import CoreText
import Flutter
import UIKit

/// The text-form PDF through UIKit text drawing (research R7, owner decision
/// 2026-11-03): Arabic is shaped, mixed Arabic and Latin runs keep their order, and
/// the PDF carries a real, extractable text layer.
///
/// Each page keeps the scanned layout (revised 2026-11-04): blocks come in reading
/// order with their alignment, print size, heading weight, spacing and indent, and
/// table cells are drawn in ruled rows and columns (column 0 on the start side). A
/// single row of side-by-side cells (two signatures) has no rules.
///
/// Redacted runs arrive as markers with no characters and are drawn as filled bars,
/// so redacted text can never reach the PDF (FR-041, FR-042).
enum TextPdfRenderer {
  private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 in points.
  private static let textRect = CGRect(x: 48, y: 56, width: 595 - 96, height: 842 - 112)
  private static let fontSize: CGFloat = 12
  private static let lineGap: CGFloat = 4
  private static let cellPad: CGFloat = 5

  private struct Look {
    let font: UIFont
    let bold: UIFont
    let ink: UIColor
    let fill: UIColor
    let onFill: UIColor
    let rule: UIColor
    let label: String
  }

  static func render(_ args: [String: Any]) -> Data? {
    guard let fontData = (args["font"] as? FlutterStandardTypedData)?.data,
      let fallbackData = (args["fontFallback"] as? FlutterStandardTypedData)?.data,
      let pages = args["pages"] as? [[[String: Any]]],
      let base = register(fontData)
    else { return nil }
    let fallback = register(fallbackData)
    let boldName = ((args["fontBold"] as? FlutterStandardTypedData)?.data).flatMap(register)

    func font(_ name: String) -> UIFont {
      var d = UIFontDescriptor(name: name, size: fontSize)
      if let fallback = fallback {
        d = d.addingAttributes([.cascadeList: [UIFontDescriptor(name: fallback, size: fontSize)]])
      }
      return UIFont(descriptor: d, size: fontSize)
    }
    let regular = font(base)
    let bold = boldName.map(font) ?? regular
    let ink = color(args["text"])
    let look = Look(
      font: regular, bold: bold, ink: ink, fill: color(args["fill"]), onFill: color(args["onFill"]),
      rule: ink.withAlphaComponent(0.45), label: args["label"] as? String ?? "")

    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    return renderer.pdfData { context in
      var drewAny = false
      for page in pages where !page.isEmpty {
        drewAny = true
        var cursor = Cursor(context: context)
        cursor.newPage()
        var i = 0
        while i < page.count {
          let block = page[i]
          if let table = block["table"] as? Int {
            var j = i
            while j < page.count, (page[j]["table"] as? Int) == table { j += 1 }
            drawTable(Array(page[i..<j]), look: look, cursor: &cursor)
            i = j
          } else {
            drawParagraph(block, look: look, cursor: &cursor)
            i += 1
          }
        }
      }
      if !drewAny { context.beginPage() }
    }
  }

  // MARK: Pages as printed

  /// The pages as printed (revised 2026-11-04): each PDF page has its scan's
  /// size; the background (the scan without the words it erased) fills it, and
  /// every word is drawn as text on its printed baseline, at its printed size,
  /// scaled across to its printed width. Coordinates arrive in points.
  static func renderPlaced(_ args: [String: Any]) -> Data? {
    guard let fontData = (args["font"] as? FlutterStandardTypedData)?.data,
      let fallbackData = (args["fontFallback"] as? FlutterStandardTypedData)?.data,
      let pages = args["pages"] as? [[String: Any]],
      let baseFace = face(fontData)
    else { return nil }
    let fallbackFace = face(fallbackData)
    let boldFace = ((args["fontBold"] as? FlutterStandardTypedData)?.data).flatMap(face) ?? baseFace
    // Fonts are made from the host's bytes, never looked up by name: iOS has its
    // own Noto Sans Arabic under the same PostScript name, with other glyphs.
    func font(_ face: CTFontDescriptor, _ size: CGFloat) -> UIFont {
      var attributes: [CFString: Any] = [:]
      if let fallbackFace = fallbackFace { attributes[kCTFontCascadeListAttribute] = [fallbackFace] }
      let d = CTFontDescriptorCreateCopyWithAttributes(face, attributes as CFDictionary)
      return CTFontCreateWithFontDescriptor(d, size, nil) as UIFont
    }
    let ink = color(args["text"])
    let fill = color(args["fill"])
    let onFill = color(args["onFill"])
    let label = args["label"] as? String ?? ""
    let first = pages.first.map { CGRect(x: 0, y: 0, width: num($0["w"]), height: num($0["h"])) } ?? pageRect
    let renderer = UIGraphicsPDFRenderer(bounds: first)
    return renderer.pdfData { context in
      if pages.isEmpty { context.beginPage() }
      for page in pages {
        let bounds = CGRect(x: 0, y: 0, width: num(page["w"]), height: num(page["h"]))
        context.beginPage(withBounds: bounds, pageInfo: [:])
        if let bg = (page["bg"] as? FlutterStandardTypedData)?.data, let image = UIImage(data: bg) {
          image.draw(in: bounds)
        }
        let cg = context.cgContext
        for item in page["items"] as? [[String: Any]] ?? [] {
          let box = CGRect(
            x: num(item["l"]), y: num(item["t"]),
            width: num(item["r"]) - num(item["l"]), height: num(item["b"]) - num(item["t"]))
          switch item["k"] as? String {
          case "word":
            guard let text = item["text"] as? String, !text.isEmpty else { continue }
            let bold = item["bold"] as? Bool ?? false
            let f = font(bold ? boldFace : baseFace, CGFloat(max(1, num(item["em"]))))
            let style = NSMutableParagraphStyle()
            let rtl = item["rtl"] as? Bool ?? true
            style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
            let line = CTLineCreateWithAttributedString(
              NSAttributedString(
                string: text, attributes: [.font: f, .foregroundColor: ink, .paragraphStyle: style]))
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            guard width > 0 else { continue }
            let sx = min(max(box.width / width, 0.6), 1.6)
            let baseline = CGFloat(num(item["base"]))
            cg.saveGState()
            // UIKit's PDF context is flipped; CoreText draws up from the baseline.
            cg.translateBy(x: box.midX - width * sx / 2, y: baseline)
            cg.scaleBy(x: sx, y: 1)
            cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            cg.textPosition = .zero
            drawGlyphs(line, ink, cg)
            cg.restoreGState()
          case "bar":
            fill.setFill()
            UIBezierPath(roundedRect: box, cornerRadius: min(3, box.height / 4)).fill()
            if item["paragraph"] as? Bool ?? false, box.height >= 14 {
              let style = NSMutableParagraphStyle()
              style.alignment = .right
              style.baseWritingDirection = .rightToLeft
              NSAttributedString(
                string: label,
                attributes: [.font: font(baseFace, min(11, box.height * 0.6)), .foregroundColor: onFill, .paragraphStyle: style]
              ).draw(in: box.insetBy(dx: 8, dy: max(1, (box.height - 14) / 2)))
            }
          case "flow":
            guard let text = item["text"] as? String else { continue }
            let style = NSMutableParagraphStyle()
            let rtl = item["rtl"] as? Bool ?? true
            style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
            style.alignment = rtl ? .right : .left
            NSAttributedString(
              string: text,
              attributes: [.font: font(baseFace, CGFloat(max(1, num(item["em"])))), .foregroundColor: ink, .paragraphStyle: style]
            ).draw(
              with: CGRect(x: box.minX, y: box.minY, width: box.width, height: bounds.height - box.minY),
              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
          default:
            continue
          }
        }
      }
    }
  }

  private static func num(_ v: Any?) -> CGFloat { CGFloat((v as? NSNumber)?.doubleValue ?? 0) }

  /// Draws the shaped line glyph by glyph at the positions CoreText gave them.
  /// `CTLineDraw` into a PDF context loses the vertical offsets of Arabic cursive
  /// attachment (a PDF text run carries horizontal spacing only), lifting words
  /// that start with an initial meem, hah or feh off the line.
  ///
  /// Known, and as before this change: PDF readers map Noto Sans Arabic's
  /// separate dot glyphs back to text poorly, so copied Arabic text is garbled.
  private static func drawGlyphs(_ line: CTLine, _ ink: UIColor, _ cg: CGContext) {
    cg.setFillColor(ink.cgColor)
    for case let run as CTRun in CTLineGetGlyphRuns(line) as NSArray {
      let count = CTRunGetGlyphCount(run)
      guard count > 0,
        let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName]
      else { continue }
      var glyphs = [CGGlyph](repeating: 0, count: count)
      var positions = [CGPoint](repeating: .zero, count: count)
      CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
      CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
      CTFontDrawGlyphs(font as! CTFont, glyphs, positions, count, cg)
    }
  }

  // TODO(unused): measured ink for centring words; superseded by drawing the
  // glyphs at their shaped positions (2026-11-04). Kept in case a font needs it.
  /// The line's ink, up from its baseline, as CoreText really draws it: the line
  /// rasterized off screen and its inked rows read back. (Glyph boxes at the run
  /// positions miss the vertical offsets of Arabic cursive attachment.)
  private static func inkBounds(_ line: CTLine) -> CGRect {
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
    let scale: CGFloat = 4
    let pad = (ascent + descent) * scale
    let w = Int((width * scale).rounded(.up)) + 4
    let h = Int(((ascent + descent) * scale + pad * 2).rounded(.up))
    guard w > 4, h > 0,
      let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return .zero }
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    // Bitmap rows run top down; CoreText draws up from the baseline at y0.
    let y0 = (pad + descent * scale) / scale
    ctx.textPosition = CGPoint(x: 0, y: y0)
    CTLineDraw(line, ctx)
    guard let data = ctx.data else { return .zero }
    let px = data.bindMemory(to: UInt8.self, capacity: w * h)
    var top = -1
    var bottom = -1
    for row in 0..<h {
      var inked = false
      for x in 0..<w where px[row * w + x] < 128 {
        inked = true
        break
      }
      if inked {
        if top < 0 { top = row }
        bottom = row
      }
    }
    guard top >= 0 else { return .zero }
    // Row r (from the top) is y = (h - r) / scale up from the bitmap's bottom.
    let maxY = CGFloat(h - top) / scale - y0
    let minY = CGFloat(h - bottom - 1) / scale - y0
    return CGRect(x: 0, y: minY, width: width, height: maxY - minY)
  }

  // MARK: Layout

  private struct Cursor {
    let context: UIGraphicsPDFRendererContext
    var y: CGFloat = 0

    mutating func newPage() {
      context.beginPage()
      y = textRect.minY
    }

    /// Starts a new page when [height] does not fit, unless the page is still empty.
    mutating func reserve(_ height: CGFloat) {
      if y + height > textRect.maxY && y > textRect.minY { newPage() }
    }
  }

  private static func space(_ block: [String: Any]) -> CGFloat {
    let s = CGFloat((block["space"] as? NSNumber)?.doubleValue ?? 0)
    return min(max(s, 0), 3) * fontSize * 0.6
  }

  private static func height(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
    text.boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
    ).integral.height
  }

  private static func drawParagraph(_ block: [String: Any], look: Look, cursor: inout Cursor) {
    let rtl = block["rtl"] as? Bool ?? true
    let indent = CGFloat(min(max((block["indent"] as? NSNumber)?.doubleValue ?? 0, 0), 0.6)) * textRect.width
    let width = textRect.width - indent
    // The indent is on the start side: the right for Arabic.
    let x = rtl ? textRect.minX : textRect.minX + indent
    let text = attributed(block, look: look, width: width)
    if cursor.y > textRect.minY { cursor.y += space(block) }
    let h = height(text, width: width)
    if h > textRect.height {
      // Longer than a page: let TextKit split it across pages.
      drawFlowing(text, x: x, width: width, cursor: &cursor)
      return
    }
    cursor.reserve(h)
    text.draw(
      with: CGRect(x: x, y: cursor.y, width: width, height: h),
      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    cursor.y += h + lineGap * 2
  }

  private static func drawFlowing(_ text: NSAttributedString, x: CGFloat, width: CGFloat, cursor: inout Cursor) {
    let storage = NSTextStorage(attributedString: text)
    let layout = NSLayoutManager()
    storage.addLayoutManager(layout)
    var drawn = 0
    while drawn < layout.numberOfGlyphs {
      let container = NSTextContainer(size: CGSize(width: width, height: textRect.maxY - cursor.y))
      container.lineFragmentPadding = 0
      layout.addTextContainer(container)
      let range = layout.glyphRange(for: container)
      if range.length == 0 {
        cursor.newPage()
        continue
      }
      let origin = CGPoint(x: x, y: cursor.y)
      layout.drawBackground(forGlyphRange: range, at: origin)
      layout.drawGlyphs(forGlyphRange: range, at: origin)
      cursor.y += layout.usedRect(for: container).height
      drawn = NSMaxRange(range)
      if drawn < layout.numberOfGlyphs { cursor.newPage() }
    }
    cursor.y += lineGap * 2
  }

  private static func drawTable(_ cells: [[String: Any]], look: Look, cursor: inout Cursor) {
    let rows = (cells.compactMap { $0["row"] as? Int }.max() ?? 0) + 1
    let cols = (cells.compactMap { $0["col"] as? Int }.max() ?? 0) + 1
    let rtl = cells.first?["rtl"] as? Bool ?? true
    let ruled = rows > 1
    let colWidth = textRect.width / CGFloat(cols)
    if cursor.y > textRect.minY { cursor.y += space(cells[0]) }
    for r in 0..<rows {
      var texts: [Int: NSAttributedString] = [:]
      var tallest: CGFloat = fontSize * 1.4
      for c in 0..<cols {
        guard var cell = cells.first(where: { ($0["row"] as? Int) == r && ($0["col"] as? Int) == c }) else {
          continue
        }
        if !ruled {
          // Side-by-side text: the outer cells hug their sides.
          cell["align"] = c == 0 ? "start" : (c == cols - 1 ? "end" : "center")
        }
        // Cells read in the page's direction even when their own text is Latin.
        cell["rtl"] = rtl
        let t = attributed(cell, look: look, width: colWidth - cellPad * 2)
        texts[c] = t
        tallest = max(tallest, height(t, width: colWidth - cellPad * 2))
      }
      let rowHeight = tallest + cellPad * 2
      cursor.reserve(rowHeight)
      for c in 0..<cols {
        // Column 0 is the start side: the right edge for Arabic.
        let x = rtl ? textRect.maxX - CGFloat(c + 1) * colWidth : textRect.minX + CGFloat(c) * colWidth
        let rect = CGRect(x: x, y: cursor.y, width: colWidth, height: rowHeight)
        if ruled {
          look.rule.setStroke()
          let path = UIBezierPath(rect: rect)
          path.lineWidth = 0.5
          path.stroke()
        }
        texts[c]?.draw(
          with: rect.insetBy(dx: cellPad, dy: cellPad),
          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
      }
      cursor.y += rowHeight
    }
    cursor.y += lineGap * 2
  }

  // MARK: Text

  private static func attributed(_ block: [String: Any], look: Look, width: CGFloat) -> NSAttributedString {
    let rtl = block["rtl"] as? Bool ?? true
    let heading = block["heading"] as? Bool ?? false
    let size = CGFloat(min(max((block["size"] as? NSNumber)?.doubleValue ?? 1, 0.85), 1.8))
    let font = (heading ? look.bold : look.font).withSize(fontSize * size)
    let style = NSMutableParagraphStyle()
    style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    style.lineSpacing = lineGap
    switch block["align"] as? String ?? "start" {
    case "center": style.alignment = .center
    case "end": style.alignment = rtl ? .left : .right
    case "justify": style.alignment = .justified
    default: style.alignment = rtl ? .right : .left
    }
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: look.ink, .paragraphStyle: style]
    let para = NSMutableAttributedString()
    for segment in block["segments"] as? [[String: Any]] ?? [] {
      if para.length > 0 { para.append(NSAttributedString(string: " ", attributes: attrs)) }
      if let text = segment["text"] as? String {
        para.append(NSAttributedString(string: text, attributes: attrs))
      } else if let kind = segment["redacted"] as? String {
        let whole = kind == "paragraph"
        let barSize = CGSize(width: whole ? width : 36, height: whole ? 28 : font.pointSize * 0.9)
        let attachment = NSTextAttachment()
        attachment.image = bar(
          size: barSize, fill: look.fill, label: whole ? look.label : nil, onFill: look.onFill, font: font)
        attachment.bounds = CGRect(x: 0, y: whole ? -8 : -1, width: barSize.width, height: barSize.height)
        let run = NSMutableAttributedString(attachment: attachment)
        run.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: run.length))
        para.append(run)
      }
    }
    return para
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

  /// A font descriptor for exactly these bytes.
  private static func face(_ data: Data) -> CTFontDescriptor? {
    CTFontManagerCreateFontDescriptorFromData(data as CFData)
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
