import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan_platform_interface.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQanoniahDocScanPlatform
    with MockPlatformInterfaceMixin
    implements QanoniahDocScanPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QanoniahDocScanPlatform initialPlatform = QanoniahDocScanPlatform.instance;

  test('$MethodChannelQanoniahDocScan is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQanoniahDocScan>());
  });

  test('getPlatformVersion', () async {
    QanoniahDocScan qanoniahDocScanPlugin = QanoniahDocScan();
    MockQanoniahDocScanPlatform fakePlatform = MockQanoniahDocScanPlatform();
    QanoniahDocScanPlatform.instance = fakePlatform;

    expect(await qanoniahDocScanPlugin.getPlatformVersion(), '42');
  });
}
