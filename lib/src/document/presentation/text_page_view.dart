import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';

/// One page's recognized text as a white sheet (stories 6 and 8, design
/// `scanTextMode`).
///
/// Tap a word to select it; tap another word in the same paragraph to extend the
/// selection to it. Hidden words show blurred. [editing] opens that paragraph in
/// place («تعديل» on the selection bar).
class TextPageView extends StatelessWidget {
  const TextPageView({super.key, required this.page, required this.strings, this.editing, this.onEditDone});

  final CapturedPage page;
  final DocScanStrings strings;

  /// The paragraph open for editing on this page, if any.
  final String? editing;
  final VoidCallback? onEditDone;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewState st = context.watch<PreviewCubit>().state;
    final RecognitionState r = page.recognition;
    final TextStyle body = t.bodyStyle.sized(14, 24).copyWith(color: t.inverseSurface, fontWeight: FontWeight.w600);
    final Widget content;
    if (r is! RecognitionDone) {
      content = Text(
        strings.noTextOnPage,
        style: body.copyWith(color: t.onSurfaceMuted, fontWeight: FontWeight.w400),
        textAlign: TextAlign.center,
      );
    } else {
      final TextDirection dir = r.text.language == RecognitionLanguage.ar ? TextDirection.rtl : TextDirection.ltr;
      Widget paragraph(Paragraph p) {
        // Headings and larger print keep their size relative to the body.
        final TextStyle style = body.copyWith(
          fontSize: (body.fontSize ?? 14) * p.size.clamp(0.85, 1.8),
          fontWeight: p.heading ? FontWeight.w700 : body.fontWeight,
        );
        if (editing == p.id) {
          return _ParagraphEditor(
            initial: st.edits.textOf(page.id, p),
            dir: dir,
            style: style,
            align: _align(p.align),
            onDone: (String text) {
              context.read<PreviewCubit>().editParagraph(page.id, p, text);
              onEditDone?.call();
            },
          );
        }
        if (st.edits.replacements.containsKey((page.id, p.id))) {
          return Text(st.edits.textOf(page.id, p), textDirection: dir, textAlign: _align(p.align), style: style);
        }
        return _Words(page: page, paragraph: p, dir: dir, state: st, style: style);
      }

      final List<Widget> blocks = <Widget>[];
      final List<Paragraph> ps = r.text.paragraphs;
      for (int i = 0; i < ps.length; i++) {
        final Paragraph p = ps[i];
        // Blank space above as printed, capped so a sparse page stays readable.
        final double gap = (p.spaceBefore.clamp(0, 3) * 8).toDouble();
        if (p.table != null) {
          int j = i;
          while (j < ps.length && ps[j].table == p.table) {
            j++;
          }
          blocks.add(
            Padding(
              padding: EdgeInsets.only(top: gap),
              child: _TableBlock(cells: ps.sublist(i, j), dir: dir, cell: paragraph),
            ),
          );
          i = j - 1;
          continue;
        }
        blocks.add(
          Padding(
            padding: EdgeInsetsDirectional.only(top: gap),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => Padding(
                padding: EdgeInsetsDirectional.only(start: c.maxWidth * p.indent.clamp(0, 0.6)),
                child: paragraph(p),
              ),
            ),
          ),
        );
      }
      content = Directionality(
        textDirection: dir,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
      );
    }
    return Container(
      width: double.infinity,
      padding: ScanMetrics.textPage,
      decoration: BoxDecoration(color: t.surface, boxShadow: pageShadow(t)),
      child: content,
    );
  }
}

TextAlign _align(BlockAlign a) => switch (a) {
  BlockAlign.start => TextAlign.start,
  BlockAlign.center => TextAlign.center,
  BlockAlign.end => TextAlign.end,
  BlockAlign.justify => TextAlign.justify,
};

/// A recognized table: ruled cells in their rows and columns. A single row of
/// side-by-side text (two signatures) has no rules, each part toward its side.
class _TableBlock extends StatelessWidget {
  const _TableBlock({required this.cells, required this.dir, required this.cell});

  final List<Paragraph> cells;
  final TextDirection dir;
  final Widget Function(Paragraph) cell;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    int rows = 0;
    int cols = 0;
    for (final Paragraph p in cells) {
      rows = rows < (p.row ?? 0) + 1 ? (p.row ?? 0) + 1 : rows;
      cols = cols < (p.col ?? 0) + 1 ? (p.col ?? 0) + 1 : cols;
    }
    Paragraph? at(int r, int c) {
      for (final Paragraph p in cells) {
        if (p.row == r && p.col == c) return p;
      }
      return null;
    }

    if (rows == 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int c = 0; c < cols; c++)
            Expanded(
              child: Align(
                alignment: c == 0
                    ? AlignmentDirectional.centerStart
                    : (c == cols - 1 ? AlignmentDirectional.centerEnd : Alignment.center),
                child: at(0, c) == null ? const SizedBox.shrink() : cell(at(0, c)!),
              ),
            ),
        ],
      );
    }
    return Table(
      textDirection: dir,
      border: TableBorder.all(color: t.border),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        for (int r = 0; r < rows; r++)
          TableRow(
            children: <Widget>[
              for (int c = 0; c < cols; c++)
                Padding(
                  padding: ScanMetrics.tableCell,
                  child: at(r, c) == null ? const SizedBox.shrink() : cell(at(r, c)!),
                ),
            ],
          ),
      ],
    );
  }
}

/// The design's paper shadow: 0 1 2 and 0 6 16, both 8% black.
List<BoxShadow> pageShadow(DocScanTheme t) => <BoxShadow>[
  BoxShadow(color: t.inverseSurface.withValues(alpha: 0.08), blurRadius: 2, offset: const Offset(0, 1)),
  BoxShadow(color: t.inverseSurface.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
];

/// One paragraph as real text runs, so the bidi algorithm orders Latin words
/// inside Arabic lines (a placeholder per word would reverse them). Each word has
/// its own tap recognizer; hidden words are blurred glyphs.
class _Words extends StatefulWidget {
  const _Words({
    required this.page,
    required this.paragraph,
    required this.dir,
    required this.state,
    required this.style,
  });

  final CapturedPage page;
  final Paragraph paragraph;
  final TextDirection dir;
  final PreviewState state;
  final TextStyle style;

  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> {
  final List<TapGestureRecognizer> _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer r in _taps) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(int i, VoidCallback onTap) {
    while (_taps.length <= i) {
      _taps.add(TapGestureRecognizer());
    }
    return _taps[i]..onTap = onTap;
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.read<PreviewCubit>();
    final Paragraph paragraph = widget.paragraph;
    final PreviewState state = widget.state;
    final WordSelection? sel = state.selection;
    final bool here = sel != null && sel.pageId == widget.page.id && sel.paragraphId == paragraph.id;
    final ParagraphKey key = (widget.page.id, paragraph.id);
    final bool wholeHidden = state.edits.isParagraphRedacted(key);
    final int n = paragraph.words.length;
    // Justified prose reflows; other blocks keep their printed lines (lists,
    // addresses, centered titles).
    final bool keepLines = paragraph.align != BlockAlign.justify;
    final Set<int> breaks = keepLines ? paragraph.lineStarts.toSet() : const <int>{};
    final TextStyle base = widget.style;
    final TextStyle hidden = base.copyWith(
      foreground: Paint()
        ..color = base.color ?? t.inverseSurface
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final TextStyle selected = base.copyWith(backgroundColor: t.frameDetected.withValues(alpha: 0.28));
    // A mostly Latin paragraph reads left to right even on an Arabic page.
    final TextDirection dir = paragraph.mostlyLatin ? TextDirection.ltr : widget.dir;
    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          for (int i = 0; i < n; i++) ...<InlineSpan>[
            if (breaks.contains(i)) const TextSpan(text: '\n') else if (i > 0) const TextSpan(text: ' '),
            TextSpan(
              text: paragraph.words[i].text,
              style: wholeHidden || state.edits.isWordRedacted(key, i)
                  ? hidden
                  : (here && i >= sel.start && i <= sel.end ? selected : null),
              recognizer: _tap(i, () {
                if (here && sel.start == i && sel.end == i) return cubit.select(null);
                if (here) {
                  final int a = i < sel.start ? i : sel.start;
                  final int b = i > sel.end ? i : sel.end;
                  return cubit.select(
                    WordSelection(pageId: widget.page.id, paragraphId: paragraph.id, start: a, end: b),
                  );
                }
                cubit.select(WordSelection(pageId: widget.page.id, paragraphId: paragraph.id, start: i, end: i));
              }),
            ),
          ],
        ],
      ),
      textDirection: dir,
      textAlign: _align(paragraph.align),
    );
  }
}

// TODO(unused): words are text runs now (_WordsState); kept for a widget per word.
// ignore: unused_element
class _Word extends StatelessWidget {
  const _Word({
    required this.text,
    required this.style,
    required this.hidden,
    required this.selected,
    required this.highlight,
  });

  final String text;
  final TextStyle style;
  final bool hidden;
  final bool selected;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final Widget word = DecoratedBox(
      decoration: BoxDecoration(color: selected ? highlight : null, borderRadius: ScanMetrics.radius(2)),
      child: Text(text, style: style),
    );
    // Design: a hidden word stays in place, blurred 4.
    return hidden ? ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: word) : word;
  }
}

/// A paragraph open in place, on a light navy wash (design `ln.isEd`).
class _ParagraphEditor extends StatefulWidget {
  const _ParagraphEditor({
    required this.initial,
    required this.dir,
    required this.style,
    required this.onDone,
    this.align = TextAlign.justify,
  });

  final TextAlign align;

  final String initial;
  final TextDirection dir;
  final TextStyle style;
  final ValueChanged<String> onDone;

  @override
  State<_ParagraphEditor> createState() => _ParagraphEditorState();
}

class _ParagraphEditorState extends State<_ParagraphEditor> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone(_c.text);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final Color wash = t.primary.withValues(alpha: 0.07);
    return Container(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: ScanMetrics.radius(4),
        boxShadow: <BoxShadow>[BoxShadow(color: wash, spreadRadius: 4)],
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        maxLines: null,
        textDirection: widget.dir,
        textAlign: widget.align,
        style: widget.style,
        onTapOutside: (_) => _focus.unfocus(),
        decoration: const InputDecoration.collapsed(hintText: null),
      ),
    );
  }
}

/// «نص محجوب»: a redacted paragraph (story 9).
class RedactedBar extends StatelessWidget {
  const RedactedBar({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
      decoration: BoxDecoration(color: t.redactionFill, borderRadius: BorderRadius.circular(t.radiusSm)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: t.captionStyle.copyWith(color: t.onRedactionFill)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The dark pill over a selection (story 8, design `scanHasSel`): hide or show
/// it, edit its paragraph, or drop the selection.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key, required this.strings, required this.onEdit});

  final DocScanStrings strings;

  /// «تعديل»: opens the selection's paragraph in place.
  final void Function(WordSelection selection) onEdit;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.watch<PreviewCubit>();
    final PreviewState st = cubit.state;
    final WordSelection? sel = st.selection;
    if (sel == null) return const SizedBox.shrink();
    final bool redacted = st.selectionRedacted;
    Widget divider() => Container(width: 1, height: 20, color: t.surface.withValues(alpha: 0.2));
    return Container(
      padding: ScanMetrics.pill,
      decoration: BoxDecoration(
        color: t.inverseSurface,
        borderRadius: ScanMetrics.radius(40),
        boxShadow: <BoxShadow>[
          BoxShadow(color: t.inverseSurface.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PillAction(
            label: redacted ? strings.showText : strings.hideSelection,
            icon: redacted ? t.icons.reveal : t.icons.redact,
            iconSize: 17,
            onTap: redacted ? cubit.revealSelection : cubit.redactSelection,
          ),
          divider(),
          _PillAction(
            label: strings.edit,
            icon: t.icons.edit,
            iconSize: 16,
            onTap: () {
              cubit.select(null);
              onEdit(sel);
            },
          ),
          divider(),
          Semantics(
            button: true,
            label: strings.cancel,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => cubit.select(null),
              child: SizedBox.square(
                dimension: 40,
                child: Center(child: DocScanIcon(t.icons.close, size: 15, color: t.surface)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, required this.icon, required this.iconSize, required this.onTap});

  final String label;
  final String icon;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: ScanMetrics.radius(40),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DocScanIcon(icon, size: iconSize, color: t.surface),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: t.bodyStyle.sized(14, 20).copyWith(color: t.surface, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
