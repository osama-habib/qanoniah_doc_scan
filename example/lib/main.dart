import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'fake_composer.dart';
import 'fallback_theme.dart';

void main() {
  runApp(const DocScanExampleApp());
}

/// Example host for qanoniah_doc_scan: RTL, Arabic, the fallback theme, and a fake
/// composer (T031).
class DocScanExampleApp extends StatelessWidget {
  const DocScanExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        fontFamily: 'NotoSansArabic',
        extensions: <ThemeExtension<dynamic>>[fallbackTheme],
      ),
      home: const FakeComposer(),
    );
  }
}
