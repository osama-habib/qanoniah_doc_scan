import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/review_cubit.dart';

/// «توضيح الصفحات»: the step between the camera and review (story 13, design
/// `scan-filter`). A large page with previous/next and «تدوير», a strip of filters
/// previewed on the page itself, one at a time (owner decision 2026-11-04), and
/// «تطبيق على كل الصفحات» (on by default).
///
/// The strip previews filters with color matrices; the large page shows the real
/// result once [ReviewCubit] has re-prepared it.
class FiltersScreen extends StatefulWidget {
  const FiltersScreen({
    super.key,
    required this.strings,
    required this.initialIndex,
    required this.onBack,
    required this.onNext,
  });

  final DocScanStrings strings;
  final int initialIndex;

  /// Back to the camera to add pages.
  final VoidCallback onBack;

  /// «التالي»: to review.
  final VoidCallback onNext;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late int _index = widget.initialIndex;
  bool _allPages = true;

  /// The strip's real previews of the current page, and which page version
  /// they show.
  Map<PageFilter, File> _previews = const <PageFilter, File>{};
  String? _previewsOf;

  void _loadPreviews(ReviewCubit cubit, CapturedPage page) {
    final String key = '${page.rawFile.path}|${page.corners}|${page.turns}';
    if (key == _previewsOf) return;
    _previewsOf = key;
    _previews = const <PageFilter, File>{};
    unawaited(
      cubit.filterPreviews(page, _filters).then((Map<PageFilter, File> p) {
        if (mounted && _previewsOf == key) setState(() => _previews = p);
      }),
    );
  }

  static const List<PageFilter> _filters = <PageFilter>[
    PageFilter.original,
    PageFilter.autoEnhance,
    PageFilter.sharpenText,
    PageFilter.removeShadows,
    PageFilter.highContrast,
    PageFilter.grayscale,
    PageFilter.blackWhite,
  ];

  String _label(PageFilter f) => switch (f) {
    PageFilter.original => widget.strings.filterOriginal,
    PageFilter.autoEnhance => widget.strings.filterAuto,
    PageFilter.sharpenText => widget.strings.filterText,
    PageFilter.removeShadows => widget.strings.filterShadow,
    PageFilter.highContrast => widget.strings.filterContrast,
    PageFilter.grayscale => widget.strings.filterGray,
    PageFilter.blackWhite => widget.strings.filterBw,
  };

  void _apply(ReviewCubit cubit, CapturedPage page, Set<PageFilter> next) {
    unawaited(cubit.setFilters(next, pageId: _allPages ? null : page.id));
  }

  /// A horizontal swipe on the page: toward the reading end shows the next page
  /// (right in Arabic), back toward the start the previous one.
  void _swipe(DragEndDetails d, int i, int count) {
    final double v = d.primaryVelocity ?? 0;
    if (v.abs() < 200) return;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final bool next = rtl ? v > 0 : v < 0;
    final int to = next ? i + 1 : i - 1;
    if (to >= 0 && to < count) setState(() => _index = to);
  }

  /// One filter at a time: the tapped one replaces the current one; tapping the
  /// current one goes back to the original.
  void _choose(ReviewCubit cubit, CapturedPage page, PageFilter f) {
    final bool current = page.filters.contains(f) && page.filters.length == 1;
    unawaited(cubit.setFilter(current ? PageFilter.original : f, pageId: _allPages ? null : page.id));
  }

  /// The page's one filter; the original when none (or, from before filters were
  /// single, the first of several).
  PageFilter _current(CapturedPage page) => _filters.firstWhere(
    (PageFilter f) => f != PageFilter.original && page.filters.contains(f),
    orElse: () => PageFilter.original,
  );

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    final Color panel = Color.alphaBlend(t.onCameraSurface.withValues(alpha: 0.06), t.cameraSurface);
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (BuildContext context, ReviewState st) {
        final ReviewCubit cubit = context.read<ReviewCubit>();
        if (st.pages.isEmpty) return ColoredBox(color: t.cameraSurface);
        final int i = _index.clamp(0, st.pages.length - 1);
        final CapturedPage page = st.pages[i];
        _loadPreviews(cubit, page);
        final bool many = st.pages.length > 1;
        final bool any = page.filters.any((PageFilter f) => f != PageFilter.original);
        return ColoredBox(
          color: t.cameraSurface,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                // Design `scan-filter` header: back, the title and page count,
                // «التالي»; 12 between them.
                Padding(
                  padding: ScanMetrics.filtersHeader,
                  child: Row(
                    children: <Widget>[
                      ScanIconButton(
                        icon: t.icons.back,
                        label: s.addPage,
                        mirrorInRtl: true,
                        color: t.onCameraSurface,
                        background: t.onCameraSurface.withValues(alpha: 0.12),
                        onPressed: widget.onBack,
                      ),
                      SizedBox(width: t.spaceMd),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Semantics(
                              header: true,
                              child: Text(
                                s.filtersTitle,
                                style: t.bodyStyle
                                    .sized(16, 24)
                                    .copyWith(color: t.onCameraSurface, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              s.pageOf(i + 1, st.pages.length),
                              style: t.captionStyle.sized(12, 16).copyWith(color: t.onCameraSurfaceMuted),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: t.spaceMd),
                      _Pill(label: s.next, onTap: st.working ? null : widget.onNext),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.spaceXs, vertical: t.spaceSm),
                    // The arrows sit beside the page, not over its edges: the page's
                    // slot keeps its size while a re-prepared page loads, so the
                    // arrows stay where they can be tapped (pk0).
                    child: Row(
                      children: <Widget>[
                        _PageArrow(
                          show: many,
                          enabled: i > 0,
                          label: s.pageLabel(i),
                          onTap: () => setState(() => _index = i - 1),
                        ),
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey<String>('filters-page'),
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: many ? (DragEndDetails d) => _swipe(d, i, st.pages.length) : null,
                            child: Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(t.radiusSm / 2),
                                  child: Image.file(
                                    page.preparedFile,
                                    key: ValueKey<String>(page.preparedFile.path),
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  ),
                                ),
                                if (st.working)
                                  Center(
                                    child: CircularProgressIndicator(
                                      color: t.onCameraSurface,
                                      strokeWidth: t.frameStrokeWidth,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        _PageArrow(
                          show: many,
                          enabled: i < st.pages.length - 1,
                          next: true,
                          label: s.pageLabel(i + 2),
                          onTap: () => setState(() => _index = i + 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
                  ),
                  padding: EdgeInsets.only(top: t.spaceMd),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: t.spaceLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
                            child: Row(
                              children: <Widget>[
                                Text(s.filtersPanelTitle, style: t.bodyStrongStyle.copyWith(color: t.onCameraSurface)),
                                const Spacer(),
                                if (any)
                                  ScanQuietButton(
                                    label: s.resetFilters,
                                    color: t.onCameraSurfaceMuted,
                                    onPressed: () => _apply(cubit, page, const <PageFilter>{PageFilter.original}),
                                  ),
                                // «تدوير» for this page (not in the design: kept out of
                                // the header, which follows it).
                                ScanIconButton(
                                  icon: t.icons.rotate,
                                  label: s.rotate,
                                  color: t.onCameraSurface,
                                  background: t.onCameraSurface.withValues(alpha: 0.12),
                                  onPressed: st.working ? null : () => unawaited(cubit.rotate(page.id)),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: t.spaceSm),
                          SizedBox(
                            // Thumbnail, gap, and one caption line at the user's text size.
                            height:
                                t.thumbnailSize * 1.5 +
                                t.spaceXs +
                                MediaQuery.textScalerOf(context).scale(t.captionStyle.fontSize ?? t.iconSize) *
                                    (t.captionStyle.height ?? 1.5) +
                                t.spaceXs,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
                              itemCount: _filters.length,
                              separatorBuilder: (BuildContext context, int _) => SizedBox(width: t.spaceSm),
                              itemBuilder: (BuildContext context, int k) => _FilterChip(
                                filter: _filters[k],
                                label: _label(_filters[k]),
                                page: page,
                                preview: _previews[_filters[k]],
                                on: _current(page) == _filters[k],
                                onTap: st.working ? null : () => _choose(cubit, page, _filters[k]),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(t.spaceLg, t.spaceXs, t.spaceLg, 0),
                            child: Text(s.filtersHint, style: t.captionStyle.copyWith(color: t.onCameraSurfaceMuted)),
                          ),
                          if (many)
                            Padding(
                              padding: EdgeInsets.fromLTRB(t.spaceLg, t.spaceSm, t.spaceLg, 0),
                              child: Material(
                                color: t.onCameraSurface.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(t.radiusMd),
                                child: SwitchListTile.adaptive(
                                  value: _allPages,
                                  activeTrackColor: t.primary,
                                  title: Text(s.applyToAllPages, style: t.bodyStyle.copyWith(color: t.onCameraSurface)),
                                  onChanged: st.working
                                      ? null
                                      : (bool on) {
                                          setState(() => _allPages = on);
                                          if (on) unawaited(cubit.setFilters(page.filters));
                                        },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A previous or next page arrow beside the page; an empty slot of the same
/// width for a single page, so the page keeps its place.
class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.show,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.next = false,
  });

  final bool show;
  final bool enabled;
  final String label;
  final VoidCallback onTap;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final Widget button = ScanIconButton(
      icon: t.icons.back,
      label: label,
      mirrorInRtl: true,
      size: t.iconSize * 0.75,
      color: t.onCameraSurface,
      background: t.onCameraSurface.withValues(alpha: 0.14),
      onPressed: enabled ? onTap : null,
    );
    return SizedBox(
      width: t.iconSize * 1.5 + t.spaceSm,
      child: !show
          ? null
          : Center(
              child: Opacity(
                opacity: enabled ? 1 : 0.35,
                child: next ? Transform.flip(flipX: true, child: button) : button,
              ),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    // Design: 36 high, 16 at the sides, a 14 / 20 bold label, fully rounded.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: t.onCameraSurface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
            alignment: Alignment.center,
            child: Text(
              label,
              style: t.buttonStyle.sized(14, 20).copyWith(color: t.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// One filter: the cropped page with that filter really applied (a small
/// preview), its name, and a check when it is on. Until the preview is made, the
/// cropped page under an approximation of the filter.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.label,
    required this.page,
    required this.preview,
    required this.on,
    required this.onTap,
  });

  final PageFilter filter;
  final String label;
  final CapturedPage page;
  final File? preview;
  final bool on;
  final VoidCallback? onTap;

  // Previews only: the page is re-prepared with the real filter when chosen.
  static const List<double> _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  static const List<double> _gray = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _bw = <double>[
    0.64,
    2.15,
    0.22,
    0,
    -300,
    0.64,
    2.15,
    0.22,
    0,
    -300,
    0.64,
    2.15,
    0.22,
    0,
    -300,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _contrast = <double>[
    1.5,
    0,
    0,
    0,
    -64,
    0,
    1.5,
    0,
    0,
    -64,
    0,
    0,
    1.5,
    0,
    -64,
    0,
    0,
    0,
    1,
    0,
  ];
  static const List<double> _bright = <double>[1.15, 0, 0, 0, 18, 0, 1.15, 0, 0, 18, 0, 0, 1.15, 0, 18, 0, 0, 0, 1, 0];
  static const List<double> _text = <double>[1.3, 0, 0, 0, -38, 0, 1.3, 0, 0, -38, 0, 0, 1.3, 0, -38, 0, 0, 0, 1, 0];

  List<double> get _matrix => switch (filter) {
    PageFilter.original => _identity,
    PageFilter.autoEnhance => _bright,
    PageFilter.sharpenText => _text,
    PageFilter.removeShadows => _bright,
    PageFilter.highContrast => _contrast,
    PageFilter.grayscale => _gray,
    PageFilter.blackWhite => _bw,
  };

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final double size = t.thumbnailSize * 1.5;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            children: <Widget>[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  border: Border.all(color: on ? t.onCameraSurface : t.cameraSurface, width: t.frameStrokeWidth),
                  color: t.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (preview != null)
                      Image.file(
                        preview!,
                        key: ValueKey<String>(preview!.path),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    else
                      ColorFiltered(
                        colorFilter: ColorFilter.matrix(_matrix),
                        child: Image.file(page.preparedFile, fit: BoxFit.cover, cacheWidth: 200, gaplessPlayback: true),
                      ),
                    if (on)
                      PositionedDirectional(
                        top: t.spaceXs,
                        end: t.spaceXs,
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: t.primary),
                          padding: EdgeInsets.all(t.spaceXs / 2),
                          child: DocScanIcon(t.icons.done, size: t.iconSize * 0.5, color: t.onPrimary),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.captionStyle.copyWith(
                  color: on ? t.onCameraSurface : t.onCameraSurfaceMuted,
                  fontWeight: on ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
