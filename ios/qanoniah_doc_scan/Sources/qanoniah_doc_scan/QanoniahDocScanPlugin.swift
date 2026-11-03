import Flutter
import UIKit
import Vision

/// Registers the iOS side of qanoniah_doc_scan: on-device text recognition with Apple
/// Vision (research R4). No image or text leaves the device.
public class QanoniahDocScanPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "qanoniah_doc_scan.recognition", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "qanoniah_doc_scan/recognition", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(QanoniahDocScanPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize",
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let lang = args["lang"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    queue.async {
      let payload = Self.recognize(path: path, language: lang == "ar" ? "ar-SA" : "en-US")
      DispatchQueue.main.async { result(payload) }
    }
  }

  /// One language per call (FR-062). Returns `unsupported` when this device's Vision
  /// cannot read the language, so the caller keeps the page as an image only.
  private static func recognize(path: String, language: String) -> [String: Any] {
    guard let image = UIImage(contentsOfFile: path)?.cgImage else {
      return ["blocks": [], "paragraphs": false]
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let supported = (try? request.supportedRecognitionLanguages()) ?? []
    guard supported.contains(language) else { return ["unsupported": true] }
    request.recognitionLanguages = [language]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
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
      text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) {
        word, range, _, _ in
        guard let word = word, !word.isEmpty,
          let box = (try? candidate.boundingBox(for: range))??.boundingBox
        else { return }
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
    return ["blocks": blocks, "paragraphs": false]
  }
}
