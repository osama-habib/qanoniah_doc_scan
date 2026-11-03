import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards for constitution P1 and P3 and FR-040, FR-043, FR-070, FR-072.
///
/// Generated files are skipped. Comments are stripped first, so documentation may
/// mention the banned names.
void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !f.path.endsWith('.freezed.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  String code(File f) => f
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');

  void expectNone(Iterable<File> files, Map<String, RegExp> banned) {
    final List<String> hits = <String>[];
    for (final File f in files) {
      final String c = code(f);
      banned.forEach((String label, RegExp re) {
        if (re.hasMatch(c)) hits.add('${f.path}: $label');
      });
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  }

  test('no network, host imports, or service locator under lib/ (P1, FR-040)', () {
    expectNone(sources, <String, RegExp>{
      'package:http': RegExp(r'''import\s+['"]package:http/'''),
      'package:dio': RegExp(r'''import\s+['"]package:dio/'''),
      'HttpClient': RegExp(r'\bHttpClient\b'),
      'package:qanoniah': RegExp(r'''import\s+['"]package:qanoniah/'''),
      'get_it': RegExp(r'''import\s+['"]package:get_it/'''),
    });
  });

  test('no logging or printing under lib/ (FR-043)', () {
    expectNone(sources, <String, RegExp>{
      'print': RegExp(r'(?<![\w.])print\('),
      'debugPrint': RegExp(r'\bdebugPrint\('),
      'log': RegExp(r'(?<![\w.])log\('),
      'developer.log': RegExp(r'\bdeveloper\.log\('),
      'stdout': RegExp(r'\bstdout\b'),
      'stderr': RegExp(r'\bstderr\b'),
    });
  });

  test('no design literals or foreign icons in presentation (P3, FR-070, FR-072)', () {
    expectNone(
      sources.where((File f) => f.path.contains('/presentation/')),
      <String, RegExp>{
        'Color literal': RegExp(r'\bColor\(0x|\bColor\.fromARGB\(|\bColor\.fromRGBO\('),
        'Colors.*': RegExp(r'\bColors\.\w+'),
        'numeric fontSize': RegExp(r'fontSize:\s*\d'),
        'numeric EdgeInsets': RegExp(r'EdgeInsets(Directional)?\.\w+\(\s*\d'),
        'numeric radius': RegExp(r'(BorderRadius|Radius)\.circular\(\s*\d'),
        'Material Icons': RegExp(r'\bIcons\.\w+'),
        'CupertinoIcons': RegExp(r'\bCupertinoIcons\.\w+'),
      },
    );
  });
}
