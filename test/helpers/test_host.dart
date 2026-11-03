import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/src/capture/data/permission_repo.dart';
import 'package:qanoniah_doc_scan/src/core/failures.dart';
import 'package:qanoniah_doc_scan/src/core/session/scan_session.dart';
import 'package:qanoniah_doc_scan/src/page_prep/data/page_preparer.dart';

/// Literal test values; tests are outside the P3 literal ban, which covers lib/.
const TextStyle _s = TextStyle(fontSize: 14);

const DocScanIcons testIcons = DocScanIcons(
  close: 'i.svg', capture: 'i.svg', autoMode: 'i.svg', manualMode: 'i.svg', addPage: 'i.svg',
  retake: 'i.svg', delete: 'i.svg', crop: 'i.svg', filters: 'i.svg', redact: 'i.svg',
  reveal: 'i.svg', edit: 'i.svg', document: 'i.svg', back: 'i.svg', done: 'i.svg', photoView: 'i.svg',
  undo: 'i.svg', dragHandle: 'i.svg', pages: 'i.svg', search: 'i.svg', chevronUp: 'i.svg', chevronDown: 'i.svg', pdf: 'i.svg',
);

const DocScanTheme testTheme = DocScanTheme(
  cameraSurface: Color(0xff111111), onCameraSurface: Color(0xffffffff), onCameraSurfaceMuted: Color(0xffcccccc),
  frameSearching: Color(0xffcccccc), frameDetected: Color(0xff3366ff), captureFlash: Color(0xffffffff),
  surface: Color(0xffffffff), surfaceSecondary: Color(0xfff5f5f5), onSurface: Color(0xff222222),
  onSurfaceMuted: Color(0xff777777), border: Color(0xffdddddd), primary: Color(0xff0a1c6d),
  onPrimary: Color(0xffffffff), redactionFill: Color(0xff222222), onRedactionFill: Color(0xffffffff),
  danger: Color(0xffdc2626), scrim: Color(0x99000000),
  canvas: Color(0xffe5e7eb), surfaceTertiary: Color(0xfff3f4f6), inverseSurface: Color(0xff111827),
  titleStyle: _s, bodyStyle: _s, bodyStrongStyle: _s, captionStyle: _s, buttonStyle: _s,
  spaceXs: 4, spaceSm: 8, spaceMd: 12, spaceLg: 16, spaceXl: 32,
  radiusSm: 12, radiusMd: 12, radiusLg: 20, radiusSheet: 20,
  iconSize: 24, thumbnailSize: 48, frameStrokeWidth: 2, icons: testIcons,
);

/// Serves a tiny SVG for any asset key, so icons render without bundled files.
class SvgStubBundle extends CachingAssetBundle {
  static const String _svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"></svg>';

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(_svg)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => _svg;
}

/// An RTL Arabic app with [testTheme], like a host.
Widget testApp(Widget home) => DefaultAssetBundle(
  bundle: SvgStubBundle(),
  child: MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const <Locale>[Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[testTheme]),
    builder: (BuildContext context, Widget? child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: home,
  ),
);

/// Permission scripted by the test.
class FakePermissionRepo implements PermissionRepo {
  FakePermissionRepo([this.result]);

  /// Null grants.
  CameraFailure? result;
  int opened = 0;

  Either<CameraFailure, Unit> get _r =>
      result == null ? const Right<CameraFailure, Unit>(unit) : Left<CameraFailure, Unit>(result!);

  @override
  Future<Either<CameraFailure, Unit>> ensureCamera() async => _r;

  @override
  Future<Either<CameraFailure, Unit>> check() async => _r;

  @override
  Future<void> openSettings() async => opened++;
}

/// Copies the raw file to both outputs instead of running OpenCV.
class FakePagePreparer implements PagePreparer {
  int calls = 0;
  final List<Set<PageFilter>> filters = <Set<PageFilter>>[];
  final List<Quad> corners = <Quad>[];

  @override
  int get maxLongEdge => 2200;

  @override
  int get jpegQuality => 90;

  @override
  Future<Either<StorageFailure, Unit>> prepare({
    required File raw,
    required Quad corners,
    required Set<PageFilter> filters,
    required File prepared,
    required File ocrInput,
  }) async {
    calls++;
    this.filters.add(filters);
    this.corners.add(corners);
    await raw.copy(prepared.path);
    await raw.copy(ocrInput.path);
    return const Right<StorageFailure, Unit>(unit);
  }
}
