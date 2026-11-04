package com.qanoniah.qanoniah_doc_scan

import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Registers the Android side of qanoniah_doc_scan: on-device text recognition with
 * Tesseract (tesseract4android) reading the bundled tessdata_fast models (research R4).
 *
 * Recognition runs on one background thread, one page and one language at a time
 * (FR-062). No image or text leaves the device.
 */
class QanoniahDocScanPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var pdfChannel: MethodChannel
    private lateinit var prepChannel: MethodChannel
    private val prepWorker = Executors.newSingleThreadExecutor()
    private lateinit var cacheDir: java.io.File
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val engines = mutableMapOf<String, TessBaseAPI>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "qanoniah_doc_scan/recognition")
        channel.setMethodCallHandler(this)
        cacheDir = binding.applicationContext.cacheDir
        pdfChannel = MethodChannel(binding.binaryMessenger, "qanoniah_doc_scan/pdf")
        pdfChannel.setMethodCallHandler { call, result ->
            if (call.method != "renderText" && call.method != "renderPlaced") {
                return@setMethodCallHandler result.notImplemented()
            }
            val args = call.arguments as? Map<*, *> ?: return@setMethodCallHandler result.notImplemented()
            val placed = call.method == "renderPlaced"
            worker.execute {
                val pdf = try {
                    if (placed) TextPdfRenderer.renderPlaced(args, cacheDir) else TextPdfRenderer.render(args, cacheDir)
                } catch (e: Exception) {
                    null
                }
                main.post {
                    if (pdf != null) result.success(pdf) else result.error("render_failed", null, null)
                }
            }
        }
        // Page preparation and live-frame statistics (see PagePrep).
        prepChannel = MethodChannel(binding.binaryMessenger, "qanoniah_doc_scan/prep")
        prepChannel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: return@setMethodCallHandler result.notImplemented()
            when (call.method) {
                "preparePage" -> prepWorker.execute {
                    val out = try {
                        PagePrep.prepare(args)
                    } catch (e: Throwable) {
                        null
                    }
                    main.post {
                        if (out != null) result.success(out) else result.error("prepare_failed", null, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        pdfChannel.setMethodCallHandler(null)
        prepChannel.setMethodCallHandler(null)
        prepWorker.shutdown()
        worker.execute {
            engines.values.forEach { it.recycle() }
            engines.clear()
        }
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognize") return result.notImplemented()
        val path = call.argument<String>("path")
        val lang = if (call.argument<String>("lang") == "ar") "ara" else "eng"
        val tessdata = call.argument<String>("tessdata")
        if (path == null || tessdata == null) return result.notImplemented()
        worker.execute {
            val payload = try {
                recognize(path, lang, tessdata)
            } catch (e: Exception) {
                mapOf("blocks" to emptyList<Any>(), "paragraphs" to false)
            }
            main.post { result.success(payload) }
        }
    }

    private fun engine(lang: String, tessdata: String): TessBaseAPI? =
        engines[lang] ?: TessBaseAPI().let { api ->
            if (api.init(tessdata, lang, TessBaseAPI.OEM_LSTM_ONLY)) {
                api.pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO
                engines[lang] = api
                api
            } else {
                api.recycle()
                null
            }
        }

    private fun recognize(path: String, lang: String, tessdata: String): Map<String, Any> {
        val api = engine(lang, tessdata) ?: return mapOf("unsupported" to true)
        val bitmap = BitmapFactory.decodeFile(path)
            ?: return mapOf("blocks" to emptyList<Any>(), "paragraphs" to false)
        api.setImage(bitmap)
        api.getUTF8Text()

        // Words with boxes, grouped by the text line that contains their center.
        val lines = mutableListOf<IntArray>()
        val words = mutableListOf<Map<String, Any>>()
        val iter = api.resultIterator
        if (iter != null) {
            iter.begin()
            do {
                iter.getBoundingBox(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE)?.let { lines.add(it) }
            } while (iter.next(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE))
            iter.begin()
            do {
                val text = iter.getUTF8Text(TessBaseAPI.PageIteratorLevel.RIL_WORD) ?: continue
                val box = iter.getBoundingBox(TessBaseAPI.PageIteratorLevel.RIL_WORD) ?: continue
                if (text.isBlank()) continue
                words.add(
                    mapOf(
                        "text" to text,
                        "l" to box[0].toDouble(),
                        "t" to box[1].toDouble(),
                        "r" to box[2].toDouble(),
                        "b" to box[3].toDouble(),
                        "c" to iter.confidence(TessBaseAPI.PageIteratorLevel.RIL_WORD) / 100.0,
                    ),
                )
            } while (iter.next(TessBaseAPI.PageIteratorLevel.RIL_WORD))
            iter.delete()
        }
        api.clear()
        val width = bitmap.width
        val height = bitmap.height
        bitmap.recycle()

        val blocks = lines.map { mutableListOf<Map<String, Any>>() }.toMutableList()
        val orphans = mutableListOf<Map<String, Any>>()
        for (w in words) {
            val cy = ((w["t"] as Double) + (w["b"] as Double)) / 2
            val i = lines.indexOfFirst { cy >= it[1] && cy <= it[3] }
            if (i >= 0) blocks[i].add(w) else orphans.add(w)
        }
        val out = blocks.filter { it.isNotEmpty() }.toMutableList<List<Map<String, Any>>>()
        if (orphans.isNotEmpty()) out.add(orphans)
        return mapOf("blocks" to out, "paragraphs" to false, "width" to width, "height" to height)
    }
}
