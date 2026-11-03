import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_event.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/review_cubit.dart';
import 'corner_adjust_screen.dart';
import 'delete_page_dialog.dart';

/// The review grid (story 3, with 11 and 12 from the tile menu). Back returns to
/// «توضيح الصفحات», where story 13's filters live (design `scan-review`).
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
  final void Function(String pageId) onRetakeLast;

  /// «توضيح الصفحات» on one page, from its tile menu.
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
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        child: BlocBuilder<ReviewCubit, ReviewState>(
          builder: (BuildContext context, ReviewState st) {
            final ReviewCubit cubit = context.read<ReviewCubit>();
            return Column(
              children: <Widget>[
                ScanHeader(
                  title: s.reviewPages,
                  leading: ScanIconButton(
                    icon: t.icons.back,
                    label: s.back,
                    mirrorInRtl: true,
                    color: t.onSurface,
                    background: t.surfaceSecondary,
                    onPressed: onBack,
                  ),
                  trailing: ScanQuietButton(label: s.cancel, onPressed: onCancel),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceXs),
                  child: Text(s.reorderHint, style: t.captionStyle.copyWith(color: t.onSurfaceMuted), textAlign: TextAlign.center),
                ),
                if (st.working) LinearProgressIndicator(color: t.primary, backgroundColor: t.surfaceSecondary),
                Expanded(
                  child: _Grid(
                    pages: st.pages,
                    strings: s,
                    onEmpty: onEmpty,
                    onAddPage: onAddPage,
                    onOpenFilters: onOpenFilters,
                  ),
                ),
                if (st.canUndo)
                  _UndoBar(label: s.undoMove, onUndo: cubit.undoMove),
                if (st.storageFull)
                  Padding(
                    padding: EdgeInsets.all(t.spaceSm),
                    child: Text(s.storageFull, style: t.captionStyle.copyWith(color: t.danger)),
                  ),
                Padding(
                  padding: EdgeInsets.all(t.spaceLg),
                  child: Column(
                    children: <Widget>[
                      if (st.pages.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ScanQuietButton(
                            label: s.retakeLast,
                            icon: t.icons.retake,
                            onPressed: () => onRetakeLast(st.pages.last.id),
                          ),
                        ),
                      Text(s.attachNote, style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
                      SizedBox(height: t.spaceMd),
                      ScanPrimaryButton(
                        label: s.buildDocument,
                        onPressed: st.canBuild && !st.working ? onBuild : null,
                      ),
                      SizedBox(height: t.spaceSm),
                      ScanSecondaryButton(
                        label: s.attach,
                        onPressed: st.canBuild && !st.working ? onAttachImages : null,
                      ),
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
    required this.strings,
    required this.onEmpty,
    required this.onAddPage,
    required this.onOpenFilters,
  });

  final List<CapturedPage> pages;
  final DocScanStrings strings;
  final VoidCallback onEmpty;
  final VoidCallback onAddPage;
  final void Function(int index) onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int columns = math.max(3, (c.maxWidth / (t.thumbnailSize * 2.6)).floor());
        return GridView.builder(
          padding: EdgeInsets.all(t.spaceMd),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: t.spaceMd,
            crossAxisSpacing: t.spaceMd,
            childAspectRatio: 0.7,
          ),
          // The last cell is the dashed «إضافة صفحة» tile (design).
          itemCount: pages.length + 1,
          itemBuilder: (BuildContext context, int i) => i == pages.length
              ? _AddTile(label: strings.addPage, onTap: onAddPage)
              : _Tile(
            key: ValueKey<String>(pages[i].id),
            page: pages[i],
            index: i,
            count: pages.length,
            strings: strings,
            onEmpty: onEmpty,
            onOpenFilters: onOpenFilters,
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
    required this.strings,
    required this.onEmpty,
    required this.onOpenFilters,
  });

  final CapturedPage page;
  final int index;
  final int count;
  final DocScanStrings strings;
  final void Function(int index) onOpenFilters;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final ReviewCubit cubit = context.read<ReviewCubit>();
    final Widget card = _card(t, highlighted: false);
    return Semantics(
      label: strings.pageLabel(index + 1),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (index > 0)
          CustomSemanticsAction(label: strings.moveEarlier): () => cubit.move(index, index - 1, via: MoveVia.action),
        if (index < count - 1)
          CustomSemanticsAction(label: strings.moveLater): () => cubit.move(index, index + 1, via: MoveVia.action),
      },
      child: DragTarget<int>(
        onWillAcceptWithDetails: (DragTargetDetails<int> d) => d.data != index,
        onAcceptWithDetails: (DragTargetDetails<int> d) => cubit.move(d.data, index),
        builder: (BuildContext context, List<int?> hovering, List<dynamic> _) => LongPressDraggable<int>(
          data: index,
          feedback: SizedBox(width: t.thumbnailSize * 2, height: t.thumbnailSize * 2.8, child: _card(t, highlighted: true)),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: hovering.isNotEmpty ? _card(t, highlighted: true) : card,
        ),
      ),
    );
  }

  Widget _card(DocScanTheme t, {required bool highlighted}) => Builder(
    builder: (BuildContext context) => Material(
      color: t.surfaceSecondary,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusMd),
          border: Border.all(color: highlighted ? t.primary : t.border, width: highlighted ? t.frameStrokeWidth : 1),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(t.spaceXs),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  child: Image.file(page.preparedFile, fit: BoxFit.cover, width: double.infinity, cacheWidth: 360),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                SizedBox(width: t.spaceSm),
                Expanded(
                  child: Text('${index + 1}', style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
                ),
                ScanIconButton(
                  icon: t.icons.edit,
                  label: strings.pageLabel(index + 1),
                  color: t.onSurfaceMuted,
                  size: t.iconSize * 0.8,
                  onPressed: () => _menu(context),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _menu(BuildContext context) async {
    final DocScanTheme t = DocScanTheme.of(context);
    final ReviewCubit cubit = context.read<ReviewCubit>();
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet))),
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScanSheetHandle(color: t.border),
            for (final (String id, String label, String icon) in <(String, String, String)>[
              ('corners', strings.cornersTitle, t.icons.crop),
              ('filters', strings.filtersTitle, t.icons.filters),
              if (index > 0) ('earlier', strings.moveEarlier, t.icons.back),
              if (index < count - 1) ('later', strings.moveLater, t.icons.back),
              ('delete', strings.deletePage, t.icons.delete),
            ])
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
                  child: ScanQuietButton(
                    label: label,
                    icon: icon,
                    color: id == 'delete' ? t.danger : t.onSurface,
                    onPressed: () => Navigator.of(sheet).pop(id),
                  ),
                ),
              ),
            SizedBox(height: t.spaceMd),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'corners':
        final Quad? q = await Navigator.of(context).push<Quad>(
          MaterialPageRoute<Quad>(
            builder: (_) => Theme(
              data: Theme.of(context),
              child: CornerAdjustScreen(page: page, strings: strings),
            ),
          ),
        );
        if (q != null) unawaited(cubit.adjustCorners(page.id, q));
      case 'filters':
        onOpenFilters(index);
      case 'earlier':
        cubit.move(index, index - 1, via: MoveVia.action);
      case 'later':
        cubit.move(index, index + 1, via: MoveVia.action);
      case 'delete':
        final bool ok = await showDeletePageDialog(context, strings: strings, pageNumber: index + 1);
        if (ok && await cubit.deletePage(page.id)) onEmpty();
    }
  }
}

class _UndoBar extends StatelessWidget {
  const _UndoBar({required this.label, required this.onUndo});

  final String label;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: t.spaceLg),
      padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
      decoration: BoxDecoration(color: t.surfaceSecondary, borderRadius: BorderRadius.circular(t.radiusMd)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(child: ScanQuietButton(label: label, icon: t.icons.back, onPressed: onUndo)),
        ],
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
          painter: _DashedBorder(color: t.border, radius: t.radiusMd, width: t.frameStrokeWidth / 2),
          child: Container(
            decoration: BoxDecoration(color: t.surfaceSecondary, borderRadius: BorderRadius.circular(t.radiusMd)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DocScanIcon(t.icons.addPage, size: t.iconSize, color: t.onSurfaceMuted),
                SizedBox(height: t.spaceXs),
                Text(label, style: t.captionStyle.copyWith(color: t.onSurfaceMuted), textAlign: TextAlign.center),
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
    final Path path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final double dash = width * 6;
    for (final PathMetric m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += dash * 2) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius || old.width != width;
}
