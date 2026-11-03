import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/document_edits.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';

/// One page's recognized text, with word selection for redaction (stories 6 and 8).
///
/// Tap a word to select it; tap another word in the same paragraph to extend the
/// selection to it. The action bar then hides or shows the selection, or opens
/// the paragraph for editing.
class TextPageView extends StatelessWidget {
  const TextPageView({super.key, required this.page, required this.strings});

  final CapturedPage page;
  final DocScanStrings strings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewState st = context.watch<PreviewCubit>().state;
    final RecognitionState r = page.recognition;
    if (r is! RecognitionDone) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spaceXl),
          child: Text(strings.noTextOnPage, style: t.bodyStyle.copyWith(color: t.onSurfaceMuted), textAlign: TextAlign.center),
        ),
      );
    }
    final TextDirection dir = r.text.language == RecognitionLanguage.ar ? TextDirection.rtl : TextDirection.ltr;
    return ListView(
      padding: EdgeInsets.all(t.spaceLg),
      children: <Widget>[
        for (final Paragraph p in r.text.paragraphs)
          Padding(
            padding: EdgeInsets.only(bottom: t.spaceMd),
            child: st.edits.isParagraphRedacted((page.id, p.id))
                ? RedactedBar(label: strings.redactedText)
                : (st.edits.replacements.containsKey((page.id, p.id))
                      ? Text(
                          st.edits.textOf(page.id, p),
                          textDirection: dir,
                          style: t.bodyStyle.copyWith(color: t.onSurface),
                        )
                      : _Words(page: page, paragraph: p, dir: dir, state: st)),
          ),
      ],
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.page, required this.paragraph, required this.dir, required this.state});

  final CapturedPage page;
  final Paragraph paragraph;
  final TextDirection dir;
  final PreviewState state;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.read<PreviewCubit>();
    final WordSelection? sel = state.selection;
    final bool here = sel != null && sel.pageId == page.id && sel.paragraphId == paragraph.id;
    final ParagraphKey key = (page.id, paragraph.id);
    return Directionality(
      textDirection: dir,
      child: Wrap(
        spacing: t.spaceXs,
        runSpacing: t.spaceXs,
        children: <Widget>[
          for (int i = 0; i < paragraph.words.length; i++)
            GestureDetector(
              onTap: () {
                if (here && sel.start == i && sel.end == i) return cubit.select(null);
                if (here) {
                  final int a = i < sel.start ? i : sel.start;
                  final int b = i > sel.end ? i : sel.end;
                  return cubit.select(WordSelection(pageId: page.id, paragraphId: paragraph.id, start: a, end: b));
                }
                cubit.select(WordSelection(pageId: page.id, paragraphId: paragraph.id, start: i, end: i));
              },
              child: _Word(
                text: paragraph.words[i].text,
                redacted: state.edits.isWordRedacted(key, i),
                selected: here && i >= sel.start && i <= sel.end,
              ),
            ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.text, required this.redacted, required this.selected});

  final String text;
  final bool redacted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final TextStyle style = t.bodyStyle.copyWith(color: redacted ? t.redactionFill : t.onSurface);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceXs / 2),
      decoration: BoxDecoration(
        color: redacted ? t.redactionFill : (selected ? t.primary.withValues(alpha: 0.16) : null),
        borderRadius: BorderRadius.circular(t.radiusSm / 2),
        border: selected ? Border.all(color: t.primary) : null,
      ),
      child: Text(text, style: style),
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
          Expanded(child: Text(label, style: t.captionStyle.copyWith(color: t.onRedactionFill))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Floating bar over a selection: hide or show it, or edit its paragraph (story 8).
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key, required this.strings});

  final DocScanStrings strings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.watch<PreviewCubit>();
    final PreviewState st = cubit.state;
    if (st.selection == null) return const SizedBox.shrink();
    final bool redacted = st.selectionRedacted;
    return Container(
      margin: EdgeInsets.all(t.spaceMd),
      padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
      decoration: BoxDecoration(color: t.onSurface, borderRadius: BorderRadius.circular(t.radiusLg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScanQuietButton(
            label: redacted ? strings.showText : strings.hideSelection,
            icon: redacted ? t.icons.reveal : t.icons.redact,
            color: t.surface,
            onPressed: redacted ? cubit.revealSelection : cubit.redactSelection,
          ),
          SizedBox(width: t.spaceSm),
          ScanQuietButton(
            label: strings.edit,
            icon: t.icons.edit,
            color: t.surface,
            onPressed: () => cubit.setEditing(true),
          ),
        ],
      ),
    );
  }
}
