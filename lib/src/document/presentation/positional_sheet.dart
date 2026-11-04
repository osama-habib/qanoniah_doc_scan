import 'package:flutter/material.dart';

import '../../core/session/scan_session.dart';
import '../../core/session/word_placement.dart';

/// How one word shows on the sheet.
enum WordLook { normal, selected, hidden }

/// A recognized page drawn as printed (revised 2026-11-04): its background (the
/// scan without the recognized words) under every word as real text, at its own
/// box, baseline, size and weight. Engine-scale coordinates are scaled to the
/// width the sheet gets.
///
/// Words read too poorly to redraw stay as the scan shows them, with a tap target
/// on top so they can still be hidden.
class PositionalSheet extends StatelessWidget {
  const PositionalSheet({
    super.key,
    required this.text,
    required this.style,
    required this.paper,
    required this.selection,
    required this.redaction,
    this.background,
    this.lookOf,
    this.replacementOf,
    this.isParagraphHidden,
    this.onTapWord,
    this.editorFor,
  });

  final PageText text;

  /// Family and color of the drawn words; size and weight come from the page.
  final TextStyle style;
  final Color paper;
  final Color selection;
  final Color redaction;
  final ImageProvider? background;
  final WordLook Function(Paragraph paragraph, int index)? lookOf;
  final String? Function(Paragraph paragraph)? replacementOf;
  final bool Function(Paragraph paragraph)? isParagraphHidden;
  final void Function(Paragraph paragraph, int index)? onTapWord;

  /// The in-place editor for a paragraph being edited; null for the others.
  final Widget? Function(Paragraph paragraph, double fontSize)? editorFor;

  static final RegExp _arabic = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

  @override
  Widget build(BuildContext context) {
    final double pw = text.width > 0 ? text.width : 1;
    final double ph = text.height > 0 ? text.height : 1;
    return AspectRatio(
      aspectRatio: pw / ph,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double k = c.maxWidth / pw;
          // Measured and drawn with the same effective style, so the baseline
          // measured is the one drawn (the ambient style may set a line height).
          final TextStyle base = DefaultTextStyle.of(context).style.merge(style);
          Rect scaled(Rect r) => Rect.fromLTRB(r.left * k, r.top * k, r.right * k, r.bottom * k);
          final List<Widget> under = <Widget>[];
          final List<Widget> words = <Widget>[];
          final List<Widget> over = <Widget>[];
          for (final Paragraph p in text.paragraphs) {
            if (p.words.isEmpty) continue;
            final Rect box = scaled(p.words.map((Word w) => w.box).reduce((Rect a, Rect b) => a.expandToInclude(b)));
            final double em = _median(p.words.map((Word w) => w.em).toList()) * k;
            final Widget? editor = editorFor?.call(p, em);
            if (editor != null) {
              over.add(Positioned(left: 0, right: 0, top: box.top, child: editor));
              continue;
            }
            if (isParagraphHidden?.call(p) ?? false) {
              over.add(
                Positioned.fromRect(
                  rect: box,
                  child: ColoredBox(color: redaction),
                ),
              );
              continue;
            }
            final String? replaced = replacementOf?.call(p);
            if (replaced != null) {
              under.add(
                Positioned.fromRect(
                  rect: box,
                  child: ColoredBox(color: paper),
                ),
              );
              words.add(
                Positioned(
                  left: box.left,
                  top: box.top,
                  width: box.width,
                  child: Text(
                    replaced,
                    textDirection: p.mostlyLatin ? TextDirection.ltr : TextDirection.rtl,
                    textScaler: TextScaler.noScaling,
                    style: style.copyWith(fontSize: em),
                  ),
                ),
              );
              continue;
            }
            for (int i = 0; i < p.words.length; i++) {
              final Word w = p.words[i];
              final WordLook look = lookOf?.call(p, i) ?? WordLook.normal;
              final Rect r = scaled(w.box);
              if (w.drawable) words.add(_word(w, k, look, base));
              if (look == WordLook.hidden && !w.drawable) {
                over.add(
                  Positioned.fromRect(
                    rect: r,
                    child: ColoredBox(color: redaction),
                  ),
                );
              }
              over.add(
                Positioned.fromRect(
                  rect: r,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapWord == null ? null : () => onTapWord!(p, i),
                    child: look == WordLook.selected ? ColoredBox(color: selection) : null,
                  ),
                ),
              );
            }
          }
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: paper)),
              if (background != null)
                Positioned.fill(
                  child: Image(image: background!, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
              ...under,
              ...words,
              ...over,
            ],
          );
        },
      ),
    );
  }

  /// The word as text on its baseline, scaled across to its printed width.
  Widget _word(Word w, double k, WordLook look, TextStyle style) {
    final TextDirection dir = _arabic.hasMatch(w.text) ? TextDirection.rtl : TextDirection.ltr;
    TextStyle s = style.copyWith(fontSize: w.em * k, fontWeight: w.bold ? FontWeight.w600 : FontWeight.w400);
    final TextPainter tp = TextPainter(
      text: TextSpan(text: w.text, style: s),
      textDirection: dir,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final double base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final double width = w.box.width * k;
    final double sx = fitScale(width, tp.width);
    final double left = w.box.center.dx * k - tp.width * sx / 2;
    tp.dispose();
    if (look == WordLook.hidden) {
      s = s.copyWith(
        foreground: Paint()
          ..color = s.color ?? redaction
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w.em * k * 0.25),
      );
    }
    return Positioned(
      left: left,
      top: w.baselineY * k - base,
      child: Transform(
        transform: Matrix4.diagonal3Values(sx, 1, 1),
        child: Text(
          w.text,
          textDirection: dir,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          softWrap: false,
          style: s,
        ),
      ),
    );
  }

  static double _median(List<double> v) {
    final List<double> s = List<double>.of(v)..sort();
    return s.isEmpty ? 0 : s[s.length ~/ 2];
  }
}
