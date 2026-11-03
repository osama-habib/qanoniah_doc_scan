package com.qanoniah.qanoniah_doc_scan

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.ReplacementSpan
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * The text-form PDF through Android's own text engine: `StaticLayout` for shaping,
 * bidi and line breaks, `PdfDocument` for the file (research R7, owner decision
 * 2026-11-03).
 *
 * Redacted runs arrive as markers with no characters and are drawn as filled bars,
 * so redacted text can never reach the PDF (FR-041, FR-042).
 */
object TextPdfRenderer {
    private const val PAGE_W = 595 // A4 in points.
    private const val PAGE_H = 842
    private const val MARGIN_X = 48f
    private const val MARGIN_Y = 56f
    private const val FONT_SIZE = 12f

    fun render(args: Map<*, *>, cacheDir: File): ByteArray? {
        val fontBytes = args["font"] as? ByteArray ?: return null
        val pages = args["pages"] as? List<*> ?: return null
        val typeface = typeface(fontBytes, args["fontFallback"] as? ByteArray, cacheDir)
        val ink = argb(args["text"])
        val fill = argb(args["fill"])
        val onFill = argb(args["onFill"])
        val label = args["label"] as? String ?: ""

        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface
            textSize = FONT_SIZE
            color = ink
        }
        val width = (PAGE_W - 2 * MARGIN_X).toInt()
        val height = PAGE_H - 2 * MARGIN_Y

        val doc = PdfDocument()
        var pageNumber = 0
        for (page in pages) {
            val text = spanned(page as? List<*> ?: continue, width, fill, onFill, label, paint)
            if (text.isEmpty()) continue
            val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setTextDirection(TextDirectionHeuristics.FIRSTSTRONG_RTL)
                .setLineSpacing(4f, 1f)
                .setIncludePad(false)
                .build()
            // One scanned page may need several PDF pages: cut between lines.
            var line = 0
            while (line < layout.lineCount) {
                val top = layout.getLineTop(line)
                var last = line
                while (last + 1 < layout.lineCount && layout.getLineBottom(last + 1) - top <= height) last++
                val pdfPage = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, ++pageNumber).create())
                val canvas = pdfPage.canvas
                canvas.save()
                canvas.translate(MARGIN_X, MARGIN_Y - top)
                canvas.clipRect(0f, top.toFloat(), width.toFloat(), layout.getLineBottom(last).toFloat())
                layout.draw(canvas)
                canvas.restore()
                doc.finishPage(pdfPage)
                line = last + 1
            }
        }
        if (pageNumber == 0) doc.finishPage(doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, 1).create()))
        val out = ByteArrayOutputStream()
        doc.writeTo(out)
        doc.close()
        return out.toByteArray()
    }

    private fun spanned(
        blocks: List<*>, width: Int, fill: Int, onFill: Int, label: String, paint: TextPaint,
    ): SpannableStringBuilder {
        val out = SpannableStringBuilder()
        for (block in blocks) {
            val map = block as? Map<*, *> ?: continue
            val rtl = map["rtl"] as? Boolean ?: true
            // A direction mark first, so a paragraph that starts with a Latin word or a
            // number still lays out in its own direction.
            out.append(if (rtl) '\u200F' else '\u200E')
            for (segment in map["segments"] as? List<*> ?: emptyList<Any>()) {
                val s = segment as? Map<*, *> ?: continue
                val text = s["text"] as? String
                val redacted = s["redacted"] as? String
                if (text != null) {
                    out.append(text).append(' ')
                } else if (redacted != null) {
                    // One placeholder character, replaced by the bar; never document text.
                    val at = out.length
                    out.append('￼')
                    val whole = redacted == "paragraph"
                    out.setSpan(
                        BarSpan(if (whole) width.toFloat() else 36f, fill, onFill, if (whole) label else null, paint),
                        at, at + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                    out.append(' ')
                }
            }
            out.append("\n\n")
        }
        return out
    }

    /** A filled bar in place of redacted text; the paragraph bar carries «نص محجوب». */
    private class BarSpan(
        private val width: Float,
        private val fill: Int,
        private val onFill: Int,
        private val label: String?,
        private val labelPaint: TextPaint,
    ) : ReplacementSpan() {
        override fun getSize(paint: Paint, text: CharSequence?, start: Int, end: Int, fm: Paint.FontMetricsInt?): Int {
            if (fm != null && label != null) {
                fm.ascent = -22; fm.top = -22; fm.descent = 6; fm.bottom = 6
            }
            return width.toInt()
        }

        override fun draw(
            canvas: Canvas, text: CharSequence?, start: Int, end: Int, x: Float, top: Int, y: Int, bottom: Int,
            paint: Paint,
        ) {
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill }
            val rect = if (label != null) RectF(x, y - 20f, x + width, y + 6f) else RectF(x, y - 10f, x + width, y + 1f)
            canvas.drawRoundRect(rect, 3f, 3f, p)
            if (label != null) {
                val lp = TextPaint(labelPaint).apply { color = onFill; textSize = 11f; textAlign = Paint.Align.RIGHT }
                canvas.drawText(label, rect.right - 12f, y - 3f, lp)
            }
        }
    }

    private fun typeface(font: ByteArray, fallback: ByteArray?, cacheDir: File): Typeface {
        val dir = File(cacheDir, "qanoniah_doc_scan_fonts").apply { mkdirs() }
        val main = File(dir, "pdf_font.ttf").apply { writeBytes(font) }
        val base = Typeface.createFromFile(main)
        if (fallback == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return base
        val latin = File(dir, "pdf_font_fallback.ttf").apply { writeBytes(fallback) }
        return try {
            val family = { f: File -> android.graphics.fonts.FontFamily.Builder(android.graphics.fonts.Font.Builder(f).build()).build() }
            Typeface.CustomFallbackBuilder(family(main)).addCustomFallback(family(latin)).build()
        } catch (e: Exception) {
            base
        }
    }

    private fun argb(value: Any?): Int = when (value) {
        is Int -> value
        is Long -> value.toInt()
        else -> 0xFF000000.toInt()
    }
}
