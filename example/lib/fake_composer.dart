
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';

/// A stand-in for the host's chat composer: the attach menu with three equal cards,
/// the result chip, and a debug panel (T030, T065, T085).
class FakeComposer extends StatefulWidget {
  const FakeComposer({super.key});

  @override
  State<FakeComposer> createState() => _FakeComposerState();
}

class _FakeComposerState extends State<FakeComposer> {
  DocScanResult? _result;
  final List<String> _events = <String>[];
  int _fileNumber = 1;

  Future<void> _scan() async {
    final ByteData font = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final ByteData latin = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    if (!mounted) return;
    final DocScanResult? r = await DocScan.start(
      context,
      DocScanConfig(
        pdfFont: font.buffer.asUint8List(),
        pdfFontFallback: latin.buffer.asUint8List(),
        fileNumber: _fileNumber,
        onEvent: (DocScanEvent e) => setState(() => _events.insert(0, '${e.name} ${e.params}')),
      ),
    );
    if (!mounted || r == null) return;
    setState(() {
      _result = r;
      _fileNumber++;
    });
  }

  void _open(DocScanResult r) {
    setState(() => _events.insert(0, DocScanEvent.viewerOpened().name));
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocScanViewer(pdf: r.pdf, fileName: r.fileName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    final DocScanResult? r = _result;
    return Scaffold(
      backgroundColor: t.surfaceSecondary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('qanoniah_doc_scan', style: t.titleStyle, textAlign: TextAlign.center),
              SizedBox(height: t.spaceLg),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (r != null) ...<Widget>[
                      _Chip(name: r.fileName, onTap: () => _open(r)),
                      SizedBox(height: t.spaceSm),
                      Text(
                        'form: ${r.form.name} · pages: ${r.pageCount} · '
                        '${(r.sizeBytes / 1024).toStringAsFixed(0)} KB',
                        style: t.captionStyle,
                      ),
                      for (int i = 0; i < r.pageTexts.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: t.spaceSm),
                          child: Text('${i + 1}: ${r.pageTexts[i]}', style: t.captionStyle, maxLines: 4, overflow: TextOverflow.ellipsis),
                        ),
                      SizedBox(height: t.spaceLg),
                    ],
                    Text('events', style: t.bodyStrongStyle),
                    for (final String e in _events) Text(e, style: t.captionStyle, textDirection: TextDirection.ltr),
                  ],
                ),
              ),
              // The attach menu: three equal cards, 76 px tall (design).
              Row(
                children: <Widget>[
                  for (final (String label, String icon, VoidCallback? onTap) in <(String, String, VoidCallback?)>[
                    ('الصور', t.icons.photoView, null),
                    ('الملفات', t.icons.document, null),
                    ('مسح مستند', t.icons.capture, _scan),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.spaceXs),
                        child: Material(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(t.radiusMd),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(t.radiusMd),
                            onTap: onTap,
                            child: SizedBox(
                              height: 76,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SvgPicture.asset(icon, width: t.iconSize, height: t.iconSize),
                                  SizedBox(height: t.spaceXs),
                                  Text(label, style: t.captionStyle.copyWith(color: t.onSurface)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DocScanTheme t = DocScanTheme.of(context);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: Padding(
          padding: EdgeInsets.all(t.spaceMd),
          child: Row(
            children: <Widget>[
              SvgPicture.asset(t.icons.document, width: t.iconSize, height: t.iconSize),
              SizedBox(width: t.spaceSm),
              Expanded(child: Text(name, style: t.bodyStrongStyle)),
            ],
          ),
        ),
      ),
    );
  }
}
