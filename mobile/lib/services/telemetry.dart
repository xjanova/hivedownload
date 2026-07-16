import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'netwix_api.dart';
import 'settings_store.dart';

/// Anonymous device-statistics ping (`POST /api/app/telemetry`), sent once per
/// launch so the backend's "สถิติแอป" screen can see which models/OS versions
/// are actually in use. Disclosed in the privacy policy. Deliberately collects
/// NO hardware identifiers — the install is keyed by [SettingsStore.deviceKey],
/// a random string that resets with a reinstall.
class Telemetry {
  Telemetry._();

  static bool _sent = false;

  /// Fire-and-forget; safe to call more than once (only the first wins).
  static Future<void> report(NetwixApi api, SettingsStore settings) async {
    if (_sent) return;
    _sent = true;
    try {
      final payload = <String, dynamic>{'device_key': settings.deviceKey};

      try {
        final info = await PackageInfo.fromPlatform();
        payload['app_version'] = info.version;
      } catch (_) {/* best-effort */}

      try {
        if (Platform.isAndroid) {
          final a = await DeviceInfoPlugin().androidInfo;
          payload['platform'] = 'android';
          payload['os_version'] = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
          payload['device_model'] = '${a.manufacturer} ${a.model}'.trim();
        } else if (Platform.isIOS) {
          final i = await DeviceInfoPlugin().iosInfo;
          payload['platform'] = 'ios';
          payload['os_version'] = '${i.systemName} ${i.systemVersion}';
          payload['device_model'] = i.utsname.machine;
        } else {
          payload['platform'] = Platform.operatingSystem;
        }
      } catch (_) {/* best-effort */}

      final views = PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        final size = views.first.physicalSize;
        payload['screen'] = '${size.width.round()}x${size.height.round()}';
      }
      payload['locale'] = PlatformDispatcher.instance.locale.toLanguageTag();

      await api.sendTelemetry(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('telemetry: $e');
    }
  }
}
