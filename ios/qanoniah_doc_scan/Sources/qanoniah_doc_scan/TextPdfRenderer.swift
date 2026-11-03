import CoreText
import Flutter
import UIKit

/// The text-form PDF through TextKit and CoreText (research R7, owner decision
/// 2026-11-03): Arabic is shaped, mixed Arabic and Latin runs keep their order, and
/// the PDF carries a real, extractable text layer.
///
/// Redacted runs arrive as markers with no characters and are drawn as filled bars,
/// so redacted text can never reach the PDF (FR-041, FR-042).
enum TextPdfRenderer {
  private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 in points.
  private static let textRect = CGRect(x: 48, y: 56, width: 595 - 96, height: 842 - 112)
  private static let fontSize: CGFloat = 12

  static func render(_ args: [String: Any]) -> Data? {
    guard let fontData = (args["font"] as? FlutterStandardTypedData)?.data,
      let fallbackData = (args["fontFallback"] as? FlutterStandardTypedData)?.data,
      let pages = args["pages"] as? [[[String: Any]]],
      let base = register(fontData)
    else { return nil }
    let fallback = register(fallbackData)
    let ink = color(args["text"])
    let fill = color(args["fill"])
    let onFill = color(args["onFill"])
    let label = args["label"] as? String ?? ""

    var descriptor = UIFontDescriptor(name: base, size: fontSize)
    if let fallback = fallback {
      descriptor = descriptor.addingAttributes([
        .cascadeList: [UIFontDescriptor(name: fallback, size: fontSize)]
      ])
    }
    let font = UIFont(descriptor: descriptor, size: fontSize)

    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    return renderer.pdfData { context in
      var drewAny = false
      for page in pages {
        let text = attributed(page, font: font, ink: ink, fill: fill, onFill: onFill, label: label)
        drewAny = draw(text, in: context) || drewAny
      }
      if !drewAny { context.beginPage() }
    }
  }

  /// Lays [text] out over as many PDF pages as it needs. False when it is empty.
  private static func draw(_ text: NSAttributedString, in context: UIGraphicsPDFRendererContext) -> Bool {
    guard text.length > 0 else { return false }
    let storage = NSTextStorage(attributedString: text)
    let layout = NSLayoutManager()
    storage.addLayoutManager(layout)
    var drawn = 0
    while drawn < layout.numberOfGlyphs {
      let container = NSTextContainer(size: textRect.size)
      container.lineFragmentPadding = 0
      layout.addTextContainer(container)
      let range = layout.glyphRange(for: container)
      if range.length == 0 { break }
      context.beginPage()
      layout.drawBackground(forGlyphRange: range, at: textRect.origin)
      layout.drawGlyphs(forGlyphRange: range, at: textRect.origin)
      drawn = NSMaxRange(range)
    }
    return true
  }

  private static func attributed(
    _ blocks: [[String: Any]], font: UIFont, ink: UIColor, fill: UIColor, onFill: UIColor,
    label: String
  ) -> NSAttributedString {
    let out = NSMutableAttributedString()
    for block in blocks {
      let rtl = block["rtl"] as? Bool ?? true
      let style = NSMutableParagraphStyle()
      style.alignment = rtl ? .right : .left
      style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
      style.lineSpacing = 4
      style.paragraphSpacing = 10
      let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink, .paragraphStyle: style]
      let para = NSMutableAttributedString()
      for segment in block["segments"] as? [[String: Any]] ?? [] {
        if let text = segment["text"] as? String {
          para.append(NSAttributedString(string: text + " ", attributes: attrs))
        } else if let kind = segment["redacted"] as? String {
          let whole = kind == "paragraph"
          let attachment = NSTextAttachment()
          attachment.image = bar(
            size: CGSize(width: whole ? textRect.width : 36, height: whole ? 28 : 11),
            fill: fill, label: whole ? label : nil, onFill: onFill, font: font)
          attachment.bounds = CGRect(
            x: 0, y: whole ? -8 : -1, width: whole ? textRect.width : 36, height: whole ? 28 : 11)
          let run = NSMutableAttributedString(attachment: attachment)
          run.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: run.length))
          para.append(run)
          para.append(NSAttributedString(string: " ", attributes: attrs))
        }
      }
      para.append(NSAttributedString(string: "\n", attributes: attrs))
      out.append(para)
    }
    return out
  }

  /// A filled bar; the whole-paragraph bar carries the «نص محجوب» label.
  private static func bar(size: CGSize, fill: UIColor, label: String?, onFill: UIColor, font: UIFont)
    -> UIImage
  {
    UIGraphicsImageRenderer(size: size).image { _ in
      fill.setFill()
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3).fill()
      guard let label = label else { return }
      let style = NSMutableParagraphStyle()
      style.alignment = .right
      style.baseWritingDirection = .rightToLeft
      let text = NSAttributedString(
        string: label,
        attributes: [
          .font: font.withSize(11), .foregroundColor: onFill, .paragraphStyle: style,
        ])
      text.draw(in: CGRect(x: 12, y: 6, width: size.width - 24, height: size.height - 8))
    }
  }

  /// Registers font bytes for this process and returns the PostScript name.
  private static func register(_ data: Data) -> String? {
    guard let provider = CGDataProvider(data: data as CFData), let cgFont = CGFont(provider),
      let name = cgFont.postScriptName as String?
    else { return nil }
    if UIFont(name: name, size: fontSize) == nil {
      CTFontManagerRegisterGraphicsFont(cgFont, nil)
    }
    return name
  }

  private static func color(_ value: Any?) -> UIColor {
    let argb = (value as? NSNumber)?.uint32Value ?? 0xFF00_0000
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}
