// The pipeline check reaches into the package's own dependencies.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qanoniah_doc_scan/src/capture/data/edge_detector.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart' show DocScanPdfForm, DocScanStrings;
import 'package:qanoniah_doc_scan/src/core/session/scan_session_repo.dart';
import 'package:qanoniah_doc_scan/src/document/data/size_fitter.dart';
import 'package:qanoniah_doc_scan/src/document/manager/preview_cubit.dart';
import 'package:qanoniah_doc_scan/src/document/presentation/text_page_view.dart';
import 'package:qanoniah_doc_scan_example/fallback_theme.dart';
import 'package:qanoniah_doc_scan/src/core/session/document_edits.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';
import 'package:qanoniah_doc_scan/src/document/data/text_pdf_renderer.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/platform_text_recognizer.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/post_processor.dart';
import 'package:qanoniah_doc_scan/src/recognition/data/text_recognizer.dart';

/// On-device check of the capture pipeline on a known page: a synthetic A4 sheet
/// with a centered heading, a justified paragraph, a 3-column table and a left
/// English line, photographed at an angle on a dark desk.
///
/// Prints timings, the found corners against the true ones, and the recovered
/// layout. Run: flutter test integration_test/pipeline_test.dart -d DEVICE.
(ScanSessionRepo, BuildOutput)? previewHarness;
Directory? outDir;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture pipeline on a photographed page', (WidgetTester t) async {
    await t.runAsync(() async {
      await _loadFonts();
      const String out = String.fromEnvironment('OUT');
      final Directory dir = out.isEmpty ? await Directory.systemTemp.createTemp('pipe') : await Directory(out).create(recursive: true);
      _logFile = File('${dir.path}/pipe.log')..writeAsStringSync('');
      final (File photo, List<Offset> truth) = await _photo(dir);
      _log('photo ${photo.lengthSync() ~/ 1024} KB, true corners ${_fmt(truth)}');

      final VisionEdgeDetector edges = VisionEdgeDetector();
      final Stopwatch sw = Stopwatch()..start();
      final Quad? found = await edges.detectInPhoto(photo);
      _log('detectInPhoto ${sw.elapsedMilliseconds} ms -> ${found == null ? 'none' : _fmt(_corners(found))}');
      if (found != null) _log('corner error ${(_err(_corners(found), truth) * 100).toStringAsFixed(2)}% of width');

      final Quad q = found ?? Quad.fullFrame;
      for (final bool native in <bool>[false, true]) {
        for (final (String name, Set<PageFilter> f) in <(String, Set<PageFilter>)>[
          ('original', <PageFilter>{PageFilter.original}),
          ('shadows+auto', <PageFilter>{PageFilter.removeShadows, PageFilter.autoEnhance}),
          ('bw', <PageFilter>{PageFilter.blackWhite}),
        ]) {
          final String tag = '${native ? 'native' : 'dart'}_$name';
          sw
            ..reset()
            ..start();
          final Either<StorageFailure, Unit> r = await PagePreparer(native: native).prepare(
            raw: photo,
            corners: q,
            filters: f,
            prepared: File('${dir.path}/prep_$tag.jpg'),
            ocrInput: File('${dir.path}/ocr_$tag.png'),
          );
          final int ms = sw.elapsedMilliseconds;
          _log('prepare[$tag] $ms ms ok=${r.isRight()} aspect(A4 0.707) ${await _stats(File('${dir.path}/prep_$tag.jpg'))} ocr ${await _stats(File('${dir.path}/ocr_$tag.png'))}');
        }
      }

      final File ocr = File('${dir.path}/ocr_native_original.png');
      final PlatformTextRecognizer rec = PlatformTextRecognizer();
      sw
        ..reset()
        ..start();
      final Either<RecognitionFailure, RawRecognition> raw = await rec.recognize(ocr, RecognitionLanguage.ar);
      _log('recognize ${sw.elapsedMilliseconds} ms');
      raw.fold((RecognitionFailure f) => _log('recognize failed $f'), (RawRecognition r) {
        _log('raw lines ${r.blocks.length}');
        for (final List<Word> l in r.blocks) {
          final Rect b = l.map((Word w) => w.box).reduce((Rect a, Rect c) => a.expandToInclude(c));
          _log('  line [${b.left.round()},${b.top.round()} ${b.width.round()}x${b.height.round()}] ${l.map((Word w) => w.text).join(' ')}');
        }
        final PageText text = const PostProcessor().process(r, RecognitionLanguage.ar);
        _log('paragraphs ${text.paragraphs.length}');
        for (final Paragraph p in text.paragraphs) {
          final String where = p.table == null ? '' : ' table${p.table} r${p.row} c${p.col}';
          _log('  ¶ [${p.align.name}${p.heading ? ' H' : ''} size ${p.size.toStringAsFixed(2)} gap ${p.spaceBefore.toStringAsFixed(1)} indent ${p.indent.toStringAsFixed(2)} lines ${p.lines.length}$where] ${p.text}');
        }
      });
      // The text-form PDF from that layout, rasterized for a look.
      final RawRecognition? rr = raw.fold((RecognitionFailure _) => null, (RawRecognition r) => r);
      if (rr != null) {
        final PageText text = const PostProcessor().process(rr, RecognitionLanguage.ar);
        final ByteData arFont = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        final ByteData boldFont = await rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf');
        final ByteData latin = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
        sw
          ..reset()
          ..start();
        final Uint8List pdf = await PlatformTextPdfRenderer(fallback: const PdfPackageTextRenderer()).render(
          <List<PdfTextBlock>>[
            <PdfTextBlock>[
              for (final Paragraph p in text.paragraphs)
                PdfTextBlock.of(p, <FinalSegment>[FinalText(p.text)], rtl: true),
            ],
          ],
          PdfLook(
            font: arFont.buffer.asUint8List(),
            fontFallback: latin.buffer.asUint8List(),
            fontBold: boldFont.buffer.asUint8List(),
            text: 0xff222222,
            redactionFill: 0xff222222,
            onRedactionFill: 0xffffffff,
            redactedLabel: 'نص محجوب',
          ),
        );
        File('${dir.path}/text.pdf').writeAsBytesSync(pdf);
        await for (final PdfRaster r in Printing.raster(pdf, dpi: 110)) {
          File('${dir.path}/text_pdf.png').writeAsBytesSync(await r.toPng());
          break;
        }
        _log('text pdf ${sw.elapsedMilliseconds} ms, ${pdf.length ~/ 1024} KB');

        // The preview's page view, rendered to an image.
        final ScanSessionRepo sessions = ScanSessionRepo(tempRoot: () async => dir);
        await sessions.start();
        final File f = File('${dir.path}/prep_native_original.jpg');
        sessions.addPage(CapturedPage(
          id: 'pg',
          rawFile: photo,
          corners: q,
          filters: const <PageFilter>{PageFilter.original},
          preparedFile: f,
          ocrInputFile: ocr,
          recognition: RecognitionState.done(text),
        ));
        previewHarness = (sessions, BuildOutput(file: f, form: DocScanPdfForm.image, sizeBytes: 1, compressed: false));
      }
      outDir = dir;
    });
    final (ScanSessionRepo, BuildOutput)? h = previewHarness;
    if (h != null) {
      final GlobalKey key = GlobalKey();
      final PreviewCubit cubit = PreviewCubit(
        sessions: h.$1,
        built: h.$2,
        fitter: const SizeFitter(),
        builder: const PdfBuilder(),
        look: PdfLook(font: Uint8List(0), fontFallback: Uint8List(0), text: 0, redactionFill: 0, onRedactionFill: 0, redactedLabel: ''),
        maxFileBytes: 1 << 30,
        defaultStem: 'scan',
        onEvent: (_) {},
      );
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansArabic', extensions: <ThemeExtension<dynamic>>[fallbackTheme]),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xffe5e7eb),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                key: key,
                child: BlocProvider<PreviewCubit>.value(
                  value: cubit,
                  child: TextPageView(page: h.$1.session.pages.single, strings: DocScanStrings.ar()),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      final RenderRepaintBoundary b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image im = await b.toImage(pixelRatio: 2);
      final ByteData? png = await t.runAsync<ByteData?>(() => im.toByteData(format: ui.ImageByteFormat.png));
      File('${outDir!.path}/preview.png').writeAsBytesSync(png!.buffer.asUint8List());
      _log('preview rendered');
    }
    _log('artifacts in ${outDir?.path}');
  });
}

/// Size, and the paper's brightness and spread in a blank strip near the bottom.
Future<String> _stats(File f) async {
  if (!f.existsSync()) return 'missing';
  final ui.Codec codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  final ui.Image im = (await codec.getNextFrame()).image;
  final ByteData? px = await im.toByteData();
  final int w = im.width;
  final int h = im.height;
  double sum = 0;
  double sq = 0;
  int n = 0;
  for (int y = (h * 0.75).round(); y < (h * 0.82).round(); y += 3) {
    for (int x = (w * 0.1).round(); x < (w * 0.9).round(); x += 3) {
      final int i = (y * w + x) * 4;
      final double l = 0.2126 * px!.getUint8(i) + 0.7152 * px.getUint8(i + 1) + 0.0722 * px.getUint8(i + 2);
      sum += l;
      sq += l * l;
      n++;
    }
  }
  final double mean = sum / n;
  return '${w}x$h paper=${mean.toStringAsFixed(0)}±${math.sqrt(math.max(0, sq / n - mean * mean)).toStringAsFixed(1)}';
}

/// A copy of the log next to the artifacts: a profile build on a phone does not send
/// `print` to the launch console, so the run is read back from the app container.
File? _logFile;

void _log(String s) {
  // ignore: avoid_print
  print('[PIPE] $s');
  _logFile?.writeAsStringSync('[PIPE] $s\n', mode: FileMode.append, flush: true);
}

String _fmt(List<Offset> c) => c.map((Offset o) => '(${o.dx.toStringAsFixed(3)},${o.dy.toStringAsFixed(3)})').join(' ');

List<Offset> _corners(Quad q) => <Offset>[q.topLeft, q.topRight, q.bottomRight, q.bottomLeft];

double _err(List<Offset> a, List<Offset> b) {
  double m = 0;
  for (int i = 0; i < 4; i++) {
    m = math.max(m, (a[i] - b[i]).distance);
  }
  return m;
}

Future<void> _loadFonts() async {
  final FontLoader ar = FontLoader('NotoSansArabic')
    ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf'));
  await ar.load();
}

/// The page as a picture, A4 at 1240 x 1754.
ui.Picture _page() {
  const double w = 1240;
  const double h = 1754;
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xfffbfaf6));
  void text(String s, double top, {double size = 30, FontWeight weight = FontWeight.w400, TextAlign align = TextAlign.right, TextDirection dir = TextDirection.rtl, double left = 110, double width = w - 220}) {
    final TextPainter p = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'NotoSansArabic', fontSize: size, fontWeight: weight, color: const Color(0xff1a1a1a), height: 1.6)),
      textDirection: dir,
      textAlign: align,
    )..layout(minWidth: width, maxWidth: width);
    p.paint(c, Offset(left, top));
  }

  text('عقد إيجار تجاري', 120, size: 52, weight: FontWeight.w600, align: TextAlign.center);
  text(
    'إنه في يوم الأحد الموافق 12 من شهر مايو لعام 2024 تم الاتفاق بين كل من الطرف الأول المؤجر والطرف الثاني المستأجر على تأجير المحل التجاري الكائن في مدينة الرياض وفق الشروط والأحكام الواردة في هذا العقد، ويقر الطرفان بأهليتهما للتعاقد.',
    260,
    align: TextAlign.justify,
  );
  // A 3-column table: البند | المبلغ | المدة
  const double tTop = 620;
  const double row = 76;
  const List<List<String>> cells = <List<String>>[
    <String>['البند', 'المبلغ', 'المدة'],
    <String>['الإيجار السنوي', '120000 ريال', '12 شهرا'],
    <String>['التأمين', '10000 ريال', 'مرة واحدة'],
    <String>['الصيانة', '5000 ريال', 'سنويا'],
  ];
  const List<double> colX = <double>[1130, 760, 420, 110]; // right edges, then left
  final Paint line = Paint()
    ..color = const Color(0xff333333)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  for (int r = 0; r <= cells.length; r++) {
    c.drawLine(Offset(colX.last, tTop + r * row), Offset(colX.first, tTop + r * row), line);
  }
  for (final double x in colX) {
    c.drawLine(Offset(x, tTop), Offset(x, tTop + cells.length * row), line);
  }
  for (int r = 0; r < cells.length; r++) {
    for (int k = 0; k < 3; k++) {
      final double right = colX[k];
      final double left = colX[k + 1];
      text(cells[r][k], tTop + r * row + 14, size: 28, weight: r == 0 ? FontWeight.w600 : FontWeight.w400, align: TextAlign.center, left: left + 10, width: right - left - 20);
    }
  }
  text('Signed in Riyadh, clause 7 applies.', 1020, align: TextAlign.left, dir: TextDirection.ltr);
  text('توقيع الطرف الأول', 1500, size: 30, align: TextAlign.right);
  text('توقيع الطرف الثاني', 1500, size: 30, align: TextAlign.left);
  return rec.endRecording();
}

/// The page on a dark desk at an angle, 1080 x 1920, and its true normalized corners.
Future<(File, List<Offset>)> _photo(Directory dir) async {
  const double pw = 1240;
  const double ph = 1754;
  const double w = 1080;
  const double h = 1920;
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xff3a2f28));
  // Uneven light, like a lamp from the top left.
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.radial(const Offset(200, 200), 1600, <Color>[const Color(0x22ffffff), const Color(0x55000000)]),
  );
  // A pinhole camera (focal 0.75 of the long side, principal point at the center)
  // looking at the sheet tilted 0.45 rad forward and 0.2 rad sideways.
  final List<Offset> dst = _pinhole(pw, ph, w, h, pitch: 0.45, yaw: 0.2, roll: -0.05);
  final Matrix4 m = _homography(<Offset>[const Offset(0, 0), const Offset(pw, 0), const Offset(pw, ph), const Offset(0, ph)], dst);
  c.save();
  c.transform(m.storage);
  c.drawPicture(_page());
  // A soft shadow band across the page.
  c.drawRect(
    const Rect.fromLTWH(0, 900, pw, 500),
    Paint()..shader = ui.Gradient.linear(const Offset(0, 900), const Offset(0, 1400), <Color>[const Color(0x00000000), const Color(0x33000000), const Color(0x00000000)], <double>[0, 0.5, 1]),
  );
  c.restore();
  final ui.Image image = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  final File f = File('${dir.path}/photo.png')..writeAsBytesSync(png!.buffer.asUint8List());
  Offset tr(double x, double y) {
    final Float64List s = m.storage;
    final double d = s[3] * x + s[7] * y + s[15];
    return Offset((s[0] * x + s[4] * y + s[12]) / d / w, (s[1] * x + s[5] * y + s[13]) / d / h);
  }

  return (f, <Offset>[tr(0, 0), tr(pw, 0), tr(pw, ph), tr(0, ph)]);
}

List<Offset> _pinhole(double pw, double ph, double w, double h, {required double pitch, required double yaw, required double roll}) {
  final double f = 0.75 * math.max(w, h);
  final List<Offset> out = <Offset>[];
  for (final Offset c in <Offset>[Offset(-pw / 2, -ph / 2), Offset(pw / 2, -ph / 2), Offset(pw / 2, ph / 2), Offset(-pw / 2, ph / 2)]) {
    final double x0 = c.dx * math.cos(roll) - c.dy * math.sin(roll);
    final double y0 = c.dx * math.sin(roll) + c.dy * math.cos(roll);
    final double y1 = y0 * math.cos(pitch);
    final double z1 = y0 * math.sin(pitch);
    final double x2 = x0 * math.cos(yaw) + z1 * math.sin(yaw);
    final double z2 = -x0 * math.sin(yaw) + z1 * math.cos(yaw) + 2300;
    out.add(Offset(f * x2 / z2 + w / 2, f * y1 / z2 + h / 2 + 60));
  }
  return out;
}

/// The 4x4 canvas transform of the homography taking [src] to [dst].
Matrix4 _homography(List<Offset> src, List<Offset> dst) {
  final List<List<double>> a = <List<double>>[];
  final List<double> b = <double>[];
  for (int i = 0; i < 4; i++) {
    final double x = src[i].dx, y = src[i].dy, u = dst[i].dx, v = dst[i].dy;
    a.add(<double>[x, y, 1, 0, 0, 0, -u * x, -u * y]);
    b.add(u);
    a.add(<double>[0, 0, 0, x, y, 1, -v * x, -v * y]);
    b.add(v);
  }
  // Gaussian elimination.
  for (int c = 0; c < 8; c++) {
    int p = c;
    for (int r = c + 1; r < 8; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    final List<double> t = a[c];
    a[c] = a[p];
    a[p] = t;
    final double tb = b[c];
    b[c] = b[p];
    b[p] = tb;
    for (int r = 0; r < 8; r++) {
      if (r == c) continue;
      final double k = a[r][c] / a[c][c];
      for (int k2 = c; k2 < 8; k2++) {
        a[r][k2] -= k * a[c][k2];
      }
      b[r] -= k * b[c];
    }
  }
  final List<double> hm = <double>[for (int i = 0; i < 8; i++) b[i] / a[i][i]];
  // Column-major: x' = h0 x + h1 y + h2, y' = h3 x + h4 y + h5, w' = h6 x + h7 y + 1.
  return Matrix4(
    hm[0], hm[3], 0, hm[6], //
    hm[1], hm[4], 0, hm[7],
    0, 0, 1, 0,
    hm[2], hm[5], 0, 1,
  );
}
