import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/scan_metrics.dart';
import '../../core/doc_scan_icons.dart';
import '../../core/doc_scan_strings.dart';
import '../../core/doc_scan_theme.dart';
import '../../core/failures.dart';
import '../../core/presentation/scan_widgets.dart';
import '../manager/build_cubit.dart';

/// Progress screen (story 4, FR-012, design `scanBuilding`): a page sketch with a
/// moving scan line over three steps that complete in order. Back cancels; a
/// failure adds «إعادة المحاولة» and «إلغاء».
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _PageSketch(running: f == null && st.step != BuildStep.done),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(
                      children: <Widget>[
                        for (final (BuildStep step, String label) in <(BuildStep, String)>[
                          (BuildStep.analyze, s.stepAnalyze),
                          (BuildStep.extract, s.stepExtract),
                          (BuildStep.pdf, s.stepPdf),
                        ])
                          Padding(
                            padding: EdgeInsets.only(top: step == BuildStep.analyze ? 0 : 12),
                            child: _StepRow(label: label, step: step, current: st),
                          ),
                      ],
                    ),
                  ),
                  if (f != null) ...<Widget>[
                    const SizedBox(height: 28),
                    Text(
                      switch (f) {
                        BuildTooLarge(:final int sizeBytes, :final int limitBytes) => s.sizeLimit(
                          sizeBytes / (1024 * 1024),
                          limitBytes / (1024 * 1024),
                        ),
                        BuildStorageFull() => s.storageFull,
                        BuildUnknown() => s.buildFailed,
                      },
                      style: t.bodyStyle.sized(14, 20).copyWith(color: t.danger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (f is! BuildTooLarge) ...<Widget>[
                      ScanPrimaryButton(label: s.retry, onPressed: context.read<BuildCubit>().retry),
                      const SizedBox(height: 10),
                    ],
                    ScanSecondaryButton(label: s.cancel, onPressed: onCancel),
                  ],
                ],
              ),
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
      child: Row(
        children: <Widget>[
          // Design dots: filled navy with a check when done, a navy ring when
          // current, a light ring when waiting.
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? t.primary : t.surface,
              border: done ? null : Border.all(color: active ? t.primary : t.border, width: active ? 2 : 1.5),
            ),
            child: done ? DocScanIcon(t.icons.done, size: 11, color: t.onPrimary) : null,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: t.bodyStyle.sized(14, 20).copyWith(color: done || active ? t.onSurface : t.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 96 by 124 page with five text lines and a scan line moving up and down.
class _PageSketch extends StatefulWidget {
  const _PageSketch({required this.running});

  final bool running;

  @override
  State<_PageSketch> createState() => _PageSketchState();
}

class _PageSketchState extends State<_PageSketch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PageSketch old) {
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
    Widget line(double widthFactor, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: widthFactor,
        child: Container(
          height: 5,
          decoration: BoxDecoration(color: color, borderRadius: ScanMetrics.radius(2)),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 96,
        height: 124,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: ScanMetrics.radius(8),
          border: Border.all(color: t.border),
          boxShadow: <BoxShadow>[
            BoxShadow(color: t.primary.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                children: <Widget>[
                  line(0.6, t.border),
                  line(1, t.surfaceTertiary),
                  line(0.85, t.surfaceTertiary),
                  line(1, t.surfaceTertiary),
                  line(0.7, t.surfaceTertiary),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (BuildContext context, Widget? _) => Align(
                alignment: Alignment(0, Curves.easeInOut.transform(_c.value) * 2 - 1),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        t.frameDetected.withValues(alpha: 0),
                        t.frameDetected,
                        t.frameDetected.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
