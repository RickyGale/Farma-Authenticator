import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdentityService {
  Future<String> getDeviceId() async {
    if (Platform.isWindows) {
      final computerName = Platform.environment['COMPUTERNAME'];
      return computerName != null && computerName.isNotEmpty
          ? computerName
          : Platform.localHostname;
    }
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      final id = await const AndroidId().getId();
      if (id != null) return id;
      return sha256
          .convert(
            utf8.encode('${info.brand}|${info.model}|${info.fingerprint}'),
          )
          .toString();
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      final id = info.identifierForVendor;
      if (id != null && id.isNotEmpty) return id;
      return sha256
          .convert(
            utf8.encode('${info.name}|${info.model}|${info.systemVersion}'),
          )
          .toString();
    }
    return 'unknown-device';
  }
}
