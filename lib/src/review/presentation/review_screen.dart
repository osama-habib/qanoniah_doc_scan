import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_event.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/review_cubit.dart';
import 'delete_page_dialog.dart';

/// «مراجعة الصفحات» (story 3, design `scan-review`): a three-column grid where a
/// page is dragged to a new place, removed with its ✕, and put back with the undo
/// button on the moved page. Back returns to «توضيح الصفحات»; corners are set on
/// the camera's corner step.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    super.key,
    required this.strings,
    required this.onBack,
    required this.onCancel,
    required this.onAddPage,
    required this.onRetakeLast,
    required this.onOpenFilters,
    required this.onBuild,
    required this.onAttachImages,
    required this.onEmpty,
  });

  final DocScanStrings strings;

  /// Back to «توضيح الصفحات».
  final VoidCallback onBack;

  /// Discards the scan. The camera's cancel keeps pages (owner, 2026-11-03), so
  /// review keeps a way out.
  final VoidCallback onCancel;
  final VoidCallback onAddPage;

  // TODO(unused): the design's review has no «إعادة التقاط الأخيرة»; kept for
  // when retake comes back.
  final void Function(String pageId) onRetakeLast;

  // TODO(unused): the design's tiles open no filters; back opens them.
  final void Function(int index) onOpenFilters;

  /// «إنشاء مستند قابل للتعديل»: build with recognized text.
  final VoidCallback onBuild;

  /// «إرفاق كملف PDF»: the photos as one PDF, straight to the preview.
  final VoidCallback onAttachImages;

  /// The last page was deleted: back to the camera.
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = strings;
    final TextStyle note = t.captionStyle.sized(12, 18).copyWith(color: t.onSurfaceMuted);
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        child: BlocBuilder<ReviewCubit, ReviewState>(
          builder: (BuildContext context, ReviewState st) {
            final bool enabled = st.canBuild && !st.working;
            return Column(
              children: <Widget>[
                ScanHeader(
                  title: s.reviewPages,
                  divider: true,
                  leading: ScanIconButton(
                    icon: t.icons.back,
                    label: s.back,
                    mirrorInRtl: true,
                    color: t.onSurface,
                    background: t.surfaceTertiary,
                    onPressed: onBack,
                  ),
                  trailing: ScanQuietButton(label: s.cancel, onPressed: onCancel),
                ),
                if (st.working)
                  LinearProgressIndicator(minHeight: 2, color: t.primary, backgroundColor: t.surfaceSecondary),
                Expanded(
                  child: ListView(
                    padding: ScanMetrics.content,
                    children: <Widget>[
                      Text(s.reorderHint, style: note),
                      const SizedBox(height: 12),
                      _Grid(pages: st.pages, lastMove: st.lastMove, strings: s, onEmpty: onEmpty, onAddPage: onAddPage),
                      const SizedBox(height: 16),
                      Text(s.attachNote, style: note),
                      if (st.storageFull) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(s.storageFull, style: note.copyWith(color: t.danger)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: ScanMetrics.reviewBar,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.surfaceTertiary)),
                  ),
                  child: Column(
                    children: <Widget>[
                      ScanPrimaryButton(label: s.buildDocument, onPressed: enabled ? onBuild : null),
                      const SizedBox(height: 10),
                      ScanSecondaryButton(label: s.attach, onPressed: enabled ? onAttachImages : null),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.pages,
    required this.lastMove,
    required this.strings,
    required this.onEmpty,
    required this.onAddPage,
  });

  final List<CapturedPage> pages;
  final PageMove? lastMove;
  final DocScanStrings strings;
  final VoidCallback onEmpty;
  final VoidCallback onAddPage;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = (c.maxWidth - _gap * 2) / 3;
        // A 3:4 card, 4 of gap and a 16 label line under it.
        final double tileHeight = w * 4 / 3 + 4 + 16;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            mainAxisExtent: tileHeight,
          ),
          // The last cell is the dashed «إضافة صفحة» tile.
          itemCount: pages.length + 1,
          itemBuilder: (BuildContext context, int i) => i == pages.length
              ? Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: w,
                    height: w * 1.38,
                    child: _AddTile(label: strings.addPage, onTap: onAddPage),
                  ),
                )
              : _Tile(
                  key: ValueKey<String>(pages[i].id),
                  page: pages[i],
                  index: i,
                  count: pages.length,
                  moved: lastMove?.toIndex == i,
                  strings: strings,
                  onEmpty: onEmpty,
                ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.page,
    required this.index,
    required this.count,
    required this.moved,
    required this.strings,
    required this.onEmpty,
  });

  final CapturedPage page;
  final int index;
  final int count;

  /// The page the last drag moved: gets the dashed ring and the undo button.
  final bool moved;
  final DocScanStrings strings;
  final VoidCallback onEmpty;

  Future<void> _delete(BuildContext context) async {
    final ReviewCubit cubit = context.read<ReviewCubit>();
    final bool ok = await showDeletePageDialog(
      context,
      strings: strings,
      pageNumber: index + 1,
      page: page.preparedFile,
    );
    if (ok && await cubit.deletePage(page.id)) onEmpty();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final ReviewCubit cubit = context.read<ReviewCubit>();
    return Semantics(
      label: strings.pageLabel(index + 1),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (index > 0)
          CustomSemanticsAction(label: strings.moveEarlier): () => cubit.move(index, index - 1, via: MoveVia.action),
        if (index < count - 1)
          CustomSemanticsAction(label: strings.moveLater): () => cubit.move(index, index + 1, via: MoveVia.action),
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Size size = Size(c.maxWidth, c.maxWidth * 4 / 3);
          return DragTarget<int>(
            onWillAcceptWithDetails: (DragTargetDetails<int> d) => d.data != index,
            onAcceptWithDetails: (DragTargetDetails<int> d) => cubit.move(d.data, index),
            builder: (BuildContext context, List<int?> hovering, List<dynamic> _) => Column(
              children: <Widget>[
                LongPressDraggable<int>(
                  data: index,
                  feedback: SizedBox.fromSize(size: size, child: _card(context, t, lifted: true)),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: SizedBox.fromSize(size: size, child: _card(context, t)),
                  ),
                  child: SizedBox.fromSize(
                    size: size,
                    child: _card(context, t, lifted: hovering.isNotEmpty),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.pageShort(index + 1),
                  maxLines: 1,
                  style: t.captionStyle
                      .sized(12, 16)
                      .copyWith(
                        color: t.onSurface,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, DocScanTheme t, {bool lifted = false}) {
    final ReviewCubit cubit = context.read<ReviewCubit>();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: ScanMetrics.radius(8),
        border: Border.all(color: lifted ? t.primary : t.border, width: lifted ? 2 : 1),
        boxShadow: lifted
            ? <BoxShadow>[
                BoxShadow(color: t.primary.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.file(page.preparedFile, fit: BoxFit.cover, cacheWidth: 360),
          if (moved) ...<Widget>[
            Padding(
              padding: ScanMetrics.movedRing,
              child: CustomPaint(painter: _DashedBorder(color: t.primary, radius: 6, width: 1.5)),
            ),
            PositionedDirectional(
              top: 5,
              start: 5,
              child: _Round(
                label: strings.undoMove,
                color: t.surface,
                shadow: true,
                onTap: cubit.undoMove,
                child: DocScanIcon(t.icons.undo, size: 13, color: t.primary),
              ),
            ),
          ],
          PositionedDirectional(
            bottom: 5,
            start: 5,
            child: ExcludeSemantics(
              child: Container(
                width: 22,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.92),
                  borderRadius: ScanMetrics.radius(7),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: t.scrim.withValues(alpha: 0.18), blurRadius: 3, offset: const Offset(0, 1)),
                  ],
                ),
                child: DocScanIcon(t.icons.dragHandle, size: 16, color: t.onSurfaceMuted),
              ),
            ),
          ),
          PositionedDirectional(
            top: 5,
            end: 5,
            child: _Round(
              label: strings.deletePage,
              color: t.inverseSurface.withValues(alpha: 0.72),
              onTap: () => _delete(context),
              child: DocScanIcon(t.icons.delete, size: 11, color: t.surface),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 24 round button on a review tile.
class _Round extends StatelessWidget {
  const _Round({
    required this.label,
    required this.color,
    required this.onTap,
    required this.child,
    this.shadow = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: shadow
                ? <BoxShadow>[
                    BoxShadow(color: t.scrim.withValues(alpha: 0.2), blurRadius: 3, offset: const Offset(0, 1)),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The dashed «إضافة صفحة» cell at the end of the grid.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: _DashedBorder(color: t.border, radius: 8, width: 1),
          child: Container(
            decoration: BoxDecoration(color: t.surfaceSecondary, borderRadius: ScanMetrics.radius(8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DocScanIcon(t.icons.addPage, size: 20, color: t.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: t.captionStyle.sized(12, 16).copyWith(color: t.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius, required this.width});

  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final Rect r = (Offset.zero & size).deflate(width / 2);
    final Path path = Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    final double dash = math.max(3, width * 3);
    for (final PathMetric m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += dash * 2) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius || old.width != width;
}
