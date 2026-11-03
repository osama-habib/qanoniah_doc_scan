import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/failures.dart';
import '../../core/presentation/scan_widgets.dart';
import '../manager/build_cubit.dart';

/// Progress screen: an animated scan line and three steps completing in order
/// (story 4, FR-012).
class BuildScreen extends StatelessWidget {
  const BuildScreen({super.key, required this.strings, required this.onCancel});

  final DocScanStrings strings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanStrings s = strings;
    return ColoredBox(
      color: t.surface,
      child: SafeArea(
        child: BlocBuilder<BuildCubit, BuildState>(
          builder: (BuildContext context, BuildState st) {
            final BuildFailure? f = st.failure;
            return Column(
              children: <Widget>[
                ScanHeader(title: s.scanTitle, leading: ScanQuietButton(label: s.cancel, onPressed: onCancel)),
                const Spacer(),
                SizedBox(
                  width: t.thumbnailSize * 3,
                  height: t.thumbnailSize * 4,
                  child: _ScanLine(running: f == null && st.step != BuildStep.done),
                ),
                SizedBox(height: t.spaceXl),
                for (final (BuildStep step, String label) in <(BuildStep, String)>[
                  (BuildStep.analyze, s.stepAnalyze),
                  (BuildStep.extract, s.stepExtract),
                  (BuildStep.pdf, s.stepPdf),
                ])
                  _StepRow(label: label, step: step, current: st),
                const Spacer(),
                if (f != null)
                  Padding(
                    padding: EdgeInsets.all(t.spaceLg),
                    child: Column(
                      children: <Widget>[
                        Text(
                          switch (f) {
                            BuildTooLarge(:final int sizeBytes, :final int limitBytes) =>
                              s.sizeLimit(sizeBytes / (1024 * 1024), limitBytes / (1024 * 1024)),
                            BuildStorageFull() => s.storageFull,
                            BuildUnknown() => s.buildFailed,
                          },
                          style: t.bodyStyle.copyWith(color: t.danger),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: t.spaceMd),
                        if (f is! BuildTooLarge)
                          ScanPrimaryButton(label: s.retry, onPressed: context.read<BuildCubit>().retry),
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

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.step, required this.current});

  final String label;
  final BuildStep step;
  final BuildState current;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final bool done = current.step.index > step.index;
    final bool active = current.step == step && current.failure == null;
    return Semantics(
      label: label,
      value: done ? '100%' : (active ? '${(current.progress * 100).round()}%' : '0%'),
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spaceXl, vertical: t.spaceSm),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: t.iconSize,
              child: done
                  ? DocScanIcon(t.icons.done, size: t.iconSize, color: t.primary)
                  : (active
                        ? CircularProgressIndicator(
                            strokeWidth: t.frameStrokeWidth,
                            color: t.primary,
                            value: current.progress > 0 && current.progress < 1 ? current.progress : null,
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.border)),
                          )),
            ),
            SizedBox(width: t.spaceMd),
            Text(
              label,
              style: (active ? t.bodyStrongStyle : t.bodyStyle).copyWith(color: done || active ? t.onSurface : t.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine({required this.running});

  final bool running;

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ScanLine old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceSecondary,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.border),
      ),
      child: Stack(
        children: <Widget>[
          Center(child: DocScanIcon(t.icons.document, size: t.thumbnailSize, color: t.onSurfaceMuted)),
          AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? _) => Align(
              alignment: Alignment(0, _c.value * 2 - 1),
              child: Container(height: t.frameStrokeWidth, color: t.primary),
            ),
          ),
        ],
      ),
    );
  }
}
