import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';
import 'attach_bar.dart';
import 'edit_mode_view.dart';
import 'photo_view.dart';
import 'rename_sheet.dart';
import 'text_page_view.dart';

/// «معاينة ملف PDF»: page sidebar, text or photo view, edit mode, and attach
/// (stories 6 to 9, 14, 15).
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key, required this.strings, required this.onCancel, required this.onAttach});

  final DocScanStrings strings;
  final VoidCallback onCancel;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = strings;
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        child: BlocBuilder<PreviewCubit, PreviewState>(
          builder: (BuildContext context, PreviewState st) {
            final PreviewCubit cubit = context.read<PreviewCubit>();
            final CapturedPage page = st.pages[st.currentPage];
            return Column(
              children: <Widget>[
                ScanHeader(
                  title: s.previewTitle,
                  leading: ScanQuietButton(label: s.cancel, onPressed: onCancel),
                  trailing: ScanQuietButton(
                    label: st.editing ? s.done : s.edit,
                    onPressed: () => cubit.setEditing(!st.editing),
                  ),
                ),
                _NameRow(name: '${st.fileStem}.pdf', strings: s),
                if (!st.editing)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
                    child: Text(s.previewTip, style: t.captionStyle.copyWith(color: t.onSurfaceMuted), textAlign: TextAlign.center),
                  ),
                if (!st.editing)
                  Padding(
                    padding: EdgeInsets.all(t.spaceSm),
                    child: ScanSegmented<PreviewView>(
                      options: <PreviewView, String>{PreviewView.text: s.textView, PreviewView.photo: s.photoView},
                      selected: st.view,
                      onChanged: cubit.showView,
                      foreground: t.onSurfaceMuted,
                      selectedForeground: t.onPrimary,
                      selectedBackground: t.primary,
                      background: t.surfaceSecondary,
                    ),
                  ),
                if (st.edits.redactedWordCount > 0)
                  Text(
                    s.redactedWords(st.edits.redactedWordCount),
                    style: t.captionStyle.copyWith(color: t.onSurfaceMuted),
                  ),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      if (st.pages.length > 1) _Sidebar(pages: st.pages, current: st.currentPage, strings: s),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (st.editing)
                              EditModeView(page: page, strings: s)
                            else if (st.view == PreviewView.photo)
                              PhotoView(page: page, strings: s)
                            else
                              TextPageView(page: page, strings: s),
                            Align(alignment: Alignment.bottomCenter, child: SelectionActionBar(strings: s)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AttachBar(
                  strings: s,
                  pageCount: st.pages.length,
                  sizeBytes: st.sizeBytes,
                  busy: st.attaching,
                  failure: st.failure,
                  onAttach: () {
                    FocusScope.of(context).unfocus();
                    onAttach();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.strings});

  final String name;
  final DocScanStrings strings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.read<PreviewCubit>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            textDirection: TextDirection.rtl,
            style: t.bodyStrongStyle.copyWith(color: t.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ScanIconButton(
          icon: t.icons.edit,
          label: strings.rename,
          color: t.onSurfaceMuted,
          size: t.iconSize * 0.8,
          onPressed: () => showRenameSheet(
            context,
            strings: strings,
            current: cubit.state.fileStem,
            onSave: cubit.rename,
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.pages, required this.current, required this.strings});

  final List<CapturedPage> pages;
  final int current;
  final DocScanStrings strings;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final PreviewCubit cubit = context.read<PreviewCubit>();
    return Container(
      width: t.thumbnailSize + t.spaceMd,
      decoration: BoxDecoration(border: BorderDirectional(end: BorderSide(color: t.border))),
      child: ListView.separated(
        padding: EdgeInsets.all(t.spaceXs),
        itemCount: pages.length,
        separatorBuilder: (BuildContext context, int _) => SizedBox(height: t.spaceXs),
        itemBuilder: (BuildContext context, int i) => Semantics(
          button: true,
          selected: i == current,
          label: strings.pageLabel(i + 1),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => cubit.goToPage(i),
            child: Container(
              height: t.thumbnailSize * 1.3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(color: i == current ? t.primary : t.border, width: i == current ? t.frameStrokeWidth : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusSm),
                child: Image.file(pages[i].preparedFile, fit: BoxFit.cover, cacheWidth: 160),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
