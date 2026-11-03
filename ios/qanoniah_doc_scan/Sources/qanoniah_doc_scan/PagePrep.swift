import CoreImage
import Foundation
import ImageIO
import UIKit
import Vision

/// Page preparation and live-frame analysis on the GPU (Core Image) and Vision.
///
/// - `preparePage`: perspective-corrects the photo to the page corners, applies the
///   user's filters, writes the visible JPEG and a grayscale, shadow-free OCR input.
///   Same contract as the Dart `preparePage`, which stays the fallback.
/// - `analyzeFrame`: page corners (document segmentation, then rectangles), sharpness,
///   brightness and a 16x16 signature of one live luminance frame, in one call.
enum PagePrep {
  static let context = CIContext(options: [.cacheIntermediates: false, .priorityRequestLow: false])
  private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
  private static let gray = CGColorSpaceCreateDeviceGray()

  // MARK: Prepare

  static func prepare(_ args: [String: Any]) -> [String: Any]? {
    guard let raw = args["raw"] as? String,
      let quad = args["quad"] as? [Double], quad.count == 8,
      let preparedPath = args["prepared"] as? String,
      let ocrPath = args["ocr"] as? String
    else { return nil }
    let filters = Set((args["filters"] as? [String]) ?? [])
    let maxLongEdge = CGFloat((args["maxLongEdge"] as? Int) ?? 2200)
    let quality = CGFloat((args["quality"] as? Int) ?? 90) / 100

    guard let photo = CIImage(contentsOf: URL(fileURLWithPath: raw), options: [.applyOrientationProperty: true])
    else { return nil }
    var page = warp(photo, quad: quad)
    let long = max(page.extent.width, page.extent.height)
    if long > maxLongEdge {
      page = page.applyingFilter(
        "CILanczosScaleTransform", parameters: [kCIInputScaleKey: maxLongEdge / long, kCIInputAspectRatioKey: 1])
    }
    page = normalized(page)
    // A hair inside the found edge, so no sliver of the desk survives.
    let inset = page.extent.insetBy(dx: page.extent.width * 0.006, dy: page.extent.height * 0.006).integral
    page = normalized(page.cropped(to: inset))

    let flat = flattened(page)
    var visible = page
    if filters.contains("removeShadows") { visible = flat }
    if filters.contains("autoEnhance") { visible = autoEnhance(visible) }
    if filters.contains("highContrast") {
      visible = visible.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.35])
    }
    if filters.contains("sharpenText") {
      visible = visible.applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 2.0, kCIInputIntensityKey: 0.9])
    }
    if filters.contains("grayscale") {
      visible = visible.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
    }
    if filters.contains("blackWhite") { visible = blackWhite(flat) }
    visible = normalized(visible)

    do {
      try context.writeJPEGRepresentation(
        of: visible, to: URL(fileURLWithPath: preparedPath), colorSpace: srgb,
        options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality])
      // Recognition reads the flattened gray page: no shadows, natural ink edges.
      let ocr = normalized(
        (filters.contains("removeShadows") || filters.contains("blackWhite") ? visible : flat)
          .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.1]))
      try context.writePNGRepresentation(
        of: ocr, to: URL(fileURLWithPath: ocrPath), format: .L8, colorSpace: gray, options: [:])
    } catch {
      return nil
    }
    return ["width": Int(visible.extent.width), "height": Int(visible.extent.height)]
  }

  /// [quad] is tl, tr, br, bl, normalized, origin top left.
  private static func warp(_ image: CIImage, quad q: [Double]) -> CIImage {
    let e = image.extent
    func point(_ i: Int) -> CIVector {
      CIVector(x: e.minX + CGFloat(q[i]) * e.width, y: e.minY + (1 - CGFloat(q[i + 1])) * e.height)
    }
    let isFull = q == [0, 0, 1, 0, 1, 1, 0, 1]
    if isFull { return image }
    let flat = image.applyingFilter(
      "CIPerspectiveCorrection",
      parameters: [
        "inputTopLeft": point(0), "inputTopRight": point(2),
        "inputBottomRight": point(4), "inputBottomLeft": point(6),
      ])
    // The sheet's real proportions, not the photo's foreshortened ones.
    guard let aspect = pageAspect(q, w: Double(e.width), h: Double(e.height)) else { return flat }
    let f = flat.extent
    let sx = CGFloat(aspect) * f.height / f.width
    return flat.transformed(by: CGAffineTransform(scaleX: sx, y: 1))
  }

  /// Same as the Dart `pageAspect`: width / height of the page from the perspective
  /// of its corners (Zhang and He 2007), with a typical phone lens when the focal
  /// length is not observable.
  static func pageAspect(_ q: [Double], w: Double, h: Double) -> Double? {
    let u0 = w / 2
    let v0 = h / 2
    func m(_ i: Int) -> [Double] { [q[i] * w, q[i + 1] * h, 1] }
    let m1 = m(0), m2 = m(2), m3 = m(6), m4 = m(4)
    func cross(_ a: [Double], _ b: [Double]) -> [Double] {
      [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    }
    func dot(_ a: [Double], _ b: [Double]) -> Double { a[0] * b[0] + a[1] * b[1] + a[2] * b[2] }
    let d2 = dot(cross(m2, m4), m3)
    let d3 = dot(cross(m3, m4), m2)
    if abs(d2) < 1e-9 || abs(d3) < 1e-9 { return nil }
    let k2 = dot(cross(m1, m4), m3) / d2
    let k3 = dot(cross(m1, m4), m2) / d3
    let n2 = [k2 * m2[0] - m1[0], k2 * m2[1] - m1[1], k2 * m2[2] - m1[2]]
    let n3 = [k3 * m3[0] - m1[0], k3 * m3[1] - m1[1], k3 * m3[2] - m1[2]]
    let longSide = max(w, h)
    let den = n2[2] * n3[2] == 0 ? 1e-12 : n2[2] * n3[2]
    let num1 = n2[0] * n3[0] - (n2[0] * n3[2] + n2[2] * n3[0]) * u0 + n2[2] * n3[2] * u0 * u0
    let num2 = n2[1] * n3[1] - (n2[1] * n3[2] + n2[2] * n3[1]) * v0 + n2[2] * n3[2] * v0 * v0
    let f2 = -(num1 + num2) / den
    func parallel(_ n: [Double]) -> Bool { abs(n[2]) * longSide < 0.02 * (n[0] * n[0] + n[1] * n[1]).squareRoot() }
    let solved = !parallel(n2) && !parallel(n3) && f2.isFinite && f2 > 0 ? f2.squareRoot() : 0
    let f = solved >= 0.5 * longSide && solved <= 3 * longSide ? solved : 0.75 * longSide
    func norm(_ n: [Double]) -> Double {
      let x = (n[0] - u0 * n[2]) / f
      let y = (n[1] - v0 * n[2]) / f
      return x * x + y * y + n[2] * n[2]
    }
    let r = (norm(n2) / norm(n3)).squareRoot()
    return r.isFinite && r > 0.2 && r < 5 ? r : nil
  }

  /// Moves the image to the origin with whole-pixel bounds.
  private static func normalized(_ image: CIImage) -> CIImage {
    let e = image.extent.integral
    return image.cropped(to: e).transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
  }

  /// The page divided by its own paper brightness: shadows and uneven light go,
  /// ink stays. The paper is estimated at 1/8 scale (max then blur), like the Dart
  /// pipeline, which keeps it cheap.
  static func flattened(_ page: CIImage) -> CIImage {
    let e = page.extent
    let k: CGFloat = 0.125
    let small = page.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: k, kCIInputAspectRatioKey: 1])
    let paper = small
      .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 2.5])
      .clampedToExtent()
      .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3])
      .cropped(to: small.extent)
      .transformed(by: CGAffineTransform(scaleX: e.width / small.extent.width, y: e.height / small.extent.height))
      .transformed(by: CGAffineTransform(translationX: e.minX, y: e.minY))
      .clampedToExtent()
      .cropped(to: e)
    // CIDivideBlendMode gives background / input, so the page is the background.
    return paper.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: page]).cropped(to: e)
  }

  private static func autoEnhance(_ image: CIImage) -> CIImage {
    var out = image
    if CIFilter(name: "CIDocumentEnhancer") != nil {
      out = out.applyingFilter("CIDocumentEnhancer", parameters: ["inputAmount": 1.0])
    } else {
      for f in out.autoAdjustmentFilters(options: [.redEye: false]) {
        f.setValue(out, forKey: kCIInputImageKey)
        if let o = f.outputImage { out = o }
      }
    }
    return out.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.4])
  }

  private static func blackWhite(_ flat: CIImage) -> CIImage {
    let g = flat.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.2])
    if CIFilter(name: "CIColorThreshold") != nil {
      return g.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.78])
    }
    return g.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 4])
  }

  // MARK: Live frames

  static func analyzeFrame(bytes: Data, width w: Int, height h: Int) -> [String: Any] {
    var out: [String: Any] = [:]
    bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      guard let g = raw.bindMemory(to: UInt8.self).baseAddress, raw.count >= w * h else { return }
      var total = 0
      var sum = 0.0
      var sumSq = 0.0
      var n = 0
      var y = 1
      while y < h - 1 {
        var x = 1
        let row = y * w
        while x < w - 1 {
          let i = row + x
          let c = Int(g[i])
          total += c
          let lap = Int(g[i - 1]) + Int(g[i + 1]) + Int(g[i - w]) + Int(g[i + w]) - 4 * c
          sum += Double(lap)
          sumSq += Double(lap * lap)
          n += 1
          x += 2
        }
        y += 2
      }
      let mean = n == 0 ? 0 : sum / Double(n)
      out["sharpness"] = n == 0 ? 0 : sumSq / Double(n) - mean * mean
      out["luminance"] = n == 0 ? 0 : Double(total) / Double(n)
      let size = 16
      var sig = [Int](repeating: 0, count: size * size)
      if w >= size && h >= size {
        for by in 0..<size {
          let y0 = by * h / size
          let y1 = (by + 1) * h / size
          for bx in 0..<size {
            let x0 = bx * w / size
            let x1 = (bx + 1) * w / size
            var s = 0
            var k = 0
            var yy = y0
            while yy < y1 {
              var xx = x0
              while xx < x1 {
                s += Int(g[yy * w + xx])
                k += 1
                xx += 2
              }
              yy += 2
            }
            sig[by * size + bx] = k == 0 ? 0 : s / k
          }
        }
      }
      out["signature"] = sig
    }
    guard let provider = CGDataProvider(data: bytes as CFData),
      let image = CGImage(
        width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
        space: gray, bitmapInfo: CGBitmapInfo(rawValue: 0),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return out }
    if let corners = page(in: VNImageRequestHandler(cgImage: image, options: [:])) {
      out["corners"] = corners
    }
    return out
  }

  /// The page in a photo or frame as tl, tr, br, bl normalized with the origin at the
  /// top left: Vision's document segmentation first, its rectangle detector second.
  static func page(in handler: VNImageRequestHandler) -> [Double]? {
    let doc = VNDetectDocumentSegmentationRequest()
    let rect = VNDetectRectanglesRequest()
    rect.maximumObservations = 1
    rect.minimumSize = 0.25
    rect.minimumConfidence = 0.5
    rect.minimumAspectRatio = 0.3
    rect.quadratureTolerance = 30
    do {
      try handler.perform([doc, rect])
    } catch {
      return nil
    }
    let candidates: [VNRectangleObservation] = (doc.results ?? []) + (rect.results ?? [])
    guard let r = candidates.first(where: { $0.confidence >= 0.5 && area($0) >= 0.08 }) else { return nil }
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft].flatMap { [Double($0.x), Double(1 - $0.y)] }
  }

  private static func area(_ r: VNRectangleObservation) -> CGFloat {
    let p = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]
    var a: CGFloat = 0
    for i in 0..<4 {
      let j = (i + 1) % 4
      a += p[i].x * p[j].y - p[j].x * p[i].y
    }
    return abs(a) / 2
  }
}
