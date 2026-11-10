import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/document/data/page_encoder.dart';
import 'package:qanoniah_doc_scan/src/document/data/pdf_builder.dart';

import '../helpers/pdf_fixtures.dart';

/// The image-form PDF without decoding and re-encoding every page (ClickUp
/// z8y71x6uvk).
void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('enc'));
  tearDown(() async => tmp.delete(recursive: true));

  File jpeg(String name, int w, int h, {int quality = 90}) {
    final img.Image im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(240, 238, 230));
    img.fillRect(im, x1: w ~/ 10, y1: h ~/ 10, x2: w ~/ 2, y2: h ~/ 5, color: img.ColorRgb8(30, 30, 30));
    return File('${tmp.path}/$name.jpg')..writeAsBytesSync(img.encodeJpg(im, quality: quality));
  }

  test('[UT] a JPEG\'s size is read from its header', () {
    expect(jpegSize(jpeg('a', 321, 654).readAsBytesSync()), (321, 654));
    expect(jpegSize(Uint8List.fromList(<int>[1, 2, 3, 4, 5])), isNull);
  });

  test('[UT] a prepared page that fits goes into the PDF as it is: no decoding, no re-encoding', () async {
    final File f = jpeg('p', 1500, 2100);
    final EncodedPage e = await const PageEncoder(
      native: false,
    ).encode(f.path, ImageEncoding.ladder.first, ScanColorMode.color);
    expect(e.bytes, f.readAsBytesSync(), reason: 'the very same bytes');
    expect((e.width, e.height), (1500, 2100));
  });

  test('[UT] a smaller rung shrinks and re-encodes the page (in Dart where native is missing)', () async {
    final File f = jpeg('p', 1500, 2100);
    final EncodedPage e = await const PageEncoder(
      native: false,
    ).encode(f.path, ImageEncoding.ladder.last, ScanColorMode.color);
    expect(e.height, ImageEncoding.ladder.last.longEdge);
    expect(e.bytes.length, lessThan(f.lengthSync()));
  });

  test('[UT] the PDF embeds the prepared JPEG unchanged, and reports each page as it goes', () async {
    final List<CapturedPage> pages = <CapturedPage>[
      pdfPage(tmp, 'a', <String>['أول'], w: 300, h: 400),
      pdfPage(tmp, 'b', <String>['ثاني'], w: 300, h: 400),
      pdfPage(tmp, 'c', <String>['ثالث'], w: 300, h: 400),
    ];
    final List<int> done = <int>[];
    final Either<BuildFailure, BuildOutput> r = await const PdfBuilder(encoder: PageEncoder(native: false)).buildImage(
      pages: pages,
      colorMode: ScanColorMode.color,
      encoding: ImageEncoding.ladder.first,
      look: testLook(),
      out: File('${tmp.path}/out.pdf'),
      onPage: (int d, int total) => done.add(d),
    );
    final Uint8List pdf = r.getOrElse(() => fail('build failed')).file.readAsBytesSync();
    expect(done, <int>[1, 2, 3], reason: 'one step per page');
    // The first page's JPEG, byte for byte, is inside the PDF.
    final Uint8List prepared = pages.first.preparedFile.readAsBytesSync();
    expect(_contains(pdf, prepared.sublist(0, 2048)), isTrue);
  });
}

bool _contains(Uint8List hay, Uint8List needle) {
  outer:
  for (int i = 0; i + needle.length <= hay.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
