import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qanoniah_doc_scan_method_channel.dart';

abstract class QanoniahDocScanPlatform extends PlatformInterface {
  /// Constructs a QanoniahDocScanPlatform.
  QanoniahDocScanPlatform() : super(token: _token);

  static final Object _token = Object();

  static QanoniahDocScanPlatform _instance = MethodChannelQanoniahDocScan();

  /// The default instance of [QanoniahDocScanPlatform] to use.
  ///
  /// Defaults to [MethodChannelQanoniahDocScan].
  static QanoniahDocScanPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QanoniahDocScanPlatform] when
  /// they register themselves.
  static set instance(QanoniahDocScanPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
