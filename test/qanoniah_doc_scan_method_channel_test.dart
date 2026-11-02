import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qanoniah_doc_scan/qanoniah_doc_scan_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelQanoniahDocScan platform = MethodChannelQanoniahDocScan();
  const MethodChannel channel = MethodChannel('qanoniah_doc_scan');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
