import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/preview_cubit.dart';
import 'attach_bar.dart';
import 'text_page_view.dart';

/// «معاينة ملف PDF» (stories 5 to 8, 15, design `scanPdf`): every page on a gray
/// canvas, as recognized text («إنشاء مستند قابل للتعديل») or as the photos
/// («إرفاق كملف PDF» from review). The header renames the file in place and opens
/// «كل الصفحات»; selecting text hides it or opens its paragraph.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.strings, required this.onBack, required this.onAttach});

  final DocScanStrings strings;

  /// Back to review.
  final VoidCallback onBack;
  final VoidCallback onAttach;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _pageKeys = <String, GlobalKey>{};
  bool _sidebar = false;
  bool _renaming = false;

  /// The paragraph open in place, as (page id, paragraph id).
  (String, String)? _editing;

  GlobalKey _keyOf(String pageId) => _pageKeys.putIfAbsent(pageId, GlobalKey.new);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _back() {
    if (_sidebar) return setState(() => _sidebar = false);
    widget.onBack();
  }

  void _goTo(PreviewCubit cubit, int index) {
    cubit.goToPage(index);
    final BuildContext? c = _keyOf(cubit.state.pages[index].id).currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Keeps «كل الصفحات» on the page at the top of the view.
  bool _onScroll(PreviewCubit cubit, ScrollNotification n) {
    if (n is! ScrollEndNotification) return false;
    final List<CapturedPage> pages = cubit.state.pages;
    for (int i = 0; i < pages.length; i++) {
      final RenderObject? box = _keyOf(pages[i].id).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final RenderObject? viewport = context.findRenderObject();
      final double bottom = box.localToGlobal(Offset(0, box.size.height), ancestor: viewport).dy;
      if (bottom > 120) {
        cubit.goToPage(i);
        break;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        child: BlocBuilder<PreviewCubit, PreviewState>(
          builder: (BuildContext context, PreviewState st) {
            final PreviewCubit cubit = context.read<PreviewCubit>();
            final bool photos = st.view == PreviewView.photo;
            final TextStyle bar = t.captionStyle.sized(12, 18).copyWith(color: t.onSurface);
            return Column(
              children: <Widget>[
                _Header(
                  strings: s,
                  state: st,
                  renaming: _renaming,
                  sidebar: _sidebar,
                  onBack: _back,
                  onRename: (bool on) => setState(() => _renaming = on),
                  onSidebar: () => setState(() => _sidebar = !_sidebar),
                ),
                if (!photos)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.surfaceSecondary,
                      border: Border(bottom: BorderSide(color: t.surfaceTertiary)),
                    ),
                    child: Text(s.previewTip, style: bar),
                  ),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ColoredBox(
                          color: t.canvas,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification n) => _onScroll(cubit, n),
                            child: ListView.separated(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              itemCount: st.pages.length,
                              separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 14),
                              itemBuilder: (BuildContext context, int i) {
                                final CapturedPage page = st.pages[i];
                                return KeyedSubtree(
                                  key: _keyOf(page.id),
                                  child: Semantics(
                                    label: s.pageLabel(i + 1),
                                    child: photos
                                        ? _PhotoPage(page: page, number: i + 1)
                                        : TextPageView(
                                            page: page,
                                            strings: s,
                                            editing: _editing?.$1 == page.id ? _editing?.$2 : null,
                                            onEditDone: () => setState(() => _editing = null),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_sidebar)
                        PositionedDirectional(
                          top: 0,
                          bottom: 0,
                          end: 0,
                          child: _Sidebar(
                            pages: st.pages,
                            current: st.currentPage,
                            photos: photos,
                            strings: s,
                            onTap: (int i) => _goTo(cubit, i),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: SelectionActionBar(
                            strings: s,
                            onEdit: (WordSelection sel) => setState(() => _editing = (sel.pageId, sel.paragraphId)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AttachBar(
                  strings: s,
                  hiddenWords: st.edits.redactedWordCount,
                  busy: st.attaching,
                  failure: st.failure,
                  onAttach: () {
                    FocusScope.of(context).unfocus();
                    widget.onAttach();
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

/// Back, the PDF icon with the file name (tap to rename in place), the page
/// count and «كل الصفحات».
class _Header extends StatelessWidget {
  const _Header({
    required this.strings,
    required this.state,
    required this.renaming,
    required this.sidebar,
    required this.onBack,
    required this.onRename,
    required this.onSidebar,
  });

  final DocScanStrings strings;
  final PreviewState state;
  final bool renaming;
  final bool sidebar;
  final VoidCallback onBack;
  final ValueChanged<bool> onRename;
  final VoidCallback onSidebar;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final TextStyle name = t.bodyStyle.sized(14, 20).copyWith(color: t.onSurface, fontWeight: FontWeight.w700);
    // Design `scanPreview` (pk7): the shared header, so the file name sits in
    // the middle of the screen however wide the page count is.
    return ScanHeader(
      title: strings.previewTitle,
      divider: true,
      leading: ScanIconButton(
        icon: t.icons.back,
        label: strings.back,
        mirrorInRtl: true,
        color: t.onSurface,
        background: t.surfaceTertiary,
        onPressed: onBack,
      ),
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(t.icons.pdf, width: 18, height: 22),
          const SizedBox(width: 8),
          if (renaming)
            Flexible(
              child: _RenameField(
                initial: state.fileStem,
                style: name.sized(16, 20),
                strings: strings,
                onDone: () => onRename(false),
              ),
            )
          else
            Flexible(
              child: Semantics(
                button: true,
                label: strings.rename,
                child: GestureDetector(
                  onTap: () => onRename(true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '\u2068${state.fileStem}\u2069.pdf',
                          style: name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      DocScanIcon(t.icons.edit, size: 14, color: t.onSurfaceMuted),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.pageCount(state.pages.length),
            style: t.captionStyle
                .sized(12, 16)
                .copyWith(color: t.onSurfaceMuted, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: ScanMetrics.headerGroupGap),
          ScanIconButton(
            icon: t.icons.pages,
            label: strings.allPages,
            color: t.onSurface,
            // TODO(ahmed): design's active fill is #eef3fd, no kit token; brand
            // navy at 7% over white is the nearest.
            background: sidebar ? t.primary.withValues(alpha: 0.07) : t.surfaceTertiary,
            onPressed: onSidebar,
          ),
        ],
      ),
    );
  }
}

/// The file name in place, with a fixed «.pdf» (design `scanNameEditing`).
class _RenameField extends StatefulWidget {
  const _RenameField({required this.initial, required this.style, required this.strings, required this.onDone});

  final String initial;
  final TextStyle style;
  final DocScanStrings strings;
  final VoidCallback onDone;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _save() {
    if (_done) return;
    _done = true;
    // An empty or invalid name keeps the old one.
    context.read<PreviewCubit>().rename(_c.text);
    widget.onDone();
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.primary),
        borderRadius: ScanMetrics.radius(8),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _c,
              focusNode: _focus,
              style: widget.style,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.deny(RegExp(r'[/\\:]'))],
              onSubmitted: (_) => _focus.unfocus(),
              onTapOutside: (_) => _focus.unfocus(),
              decoration: InputDecoration.collapsed(hintText: widget.strings.rename),
            ),
          ),
          Text(
            '.pdf',
            textDirection: TextDirection.ltr,
            style: t.captionStyle.sized(13, 20).copyWith(color: t.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// A photo page on A4 paper with its number at the bottom (design `scanImgMode`).
class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.page, required this.number});

  final CapturedPage page;
  final int number;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) => Container(
          decoration: BoxDecoration(color: t.surface, boxShadow: pageShadow(t)),
          padding: EdgeInsets.fromLTRB(c.maxWidth * 0.06, c.maxWidth * 0.06, c.maxWidth * 0.06, c.maxWidth * 0.09),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(child: Image.file(page.preparedFile, fit: BoxFit.contain, cacheWidth: 1200)),
              Positioned(
                left: 0,
                right: 0,
                bottom: -c.maxWidth * 0.06,
                child: Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: t.captionStyle.sized(9, 12).copyWith(color: t.onSurfaceMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «كل الصفحات»: a 96 wide frosted column of page thumbnails (design `scanGrid`).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.pages,
    required this.current,
    required this.photos,
    required this.strings,
    required this.onTap,
  });

  final List<CapturedPage> pages;
  final int current;
  final bool photos;
  final DocScanStrings strings;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: t.surfaceSecondary.withValues(alpha: 0.94),
        border: BorderDirectional(start: BorderSide(color: t.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: t.inverseSurface.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(-6, 0)),
        ],
      ),
      child: ListView.separated(
        padding: ScanMetrics.sidebar,
        itemCount: pages.length,
        separatorBuilder: (BuildContext context, int _) => const SizedBox(height: 14),
        itemBuilder: (BuildContext context, int i) {
          final bool on = i == current;
          return Semantics(
            button: true,
            selected: on,
            label: strings.pageLabel(i + 1),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                children: <Widget>[
                  Container(
                    padding: ScanMetrics.ring,
                    decoration: BoxDecoration(
                      borderRadius: ScanMetrics.radius(6),
                      border: Border.all(color: on ? t.primary : t.border, width: on ? 2 : 1),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1 / 1.414,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: ScanMetrics.radius(4),
                          boxShadow: pageShadow(t),
                        ),
                        child: photos
                            ? Padding(
                                padding: ScanMetrics.thumbPaper,
                                child: Image.file(pages[i].preparedFile, fit: BoxFit.contain, cacheWidth: 200),
                              )
                            : IgnorePointer(
                                child: FittedBox(
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: 360,
                                    child: TextPageView(page: pages[i], strings: strings),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: on ? t.primary : null, borderRadius: ScanMetrics.radius(18)),
                    child: Text(
                      '${i + 1}',
                      style: t.captionStyle
                          .sized(11, 11)
                          .copyWith(color: on ? t.onPrimary : t.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
