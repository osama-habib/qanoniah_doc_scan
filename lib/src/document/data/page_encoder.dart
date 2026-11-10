import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../core/session/scan_session.dart';

/// How a prepared page goes into the image-form PDF (research R7 size fitting).
@immutable
class ImageEncoding {
  const ImageEncoding({required this.quality, required this.longEdge, this.asPrepared = false});

  final int quality;
  final int longEdge;

  /// The prepared JPEG as it is, when it is no larger than [longEdge] and in
  /// color: no decoding, no re-encoding (ClickUp z8y71x6uvk).
  final bool asPrepared;

  /// Tried in order until the PDF fits; the last one is the legibility floor.
  static const List<ImageEncoding> ladder = <ImageEncoding>[
    ImageEncoding(quality: 90, longEdge: 2200, asPrepared: true),
    ImageEncoding(quality: 75, longEdge: 2200),
    ImageEncoding(quality: 65, longEdge: 1900),
    ImageEncoding(quality: 55, longEdge: 1600),
  ];
}

/// One page's JPEG for the PDF, with its size in pixels.
@immutable
class EncodedPage {
  const EncodedPage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Turns a prepared page into the JPEG the PDF embeds, the cheapest way that
/// meets an [ImageEncoding]: the file itself when it already does; else
/// re-encoded natively (`encodePage` on the `qanoniah_doc_scan/prep` channel:
/// Core Image on iOS, Bitmap on Android), in a fraction of the time the `image`
/// package takes and without heating the phone; else in Dart off the UI isolate.
class PageEncoder {
  const PageEncoder({this.native = true, MethodChannel channel = const MethodChannel('qanoniah_doc_scan/prep')})
    : _channel = channel;

  /// False forces the Dart path (tests, benchmarks).
  final bool native;
  final MethodChannel _channel;

  /// Set once the platform has no native encoder, so later pages skip the call.
  static bool _nativeMissing = false;

  Future<EncodedPage> encode(String path, ImageEncoding enc, ScanColorMode mode) async {
    final Uint8List file = await File(path).readAsBytes();
    if (enc.asPrepared && mode == ScanColorMode.color) {
      final (int, int)? size = jpegSize(file);
      if (size != null && math.max(size.$1, size.$2) <= enc.longEdge) return EncodedPage(file, size.$1, size.$2);
    }
    if (native && !_nativeMissing) {
      try {
        final Map<String, Object?>? out = await _channel
            .invokeMapMethod<String, Object?>('encodePage', <String, Object>{
              'path': path,
              'longEdge': enc.longEdge,
              'quality': enc.quality,
              'gray': mode != ScanColorMode.color,
              'bw': mode == ScanColorMode.bw,
            });
        final Object? bytes = out?['bytes'];
        final Object? w = out?['width'];
        final Object? h = out?['height'];
        if (bytes is Uint8List && w is int && h is int) return EncodedPage(bytes, w, h);
      } on MissingPluginException {
        _nativeMissing = true;
      } on PlatformException {
        // The Dart path below.
      } on FlutterError {
        // No platform binding (tests, a background isolate): Dart from now on.
        _nativeMissing = true;
      }
    }
    final int edge = enc.longEdge, quality = enc.quality;
    return Isolate.run(() => encodeInDart(file, edge, quality, mode));
  }
}

/// The Dart path: decode, shrink to [longEdge], gray or black and white, JPEG.
EncodedPage encodeInDart(Uint8List file, int longEdge, int quality, ScanColorMode mode) {
  final img.Image? decoded = img.decodeImage(file);
  if (decoded == null) throw const FileSystemException('decode');
  img.Image photo = decoded;
  final int long = math.max(photo.width, photo.height);
  if (long > longEdge) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: longEdge, interpolation: img.Interpolation.average)
        : img.copyResize(photo, height: longEdge, interpolation: img.Interpolation.average);
  }
  if (mode != ScanColorMode.color) photo = img.grayscale(photo);
  if (mode == ScanColorMode.bw) photo = img.luminanceThreshold(photo, threshold: 0.6);
  return EncodedPage(img.encodeJpg(photo, quality: quality), photo.width, photo.height);
}

/// Width and height from a JPEG's frame header, without decoding it; null for
/// anything else.
(int, int)? jpegSize(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  int i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) return null;
    final int marker = b[i + 1];
    // Fill bytes and markers without a length.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final int length = (b[i + 2] << 8) | b[i + 3];
    // Start of frame: baseline, extended, progressive, lossless (not DHT, JPG, DAC).
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
      final int h = (b[i + 5] << 8) | b[i + 6];
      final int w = (b[i + 7] << 8) | b[i + 8];
      return w > 0 && h > 0 ? (w, h) : null;
    }
    i += 2 + length;
  }
  return null;
}
