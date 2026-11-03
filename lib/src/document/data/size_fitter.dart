import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/failures.dart';
import '../../core/session/scan_session.dart';
import 'pdf_builder.dart';

/// Builds the image-form PDF at the best encoding that fits the host's limit
/// (FR-061, research R7). Text form is built once and never re-encoded.
class SizeFitter {
  const SizeFitter({PdfBuilder builder = const PdfBuilder()}) : _builder = builder;

  final PdfBuilder _builder;

  Future<Either<BuildFailure, BuildOutput>> fitImage({
    required List<CapturedPage> pages,
    required ScanColorMode colorMode,
    required PdfLook look,
    required int maxBytes,
    required File Function() newFile,
  }) async {
    BuildOutput? last;
    for (final ImageEncoding enc in ImageEncoding.ladder) {
      final File out = newFile();
      final Either<BuildFailure, BuildOutput> r =
          await _builder.buildImage(pages: pages, colorMode: colorMode, encoding: enc, look: look, out: out);
      if (r.isLeft()) return r;
      final BuildOutput o = r.getOrElse(() => throw StateError('unreachable'));
      if (o.sizeBytes <= maxBytes) {
        if (last != null) await _delete(last.file);
        return Right<BuildFailure, BuildOutput>(o);
      }
      if (last != null) await _delete(last.file);
      last = o;
    }
    final BuildOutput over = last!;
    await _delete(over.file);
    return Left<BuildFailure, BuildOutput>(BuildFailure.tooLarge(sizeBytes: over.sizeBytes, limitBytes: maxBytes));
  }

  static Future<void> _delete(File f) async {
    if (await f.exists()) await f.delete();
  }
}
