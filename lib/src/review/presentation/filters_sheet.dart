import 'package:flutter/material.dart';

import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/presentation/scan_widgets.dart';
import '../../core/session/scan_session.dart';
import '../manager/review_cubit.dart';

/// «توضيح الصفحات»: combinable filters for one page or all pages (story 13).
Future<void> showFiltersSheet(
  BuildContext context, {
  required ReviewCubit cubit,
  required DocScanStrings strings,
  required String? pageId,
}) {
  final DocScanTheme t = DocScanTheme.of(context);
  final List<CapturedPage> pages = cubit.state.pages;
  final Set<PageFilter> initial = pageId == null
      ? (pages.isEmpty ? const <PageFilter>{PageFilter.original} : pages.first.filters)
      : pages.firstWhere((CapturedPage p) => p.id == pageId).filters;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet))),
    builder: (BuildContext sheet) => _FiltersBody(
      strings: strings,
      initial: initial,
      allPagesInitially: pageId == null,
      onApply: (Set<PageFilter> f, bool all) {
        Navigator.of(sheet).pop();
        cubit.setFilters(f, pageId: all ? null : pageId);
      },
    ),
  );
}

class _FiltersBody extends StatefulWidget {
  const _FiltersBody({
    required this.strings,
    required this.initial,
    required this.allPagesInitially,
    required this.onApply,
  });

  final DocScanStrings strings;
  final Set<PageFilter> initial;
  final bool allPagesInitially;
  final void Function(Set<PageFilter>, bool allPages) onApply;

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  late Set<PageFilter> _filters = Set<PageFilter>.of(widget.initial);
  late bool _all = widget.allPagesInitially;

  String _label(PageFilter f) => switch (f) {
    PageFilter.original => widget.strings.filterOriginal,
    PageFilter.autoEnhance => widget.strings.filterAuto,
    PageFilter.sharpenText => widget.strings.filterText,
    PageFilter.removeShadows => widget.strings.filterShadow,
    PageFilter.highContrast => widget.strings.filterContrast,
    PageFilter.grayscale => widget.strings.filterGray,
    PageFilter.blackWhite => widget.strings.filterBw,
  };

  void _toggle(PageFilter f) {
    setState(() {
      if (f == PageFilter.original) {
        _filters = <PageFilter>{PageFilter.original};
        return;
      }
      _filters.remove(PageFilter.original);
      if (!_filters.remove(f)) _filters.add(f);
      if (_filters.isEmpty) _filters = <PageFilter>{PageFilter.original};
    });
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = widget.strings;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.spaceLg, 0, t.spaceLg, t.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: ScanSheetHandle(color: t.border)),
            ScanHeader(
              title: s.filtersTitle,
              trailing: ScanQuietButton(
                label: s.resetFilters,
                onPressed: () => setState(() => _filters = <PageFilter>{PageFilter.original}),
              ),
            ),
            Text(s.filtersHint, style: t.captionStyle.copyWith(color: t.onSurfaceMuted)),
            SizedBox(height: t.spaceMd),
            Wrap(
              spacing: t.spaceSm,
              runSpacing: t.spaceSm,
              children: <Widget>[
                for (final PageFilter f in PageFilter.values)
                  Semantics(
                    selected: _filters.contains(f),
                    button: true,
                    label: _label(f),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _toggle(f),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
                        decoration: BoxDecoration(
                          color: _filters.contains(f) ? t.primary : t.surfaceSecondary,
                          borderRadius: BorderRadius.circular(t.radiusLg),
                          border: Border.all(color: _filters.contains(f) ? t.primary : t.border),
                        ),
                        child: Text(
                          _label(f),
                          style: t.captionStyle.copyWith(color: _filters.contains(f) ? t.onPrimary : t.onSurface),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: t.spaceMd),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _all,
                  activeColor: t.primary,
                  onChanged: (bool? v) => setState(() => _all = v ?? false),
                ),
                Expanded(child: Text(s.applyToAllPages, style: t.bodyStyle.copyWith(color: t.onSurface))),
              ],
            ),
            SizedBox(height: t.spaceSm),
            ScanPrimaryButton(label: s.done, onPressed: () => widget.onApply(_filters, _all)),
          ],
        ),
      ),
    );
  }
}
