
import 'qanoniah_doc_scan_platform_interface.dart';

class QanoniahDocScan {
  Future<String?> getPlatformVersion() {
    return QanoniahDocScanPlatform.instance.getPlatformVersion();
  }
}
