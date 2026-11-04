package com.qanoniah.qanoniah_doc_scan

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.ReplacementSpan
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max

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
        val typeface = typeface(fontBytes, args["fontFallback"] as? ByteArray, cacheDir, "pdf_font")
        val bold = (args["fontBold"] as? ByteArray)?.let { typeface(it, args["fontFallback"] as? ByteArray, cacheDir, "pdf_font_bold") }
            ?: Typeface.create(typeface, Typeface.BOLD)
        val look = Look(
            regular = typeface, bold = bold, ink = argb(args["text"]), fill = argb(args["fill"]),
            onFill = argb(args["onFill"]), label = args["label"] as? String ?: "",
        )
        val doc = PdfDocument()
        val cursor = Cursor(doc)
        for (page in pages) {
            val blocks = (page as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: continue
            if (blocks.isEmpty()) continue
            cursor.newPage()
            var i = 0
            while (i < blocks.size) {
                val table = blocks[i]["table"] as? Number
                if (table != null) {
                    var j = i
                    while (j < blocks.size && (blocks[j]["table"] as? Number)?.toInt() == table.toInt()) j++
                    drawTable(blocks.subList(i, j), look, cursor)
                    i = j
                } else {
                    drawParagraph(blocks[i], look, cursor)
                    i++
                }
            }
        }
        cursor.finish()
        if (cursor.pageNumber == 0) doc.finishPage(doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, 1).create()))
        val out = ByteArrayOutputStream()
        doc.writeTo(out)
        doc.close()
        return out.toByteArray()
    }

    /**
     * The pages as printed (revised 2026-11-04): each PDF page has its scan's size;
     * the background (the scan without the words it erased) fills it, and every word
     * is drawn as text on its printed baseline, at its printed size, scaled across to
     * its printed width. Coordinates arrive in points.
     */
    fun renderPlaced(args: Map<*, *>, cacheDir: File): ByteArray? {
        val fontBytes = args["font"] as? ByteArray ?: return null
        val pages = (args["pages"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: return null
        val regular = typeface(fontBytes, args["fontFallback"] as? ByteArray, cacheDir, "pdf_font")
        val bold = (args["fontBold"] as? ByteArray)?.let { typeface(it, args["fontFallback"] as? ByteArray, cacheDir, "pdf_font_bold") }
            ?: Typeface.create(regular, Typeface.BOLD)
        val ink = argb(args["text"])
        val fill = argb(args["fill"])
        val onFill = argb(args["onFill"])
        val label = args["label"] as? String ?: ""
        val doc = PdfDocument()
        var number = 0
        for (page in pages) {
            val w = num(page["w"]).toInt().coerceAtLeast(1)
            val h = num(page["h"]).toInt().coerceAtLeast(1)
            val pdfPage = doc.startPage(PdfDocument.PageInfo.Builder(w, h, ++number).create())
            val canvas = pdfPage.canvas
            (page["bg"] as? ByteArray)?.let { bytes ->
                android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.let { bmp ->
                    canvas.drawBitmap(bmp, null, RectF(0f, 0f, w.toFloat(), h.toFloat()), Paint(Paint.FILTER_BITMAP_FLAG))
                    bmp.recycle()
                }
            }
            for (item in (page["items"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()) {
                val box = RectF(num(item["l"]), num(item["t"]), num(item["r"]), num(item["b"]))
                when (item["k"]) {
                    "word" -> {
                        val text = item["text"] as? String ?: continue
                        if (text.isEmpty()) continue
                        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                            typeface = if (item["bold"] == true) bold else regular
                            textSize = max(1f, num(item["em"]))
                            color = ink
                        }
                        val rtl = item["rtl"] as? Boolean ?: true
                        // One line, as wide as the text (a wider layout would wrap nothing but
                        // push right-to-left text far from 0).
                        val natural = kotlin.math.ceil(paint.measureText(text)).toInt() + 2
                        val layout = staticLayout(text, paint, natural, rtl, Layout.Alignment.ALIGN_NORMAL)
                        val width = layout.getLineWidth(0)
                        if (width <= 0f) continue
                        val sx = (box.width() / width).coerceIn(0.6f, 1.6f)
                        val lineLeft = layout.getLineLeft(0)
                        canvas.save()
                        canvas.translate(box.centerX() - width * sx / 2, num(item["base"]))
                        canvas.scale(sx, 1f)
                        // The layout's own origin: its first line's left edge, its baseline at 0.
                        canvas.translate(-lineLeft, -layout.getLineBaseline(0).toFloat())
                        layout.draw(canvas)
                        canvas.restore()
                    }
                    "bar" -> {
                        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill }
                        val r = minOf(3f, box.height() / 4)
                        canvas.drawRoundRect(box, r, r, paint)
                        if (item["paragraph"] == true && box.height() >= 14f) {
                            val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                                typeface = regular
                                textSize = minOf(11f, box.height() * 0.6f)
                                color = onFill
                            }
                            val l = staticLayout(label, tp, max(1, (box.width() - 16).toInt()), true, Layout.Alignment.ALIGN_NORMAL)
                            canvas.save()
                            canvas.translate(box.left + 8, box.top + (box.height() - l.height) / 2)
                            l.draw(canvas)
                            canvas.restore()
                        }
                    }
                    "flow" -> {
                        val text = item["text"] as? String ?: continue
                        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                            typeface = regular
                            textSize = max(1f, num(item["em"]))
                            color = ink
                        }
                        val rtl = item["rtl"] as? Boolean ?: true
                        val l = staticLayout(text, paint, max(1, box.width().toInt()), rtl, Layout.Alignment.ALIGN_NORMAL)
                        canvas.save()
                        canvas.translate(box.left, box.top)
                        l.draw(canvas)
                        canvas.restore()
                    }
                }
            }
            doc.finishPage(pdfPage)
        }
        if (number == 0) doc.finishPage(doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, 1).create()))
        val out = ByteArrayOutputStream()
        doc.writeTo(out)
        doc.close()
        return out.toByteArray()
    }

    private fun num(v: Any?): Float = (v as? Number)?.toFloat() ?: 0f

    private fun staticLayout(text: CharSequence, paint: TextPaint, width: Int, rtl: Boolean, align: Layout.Alignment): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(align)
            .setTextDirection(if (rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
            .setIncludePad(false)
            .build()

    private class Look(
        val regular: Typeface, val bold: Typeface, val ink: Int, val fill: Int, val onFill: Int, val label: String,
    )

    /** The current PDF page and how far down it is filled. */
    private class Cursor(val doc: PdfDocument) {
        var page: PdfDocument.Page? = null
        var pageNumber = 0
        var y = MARGIN_Y

        val canvas: Canvas get() = page!!.canvas

        fun newPage() {
            finish()
            page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, ++pageNumber).create())
            y = MARGIN_Y
        }

        fun finish() {
            page?.let { doc.finishPage(it) }
            page = null
        }

        /** A new page when [h] does not fit, unless this page is still empty. */
        fun reserve(h: Float) {
            if (y + h > PAGE_H - MARGIN_Y && y > MARGIN_Y) newPage()
        }
    }

    private val textWidth get() = PAGE_W - 2 * MARGIN_X

    private fun space(block: Map<*, *>): Float =
        ((block["space"] as? Number)?.toFloat() ?: 0f).coerceIn(0f, 3f) * FONT_SIZE * 0.6f

    private fun layout(block: Map<*, *>, look: Look, width: Int, alignOverride: String? = null): StaticLayout {
        val rtl = block["rtl"] as? Boolean ?: true
        val heading = block["heading"] as? Boolean ?: false
        val size = ((block["size"] as? Number)?.toFloat() ?: 1f).coerceIn(0.85f, 1.8f)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = if (heading) look.bold else look.regular
            textSize = FONT_SIZE * size
            color = look.ink
        }
        val text = spanned(block, width, look.fill, look.onFill, look.label, paint)
        // NORMAL is the text's start side; OPPOSITE its end.
        val align = when (alignOverride ?: block["align"] as? String) {
            "center" -> Layout.Alignment.ALIGN_CENTER
            "end" -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_NORMAL
        }
        val b = StaticLayout.Builder.obtain(text, 0, text.length, paint, max(1, width))
            .setTextDirection(if (rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
            .setAlignment(align)
            .setLineSpacing(4f, 1f)
            .setIncludePad(false)
        if ((block["align"] as? String) == "justify" && alignOverride == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            b.setJustificationMode(android.text.Layout.JUSTIFICATION_MODE_INTER_WORD)
        }
        return b.build()
    }

    private fun drawParagraph(block: Map<*, *>, look: Look, cursor: Cursor) {
        val rtl = block["rtl"] as? Boolean ?: true
        val indent = ((block["indent"] as? Number)?.toFloat() ?: 0f).coerceIn(0f, 0.6f) * textWidth
        val width = (textWidth - indent).toInt()
        val x = if (rtl) MARGIN_X else MARGIN_X + indent
        if (cursor.y > MARGIN_Y) cursor.y += space(block)
        val l = layout(block, look, width)
        val pageH = PAGE_H - 2 * MARGIN_Y
        if (l.height <= pageH) {
            cursor.reserve(l.height.toFloat())
            cursor.canvas.save()
            cursor.canvas.translate(x, cursor.y)
            l.draw(cursor.canvas)
            cursor.canvas.restore()
            cursor.y += l.height + 8f
            return
        }
        // Longer than a page: cut between lines.
        var line = 0
        while (line < l.lineCount) {
            val top = l.getLineTop(line)
            val room = PAGE_H - MARGIN_Y - cursor.y
            var last = line
            while (last + 1 < l.lineCount && l.getLineBottom(last + 1) - top <= room) last++
            cursor.canvas.save()
            cursor.canvas.translate(x, cursor.y - top)
            cursor.canvas.clipRect(0f, top.toFloat(), width.toFloat(), l.getLineBottom(last).toFloat())
            l.draw(cursor.canvas)
            cursor.canvas.restore()
            cursor.y += (l.getLineBottom(last) - top).toFloat()
            line = last + 1
            if (line < l.lineCount) cursor.newPage()
        }
        cursor.y += 8f
    }

    private fun drawTable(cells: List<Map<*, *>>, look: Look, cursor: Cursor) {
        val rows = (cells.mapNotNull { (it["row"] as? Number)?.toInt() }.maxOrNull() ?: 0) + 1
        val cols = (cells.mapNotNull { (it["col"] as? Number)?.toInt() }.maxOrNull() ?: 0) + 1
        val rtl = cells.first()["rtl"] as? Boolean ?: true
        val ruled = rows > 1
        val colW = textWidth / cols
        val pad = 5f
        val rule = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = (look.ink and 0x00FFFFFF) or (0x73 shl 24)
            style = Paint.Style.STROKE
            strokeWidth = 0.5f
        }
        if (cursor.y > MARGIN_Y) cursor.y += space(cells.first())
        for (r in 0 until rows) {
            val layouts = HashMap<Int, StaticLayout>()
            var tallest = FONT_SIZE * 1.4f
            for (c in 0 until cols) {
                val cell = cells.firstOrNull { (it["row"] as? Number)?.toInt() == r && (it["col"] as? Number)?.toInt() == c } ?: continue
                val override = if (ruled) null else if (c == 0) "start" else if (c == cols - 1) "end" else "center"
                // Cells read in the page's direction even when their own text is Latin.
                val l = layout(HashMap<Any?, Any?>(cell).apply { put("rtl", rtl) }, look, (colW - pad * 2).toInt(), override)
                layouts[c] = l
                tallest = max(tallest, l.height.toFloat())
            }
            val rowH = tallest + pad * 2
            cursor.reserve(rowH)
            for (c in 0 until cols) {
                // Column 0 is the start side: the right edge for Arabic.
                val x = if (rtl) PAGE_W - MARGIN_X - (c + 1) * colW else MARGIN_X + c * colW
                if (ruled) cursor.canvas.drawRect(x, cursor.y, x + colW, cursor.y + rowH, rule)
                val l = layouts[c] ?: continue
                cursor.canvas.save()
                cursor.canvas.translate(x + pad, cursor.y + pad)
                l.draw(cursor.canvas)
                cursor.canvas.restore()
            }
            cursor.y += rowH
        }
        cursor.y += 8f
    }

    private fun spanned(
        block: Map<*, *>, width: Int, fill: Int, onFill: Int, label: String, paint: TextPaint,
    ): SpannableStringBuilder {
        val out = SpannableStringBuilder()
        val rtl = block["rtl"] as? Boolean ?: true
        // A direction mark first, so a paragraph that starts with a Latin word or a
        // number still lays out in its own direction.
        out.append(if (rtl) '\u200F' else '\u200E')
        for (segment in block["segments"] as? List<*> ?: emptyList<Any>()) {
            val s = segment as? Map<*, *> ?: continue
            val text = s["text"] as? String
            val redacted = s["redacted"] as? String
            if (out.length > 1) out.append(' ')
            if (text != null) {
                out.append(text)
            } else if (redacted != null) {
                // One placeholder character, replaced by the bar; never document text.
                val at = out.length
                out.append('\uFFFC')
                val whole = redacted == "paragraph"
                out.setSpan(
                    BarSpan(if (whole) width.toFloat() else 36f, fill, onFill, if (whole) label else null, paint),
                    at, at + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
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

    private fun typeface(font: ByteArray, fallback: ByteArray?, cacheDir: File, name: String): Typeface {
        val dir = File(cacheDir, "qanoniah_doc_scan_fonts").apply { mkdirs() }
        val main = File(dir, "$name.ttf").apply { writeBytes(font) }
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
