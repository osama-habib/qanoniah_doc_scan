package com.qanoniah.qanoniah_doc_scan

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Page preparation on Android, the same contract as the iOS Core Image pipeline and
 * the Dart fallback: perspective-correct the photo to the page corners at the page's
 * real proportions, flatten shadows, apply the user's filters, and write the visible
 * JPEG and a grayscale OCR input.
 *
 * Bitmap and Matrix do the warp in native code; the per-pixel steps run on IntArray
 * at the page's final size only.
 */
object PagePrep {
    fun prepare(args: Map<*, *>): Map<String, Any>? {
        val raw = args["raw"] as? String ?: return null
        val quad = (args["quad"] as? List<*>)?.map { (it as Number).toDouble() } ?: return null
        if (quad.size != 8) return null
        val prepared = args["prepared"] as? String ?: return null
        val ocr = args["ocr"] as? String ?: return null
        val filters = (args["filters"] as? List<*>)?.map { it.toString() }?.toSet() ?: emptySet()
        val maxLong = (args["maxLongEdge"] as? Number)?.toInt() ?: 2200
        val quality = (args["quality"] as? Number)?.toInt() ?: 90

        val photo = decodeUpright(raw, maxLong * 2) ?: return null
        var page = warp(photo, quad, maxLong)
        if (page !== photo) photo.recycle()
        // Upright: clockwise quarter turns.
        val turns = ((args["turns"] as? Number)?.toInt() ?: 0).mod(4)
        if (turns != 0) {
            val m = android.graphics.Matrix().apply { postRotate(90f * turns) }
            val turned = Bitmap.createBitmap(page, 0, 0, page.width, page.height, m, true)
            if (turned !== page) page.recycle()
            page = turned
        }

        val flat = flattened(page)
        var visible = page
        if ("removeShadows" in filters) visible = flat
        if ("autoEnhance" in filters) visible = levels(visible)
        if ("highContrast" in filters) visible = colorMatrix(visible, contrast(1.35f))
        if ("sharpenText" in filters) visible = sharpen(visible)
        if ("grayscale" in filters) visible = colorMatrix(visible, ColorMatrix().apply { setSaturation(0f) })
        if ("blackWhite" in filters) visible = blackWhite(flat)

        write(visible, prepared, quality)
        val ocrBase = if ("removeShadows" in filters || "blackWhite" in filters) visible else flat
        val gray = colorMatrix(ocrBase, ColorMatrix().apply {
            setSaturation(0f)
            postConcat(contrast(1.1f))
        })
        // Tesseract decodes by content, so a high-quality JPEG serves as the input.
        write(gray, ocr, 95)
        return mapOf("width" to visible.width, "height" to visible.height)
    }

    /** Decodes with EXIF orientation applied, no larger than [maxLong] on the long side. */
    /**
     * A prepared page re-encoded for the PDF (ClickUp z8y71x6uvk): shrunk to
     * `longEdge`, gray or black and white when asked, JPEG at `quality`, in
     * native code; the `image` package took seconds a page.
     */
    fun encode(args: Map<*, *>): Map<String, Any>? {
        val path = args["path"] as? String ?: return null
        val longEdge = (args["longEdge"] as? Number)?.toInt() ?: return null
        val quality = (args["quality"] as? Number)?.toInt() ?: return null
        var page = decodeUpright(path, longEdge) ?: return null
        val long = max(page.width, page.height)
        if (long > longEdge) {
            val k = longEdge.toFloat() / long
            val scaled = Bitmap.createScaledBitmap(
                page, max(1, (page.width * k).roundToInt()), max(1, (page.height * k).roundToInt()), true)
            page.recycle()
            page = scaled
        }
        if (args["gray"] == true) page = colorMatrix(page, ColorMatrix().apply { setSaturation(0f) })
        // The Dart path's luminance threshold at 0.6.
        if (args["bw"] == true) page = threshold(page, 0.6f)
        val out = java.io.ByteArrayOutputStream()
        page.compress(Bitmap.CompressFormat.JPEG, quality, out)
        val result = mapOf<String, Any>("bytes" to out.toByteArray(), "width" to page.width, "height" to page.height)
        page.recycle()
        return result
    }

    private fun decodeUpright(path: String, maxLong: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxLong) sample *= 2
        val bmp = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rotation = try {
            when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (e: Exception) {
            0f
        }
        if (rotation == 0f) return bmp
        val out = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(rotation) }, true)
        bmp.recycle()
        return out
    }

    /** [q] is tl, tr, br, bl normalized, origin top left. */
    private fun warp(src: Bitmap, q: List<Double>, maxLong: Int): Bitmap {
        val w = src.width.toDouble()
        val h = src.height.toDouble()
        val p = (0 until 4).map { doubleArrayOf(q[it * 2] * w, q[it * 2 + 1] * h) }
        fun d(a: DoubleArray, b: DoubleArray) = hypot(a[0] - b[0], a[1] - b[1])
        var outW = max(d(p[0], p[1]), d(p[3], p[2]))
        val outH = max(d(p[0], p[3]), d(p[1], p[2]))
        pageAspect(q, w, h)?.let { outW = outH * it }
        val scale = min(1.0, maxLong / max(outW, outH))
        val ow = max(1, (outW * scale).roundToInt())
        val oh = max(1, (outH * scale).roundToInt())
        // A hair inside the found edge, so no sliver of the desk survives.
        val ix = ow * 0.006f
        val iy = oh * 0.006f
        val m = Matrix()
        m.setPolyToPoly(
            floatArrayOf(
                p[0][0].toFloat(), p[0][1].toFloat(), p[1][0].toFloat(), p[1][1].toFloat(),
                p[2][0].toFloat(), p[2][1].toFloat(), p[3][0].toFloat(), p[3][1].toFloat(),
            ),
            0,
            floatArrayOf(-ix, -iy, ow + ix, -iy, ow + ix, oh + iy, -ix, oh + iy),
            0,
            4,
        )
        val out = Bitmap.createBitmap(ow, oh, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(src, m, Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        return out
    }

    /** Same as the Dart and Swift `pageAspect` (Zhang and He 2007). */
    fun pageAspect(q: List<Double>, w: Double, h: Double): Double? {
        val u0 = w / 2
        val v0 = h / 2
        fun m(i: Int) = doubleArrayOf(q[i] * w, q[i + 1] * h, 1.0)
        val m1 = m(0)
        val m2 = m(2)
        val m3 = m(6)
        val m4 = m(4)
        fun cross(a: DoubleArray, b: DoubleArray) =
            doubleArrayOf(a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
        fun dot(a: DoubleArray, b: DoubleArray) = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
        val d2 = dot(cross(m2, m4), m3)
        val d3 = dot(cross(m3, m4), m2)
        if (abs(d2) < 1e-9 || abs(d3) < 1e-9) return null
        val k2 = dot(cross(m1, m4), m3) / d2
        val k3 = dot(cross(m1, m4), m2) / d3
        val n2 = DoubleArray(3) { k2 * m2[it] - m1[it] }
        val n3 = DoubleArray(3) { k3 * m3[it] - m1[it] }
        val long = max(w, h)
        val den = if (n2[2] * n3[2] == 0.0) 1e-12 else n2[2] * n3[2]
        val f2 = -((n2[0] * n3[0] - (n2[0] * n3[2] + n2[2] * n3[0]) * u0 + n2[2] * n3[2] * u0 * u0) +
            (n2[1] * n3[1] - (n2[1] * n3[2] + n2[2] * n3[1]) * v0 + n2[2] * n3[2] * v0 * v0)) / den
        fun parallel(n: DoubleArray) = abs(n[2]) * long < 0.02 * sqrt(n[0] * n[0] + n[1] * n[1])
        val solved = if (!parallel(n2) && !parallel(n3) && f2.isFinite() && f2 > 0) sqrt(f2) else 0.0
        val f = if (solved >= 0.5 * long && solved <= 3 * long) solved else 0.75 * long
        fun norm(n: DoubleArray): Double {
            val x = (n[0] - u0 * n[2]) / f
            val y = (n[1] - v0 * n[2]) / f
            return x * x + y * y + n[2] * n[2]
        }
        val r = sqrt(norm(n2) / norm(n3))
        return if (r.isFinite() && r > 0.2 && r < 5) r else null
    }

    /** The page divided by its paper brightness, estimated at 1/8 scale (max, then blur). */
    private fun flattened(page: Bitmap): Bitmap {
        val w = page.width
        val h = page.height
        val sw = max(1, w / 8)
        val sh = max(1, h / 8)
        val small = Bitmap.createScaledBitmap(page, sw, sh, true)
        val sp = IntArray(sw * sh)
        small.getPixels(sp, 0, sw, 0, 0, sw, sh)
        small.recycle()
        var bg = FloatArray(sw * sh) { lum(sp[it]) }
        bg = maxFilter(bg, sw, sh, 2)
        repeat(3) { bg = boxBlur(bg, sw, sh, 2) }

        val px = IntArray(w * h)
        page.getPixels(px, 0, w, 0, 0, w, h)
        for (y in 0 until h) {
            val fy = min(sh - 1f, y / 8f)
            val y0 = fy.toInt()
            val y1 = min(sh - 1, y0 + 1)
            val ty = fy - y0
            for (x in 0 until w) {
                val fx = min(sw - 1f, x / 8f)
                val x0 = fx.toInt()
                val x1 = min(sw - 1, x0 + 1)
                val tx = fx - x0
                val b = (bg[y0 * sw + x0] * (1 - tx) + bg[y0 * sw + x1] * tx) * (1 - ty) +
                    (bg[y1 * sw + x0] * (1 - tx) + bg[y1 * sw + x1] * tx) * ty
                val k = 255f / max(1f, b)
                val c = px[y * w + x]
                px[y * w + x] = (0xFF shl 24) or
                    (clamp(((c shr 16) and 0xFF) * k) shl 16) or
                    (clamp(((c shr 8) and 0xFF) * k) shl 8) or
                    clamp((c and 0xFF) * k)
            }
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    /** Stretches the 1st to 99th luminance percentile to the full range. */
    private fun levels(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val hist = IntArray(256)
        for (c in px) hist[lum(c).toInt().coerceIn(0, 255)]++
        fun pct(p: Double): Int {
            var acc = 0
            val target = px.size * p
            for (i in 0..255) {
                acc += hist[i]
                if (acc >= target) return i
            }
            return 255
        }
        val lo = pct(0.01)
        val hi = max(lo + 1, pct(0.99))
        val k = 255f / (hi - lo)
        val m = ColorMatrix(floatArrayOf(k, 0f, 0f, 0f, -lo * k, 0f, k, 0f, 0f, -lo * k, 0f, 0f, k, 0f, -lo * k, 0f, 0f, 0f, 1f, 0f))
        return colorMatrix(src, m)
    }

    private fun contrast(c: Float): ColorMatrix {
        val t = (1 - c) * 128f
        return ColorMatrix(floatArrayOf(c, 0f, 0f, 0f, t, 0f, c, 0f, 0f, t, 0f, 0f, c, 0f, t, 0f, 0f, 0f, 1f, 0f))
    }

    private fun colorMatrix(src: Bitmap, m: ColorMatrix): Bitmap {
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(src, 0f, 0f, Paint().apply { colorFilter = ColorMatrixColorFilter(m) })
        return out
    }

    private fun sharpen(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val out = px.copyOf()
        for (y in 1 until h - 1) {
            for (x in 1 until w - 1) {
                val i = y * w + x
                var r = 0
                var g = 0
                var b = 0
                for ((j, k) in arrayOf(i to 5, i - 1 to -1, i + 1 to -1, i - w to -1, i + w to -1)) {
                    val c = px[j]
                    r += ((c shr 16) and 0xFF) * k
                    g += ((c shr 8) and 0xFF) * k
                    b += (c and 0xFF) * k
                }
                out[i] = (0xFF shl 24) or (clamp(r.toFloat()) shl 16) or (clamp(g.toFloat()) shl 8) or clamp(b.toFloat())
            }
        }
        return Bitmap.createBitmap(out, w, h, Bitmap.Config.ARGB_8888)
    }

    /**
     * Black and white from the flattened page (shadows already gone). The cut is
     * the page's own: between its ink and its paper (Otsu), then most of the way
     * to the paper, so faint print and light stamps stay black while the paper's
     * grain goes white. A narrow ramp keeps letters' edges smooth, not jagged.
     */
    private fun blackWhite(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val hist = DoubleArray(256)
        for (c in px) hist[lum(c).toInt().coerceIn(0, 255)] += 1.0
        val cut = (inkCut(hist) ?: 0.78) * 255.0
        val ramp = 0.04 * 255.0
        val lo = cut - ramp
        for (i in px.indices) {
            val v = ((lum(px[i]) - lo) / (2 * ramp) * 255.0).toInt().coerceIn(0, 255)
            px[i] = (0xFF shl 24) or (v shl 16) or (v shl 8) or v
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    /** Otsu's level, then 55% of the way up to the paper's peak; between 0.6 and 0.9. */
    fun inkCut(h: DoubleArray): Double? {
        val n = h.size
        val total = h.sum()
        if (total <= 0 || n < 2) return null
        var sumAll = 0.0
        for (i in 0 until n) sumAll += i * h[i]
        var sumB = 0.0
        var wB = 0.0
        var best = -1.0
        var t = n / 2
        for (i in 0 until n) {
            wB += h[i]
            if (wB == 0.0) continue
            val wF = total - wB
            if (wF == 0.0) break
            sumB += i * h[i]
            val mB = sumB / wB
            val mF = (sumAll - sumB) / wF
            val between = wB * wF * (mB - mF) * (mB - mF)
            if (between > best) {
                best = between
                t = i
            }
        }
        var paper = t
        for (i in t until n) if (h[i] > h[paper]) paper = i
        val cut = (t + 0.55 * (paper - t)) / (n - 1).toDouble()
        return cut.coerceIn(0.6, 0.9)
    }

    /** Hard cut at [level]: the PDF's black-and-white mode, and the fixed 0.78 cut before the page's own. */
    private fun threshold(src: Bitmap, level: Float): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        val cut = level * 255f
        for (i in px.indices) px[i] = if (lum(px[i]) > cut) -0x1 else -0x1000000
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    private fun maxFilter(a: FloatArray, w: Int, h: Int, r: Int): FloatArray {
        val out = FloatArray(a.size)
        for (y in 0 until h) for (x in 0 until w) {
            var m = 0f
            for (dy in -r..r) {
                val yy = (y + dy).coerceIn(0, h - 1)
                for (dx in -r..r) m = max(m, a[yy * w + (x + dx).coerceIn(0, w - 1)])
            }
            out[y * w + x] = m
        }
        return out
    }

    private fun boxBlur(a: FloatArray, w: Int, h: Int, r: Int): FloatArray {
        val out = FloatArray(a.size)
        val n = (2 * r + 1) * (2 * r + 1)
        for (y in 0 until h) for (x in 0 until w) {
            var s = 0f
            for (dy in -r..r) {
                val yy = (y + dy).coerceIn(0, h - 1)
                for (dx in -r..r) s += a[yy * w + (x + dx).coerceIn(0, w - 1)]
            }
            out[y * w + x] = s / n
        }
        return out
    }

    private fun write(bmp: Bitmap, path: String, quality: Int) {
        FileOutputStream(File(path)).use { bmp.compress(Bitmap.CompressFormat.JPEG, quality, it) }
    }

    private fun lum(c: Int): Float =
        0.2126f * ((c shr 16) and 0xFF) + 0.7152f * ((c shr 8) and 0xFF) + 0.0722f * (c and 0xFF)

    private fun clamp(v: Float): Int = v.roundToInt().coerceIn(0, 255)

    /** Sharpness, brightness and a 16x16 signature of a live luminance frame. */
    fun analyzeFrame(bytes: ByteArray, w: Int, h: Int): Map<String, Any> {
        var total = 0L
        var sum = 0.0
        var sumSq = 0.0
        var n = 0
        var y = 1
        while (y < h - 1) {
            var x = 1
            while (x < w - 1) {
                val i = y * w + x
                val c = bytes[i].toInt() and 0xFF
                total += c
                val lap = (bytes[i - 1].toInt() and 0xFF) + (bytes[i + 1].toInt() and 0xFF) +
                    (bytes[i - w].toInt() and 0xFF) + (bytes[i + w].toInt() and 0xFF) - 4 * c
                sum += lap
                sumSq += lap.toDouble() * lap
                n++
                x += 2
            }
            y += 2
        }
        val mean = if (n == 0) 0.0 else sum / n
        val size = 16
        val sig = IntArray(size * size)
        if (w >= size && h >= size) {
            for (by in 0 until size) for (bx in 0 until size) {
                var s = 0
                var k = 0
                var yy = by * h / size
                while (yy < (by + 1) * h / size) {
                    var xx = bx * w / size
                    while (xx < (bx + 1) * w / size) {
                        s += bytes[yy * w + xx].toInt() and 0xFF
                        k++
                        xx += 2
                    }
                    yy += 2
                }
                sig[by * size + bx] = if (k == 0) 0 else s / k
            }
        }
        return mapOf(
            "sharpness" to (if (n == 0) 0.0 else sumSq / n - mean * mean),
            "luminance" to (if (n == 0) 0.0 else total.toDouble() / n),
            "signature" to sig.toList(),
        )
    }
}
