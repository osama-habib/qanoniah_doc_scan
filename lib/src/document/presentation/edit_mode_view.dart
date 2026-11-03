import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';
import 'text_page_view.dart';

// TODO(unused): the design has no edit mode; «تعديل» on a selection opens
// the paragraph in place (TextPageView). Kept for paragraph redaction.
/// Edit mode: every paragraph is a text field; the eye button redacts it whole
/// (stories 7 and 9).
class EditModeView extends StatelessWidget {
  const EditModeView({super.key, required this.page, required this.strings});

  final CapturedPage page;
  final DocScanStrings strings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final RecognitionState r = page.recognition;
    if (r is! RecognitionDone) {
      return Center(child: Text(strings.noTextOnPage, style: t.bodyStyle.copyWith(color: t.onSurfaceMuted)));
    }
    final TextDirection dir = r.text.language == RecognitionLanguage.ar ? TextDirection.rtl : TextDirection.ltr;
    return ListView(
      padding: EdgeInsets.all(t.spaceLg),
      children: <Widget>[
        Text(strings.editHint, style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
        SizedBox(height: t.spaceMd),
        for (final Paragraph p in r.text.paragraphs)
          Padding(
            padding: EdgeInsets.only(bottom: t.spaceMd),
            child: _ParagraphEditor(key: ValueKey<String>('${page.id}/${p.id}'), page: page, paragraph: p, dir: dir, strings: strings),
          ),
      ],
    );
  }
}

class _ParagraphEditor extends StatefulWidget {
  const _ParagraphEditor({super.key, required this.page, required this.paragraph, required this.dir, required this.strings});

  final CapturedPage page;
  final Paragraph paragraph;
  final TextDirection dir;
  final DocScanStrings strings;

  @override
  State<_ParagraphEditor> createState() => _ParagraphEditorState();
}

class _ParagraphEditorState extends State<_ParagraphEditor> {
  late final TextEditingController _c = TextEditingController(
    text: context.read<PreviewCubit>().state.edits.textOf(widget.page.id, widget.paragraph),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit() => context.read<PreviewCubit>().editParagraph(widget.page.id, widget.paragraph, _c.text);

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.watch<PreviewCubit>();
    final bool redacted = cubit.state.edits.isParagraphRedacted((widget.page.id, widget.paragraph.id));
    final Widget eye = ScanIconButton(
      icon: redacted ? t.icons.reveal : t.icons.redact,
      label: redacted ? widget.strings.showParagraph : widget.strings.hideParagraph,
      color: redacted ? t.onRedactionFill : t.onSurfaceMuted,
      onPressed: () => cubit.toggleParagraphRedaction(widget.page.id, widget.paragraph.id),
    );
    if (redacted) return RedactedBar(label: widget.strings.redactedText, trailing: eye);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Focus(
            onFocusChange: (bool has) {
              if (!has) _commit();
            },
            child: TextField(
              controller: _c,
              textDirection: widget.dir,
              maxLines: null,
              style: t.bodyStyle.copyWith(color: t.onSurface),
              cursorColor: t.primary,
              onEditingComplete: _commit,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: t.surfaceSecondary,
                contentPadding: EdgeInsets.all(t.spaceSm),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  borderSide: BorderSide(color: t.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  borderSide: BorderSide(color: t.primary),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: t.spaceXs),
        eye,
      ],
    );
  }
}
