import CTesseract
import Flutter
import ImageIO
import UIKit
import Vision

/// Registers the iOS side of qanoniah_doc_scan. Everything runs on the device; no
/// image or text leaves it.
///
/// - `recognize`: Apple Vision when it can read the language, otherwise Tesseract 5
///   with the bundled tessdata_fast models (iOS 15 to 17 have no Arabic in Vision;
///   owner decision 2026-11-03).
/// - `detectRectangle`: Vision's rectangle detector on a live luminance frame.
/// - `renderText`, `renderPlaced` (channel `qanoniah_doc_scan/pdf`): the
///   text-form PDF, see [TextPdfRenderer].
public class QanoniahDocScanPlugin: NSObject, FlutterPlugin {
  private let recognitionQueue = DispatchQueue(label: "qanoniah_doc_scan.recognition", qos: .userInitiated)
  private let frameQueue = DispatchQueue(label: "qanoniah_doc_scan.frames", qos: .userInitiated)
  private let prepQueue = DispatchQueue(label: "qanoniah_doc_scan.prep", qos: .userInitiated)
  private var tesseract: [String: OpaquePointer] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "qanoniah_doc_scan/recognition", binaryMessenger: registrar.messenger())
    let plugin = QanoniahDocScanPlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    let pdf = FlutterMethodChannel(name: "qanoniah_doc_scan/pdf", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: pdf)
    let prep = FlutterMethodChannel(name: "qanoniah_doc_scan/prep", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: prep)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "recognize":
      guard let path = args["path"] as? String, let lang = args["lang"] as? String else {
        return result(FlutterMethodNotImplemented)
      }
      let tessdata = args["tessdata"] as? String
      recognitionQueue.async {
        let payload = self.recognize(path: path, lang: lang, tessdata: tessdata)
        DispatchQueue.main.async { result(payload) }
      }
    case "detectRectangle":
      guard let data = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int, let height = args["height"] as? Int
      else { return result(FlutterMethodNotImplemented) }
      frameQueue.async {
        let corners = Self.detectRectangle(bytes: data.data, width: width, height: height)
        DispatchQueue.main.async { result(corners) }
      }
    case "analyzeFrame":
      guard let data = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int, let height = args["height"] as? Int
      else { return result(FlutterMethodNotImplemented) }
      frameQueue.async {
        let analysis = PagePrep.analyzeFrame(bytes: data.data, width: width, height: height)
        DispatchQueue.main.async { result(analysis) }
      }
    case "preparePage":
      prepQueue.async {
        let out = autoreleasepool { PagePrep.prepare(args) }
        DispatchQueue.main.async {
          if let out = out {
            result(out)
          } else {
            result(FlutterError(code: "prepare_failed", message: nil, details: nil))
          }
        }
      }
    case "encodePage":
      prepQueue.async {
        var out = autoreleasepool { PagePrep.encode(args) }
        if let data = out?["bytes"] as? Data { out?["bytes"] = FlutterStandardTypedData(bytes: data) }
        DispatchQueue.main.async {
          if let out = out {
            result(out)
          } else {
            result(FlutterError(code: "encode_failed", message: nil, details: nil))
          }
        }
      }
    case "uprightTurns":
      guard let path = args["path"] as? String, let quad = args["quad"] as? [Double] else {
        return result(FlutterMethodNotImplemented)
      }
      frameQueue.async {
        let turns = PagePrep.uprightTurns(path: path, quad: quad)
        DispatchQueue.main.async { result(turns) }
      }
    case "detectRectangleInPhoto":
      guard let path = args["path"] as? String else { return result(FlutterMethodNotImplemented) }
      frameQueue.async {
        let corners = Self.detectRectangle(inPhotoAt: path)
        DispatchQueue.main.async { result(corners) }
      }
    case "renderText", "renderPlaced":
      let placed = call.method == "renderPlaced"
      recognitionQueue.async {
        let data = placed ? TextPdfRenderer.renderPlaced(args) : TextPdfRenderer.render(args)
        DispatchQueue.main.async {
          if let data = data {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(FlutterError(code: "render_failed", message: nil, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Recognition

  private func recognize(path: String, lang: String, tessdata: String?) -> [String: Any] {
    guard let image = UIImage(contentsOfFile: path)?.cgImage else {
      return ["blocks": [], "paragraphs": false]
    }
    if let vision = Self.recognizeWithVision(image, language: lang == "ar" ? "ar-SA" : "en-US") {
      return vision
    }
    guard let tessdata = tessdata else { return ["unsupported": true] }
    return recognizeWithTesseract(image, lang: lang == "ar" ? "ara" : "eng", tessdata: tessdata)
  }

  private static let wordRun = try! NSRegularExpression(pattern: "\\S+")

  /// Nil when this device's Vision cannot read [language].
  private static func recognizeWithVision(_ image: CGImage, language: String) -> [String: Any]? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let supported = (try? request.supportedRecognitionLanguages()) ?? []
    guard supported.contains(language) else { return nil }
    request.recognitionLanguages = [language]
    do {
      try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    } catch {
      return ["blocks": [], "paragraphs": false]
    }
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    var blocks: [[[String: Any]]] = []
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let text = candidate.string
      var words: [[String: Any]] = []
      // Words are whitespace runs, not `.byWords`: that skips punctuation, which
      // dropped every comma and full stop from the text.
      let whole = NSRange(text.startIndex..<text.endIndex, in: text)
      for match in wordRun.matches(in: text, range: whole) {
        guard let range = Range(match.range, in: text),
          let box = (try? candidate.boundingBox(for: range))??.boundingBox
        else { continue }
        let word = String(text[range])
        // Vision boxes are normalized with the origin at the bottom left.
        words.append([
          "text": word,
          "l": box.minX * width,
          "t": (1 - box.maxY) * height,
          "r": box.maxX * width,
          "b": (1 - box.minY) * height,
          "c": Double(candidate.confidence),
        ])
      }
      if !words.isEmpty { blocks.append(words) }
    }
    return ["blocks": blocks, "paragraphs": false, "width": image.width, "height": image.height]
  }

  private func engine(lang: String, tessdata: String) -> OpaquePointer? {
    if let api = tesseract[lang] { return api }
    guard let api = TessBaseAPICreate() else { return nil }
    guard TessBaseAPIInit2(api, tessdata, lang, OEM_LSTM_ONLY) == 0 else {
      TessBaseAPIDelete(api)
      return nil
    }
    TessBaseAPISetPageSegMode(api, PSM_AUTO)
    tesseract[lang] = api
    return api
  }

  private func recognizeWithTesseract(_ image: CGImage, lang: String, tessdata: String) -> [String: Any] {
    guard let api = engine(lang: lang, tessdata: tessdata) else { return ["unsupported": true] }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 255, count: width * height)
    let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return ["blocks": [], "paragraphs": false] }

    var blocks: [[[String: Any]]] = []
    pixels.withUnsafeBufferPointer { buffer in
      TessBaseAPISetImage(api, buffer.baseAddress, Int32(width), Int32(height), 1, Int32(width))
      guard TessBaseAPIRecognize(api, nil) == 0, let it = TessBaseAPIGetIterator(api) else { return }
      defer { TessResultIteratorDelete(it) }
      let page = TessResultIteratorGetPageIterator(it)
      var line: [[String: Any]] = []
      repeat {
        if TessPageIteratorIsAtBeginningOf(page, RIL_TEXTLINE) != 0, !line.isEmpty {
          blocks.append(line)
          line = []
        }
        guard let cText = TessResultIteratorGetUTF8Text(it, RIL_WORD) else { continue }
        let text = String(cString: cText)
        TessDeleteText(cText)
        var l: Int32 = 0, t: Int32 = 0, r: Int32 = 0, b: Int32 = 0
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty,
          TessPageIteratorBoundingBox(page, RIL_WORD, &l, &t, &r, &b) != 0
        else { continue }
        line.append([
          "text": text, "l": Double(l), "t": Double(t), "r": Double(r), "b": Double(b),
          "c": Double(TessResultIteratorConfidence(it, RIL_WORD)) / 100,
        ])
      } while TessResultIteratorNext(it, RIL_WORD) != 0
      if !line.isEmpty { blocks.append(line) }
    }
    TessBaseAPIClear(api)
    return ["blocks": blocks, "paragraphs": false, "width": width, "height": height]
  }

  // MARK: Page edges

  /// The page in a captured photo, upright (EXIF orientation applied), as 8
  /// normalized numbers, origin top left, or nil.
  private static func detectRectangle(inPhotoAt path: String) -> [Double]? {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let raw = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
    let orientation = CGImagePropertyOrientation(rawValue: raw) ?? .up
    return PagePrep.page(in: VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]))
  }

  private static func rectangle(in handler: VNImageRequestHandler) -> [Double]? {
    let request = VNDetectRectanglesRequest()
    request.maximumObservations = 1
    request.minimumSize = 0.3
    request.minimumConfidence = 0.6
    request.minimumAspectRatio = 0.3
    request.quadratureTolerance = 25
    do {
      try handler.perform([request])
    } catch {
      return nil
    }
    guard let r = request.results?.first else { return nil }
    let points = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]
    return points.flatMap { [Double($0.x), Double(1 - $0.y)] }
  }

  /// The largest page-like rectangle, as 8 normalized numbers (x, y per corner,
  /// origin top left), or nil.
  private static func detectRectangle(bytes: Data, width: Int, height: Int) -> [Double]? {
    guard bytes.count >= width * height,
      let provider = CGDataProvider(data: bytes as CFData),
      let image = CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    return rectangle(in: VNImageRequestHandler(cgImage: image, options: [:]))
  }
}
