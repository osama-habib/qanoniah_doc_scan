import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qanoniah_doc_scan_platform_interface.dart';

/// An implementation of [QanoniahDocScanPlatform] that uses method channels.
class MethodChannelQanoniahDocScan extends QanoniahDocScanPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qanoniah_doc_scan');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
