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
