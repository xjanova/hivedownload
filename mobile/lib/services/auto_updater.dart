import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'update_info.dart';

/// Progress of an in-flight update install.
class UpdateProgress {
  const UpdateProgress(this.phase, {this.percent, this.error});
  final UpdatePhase phase;
  final int? percent;
  final String? error;
}

enum UpdatePhase { downloading, installing, done, error }

/// In-app self-update: reads the latest GitHub Release, compares versions, and
/// (on Android) downloads + installs the attached APK via `ota_update`.
///
/// Distribution model is sideloaded GitHub Releases (NOT Play Store), so we use
/// `ota_update` rather than `in_app_update`. Because every release keeps the
/// same `applicationId` and signing key, Android installs the new APK over the
/// old one and **user data is preserved**.
class AutoUpdater {
  AutoUpdater({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/vnd.github+json'},
            ));

  static const String owner = 'xjanova';
  static const String repo = 'hivedownload';
  static String get latestReleaseApi =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  final Dio _dio;

  /// Library-global guard so two concurrent checks can't fire two network calls
  /// and stack two update sheets (learned from Juntra's double-tap bug).
  static bool _checkInFlight = false;

  /// Queries GitHub for the latest release and reports whether it's newer than
  /// the running build. Returns null on any network/parse failure (callers show
  /// a generic message — never a raw exception).
  Future<UpdateInfo?> checkForUpdate() async {
    if (_checkInFlight) return null;
    _checkInFlight = true;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final curVer = pkg.version; // e.g. "1.0.0"
      final curBuild = int.tryParse(pkg.buildNumber) ?? 0;

      final resp = await _dio.get<Map<String, dynamic>>(latestReleaseApi);
      final data = resp.data;
      if (data == null) return null;

      final tag = (data['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;

      final parsed = ReleaseVersion.parse(tag);
      final latestVersion = parsed.parts.join('.');
      final latestBuild = parsed.build;
      final notes = (data['body'] as String?)?.trim() ?? '';

      // Find the .apk asset.
      String? apkUrl;
      var apkSize = 0;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map &&
              (a['name'] as String?)?.toLowerCase().endsWith('.apk') == true) {
            apkUrl = a['browser_download_url'] as String?;
            apkSize = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      final available =
          isReleaseNewer(curVer, curBuild, latestVersion, latestBuild) &&
              apkUrl != null;

      return UpdateInfo(
        available: available,
        currentVersion: curVer,
        currentBuild: curBuild,
        latestVersion: latestVersion,
        latestBuild: latestBuild,
        tag: tag,
        notes: notes,
        apkUrl: apkUrl,
        apkSizeBytes: apkSize,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('checkForUpdate failed: $e');
      return null;
    } finally {
      _checkInFlight = false;
    }
  }

  /// Downloads and installs the APK, streaming coarse-grained progress.
  ///
  /// Status handling is intentionally forgiving: we categorise by the enum's
  /// *name* (contains "ERROR"/"DONE") so a future plugin version that adds a new
  /// [OtaStatus] can't break the compile or silently mis-route (Juntra lesson).
  Stream<UpdateProgress> downloadAndInstall(UpdateInfo info) async* {
    final url = info.apkUrl;
    if (url == null) {
      yield const UpdateProgress(UpdatePhase.error, error: 'ไม่พบไฟล์ติดตั้ง (APK)');
      return;
    }

    try {
      final stream = OtaUpdate().execute(
        url,
        destinationFilename: 'hivedownload-${info.latestVersion}.apk',
        usePackageInstaller: true,
      );

      await for (final event in stream) {
        final name = event.status.name; // e.g. "DOWNLOADING"
        if (name == 'DOWNLOADING') {
          yield UpdateProgress(UpdatePhase.downloading,
              percent: int.tryParse(event.value ?? ''));
        } else if (name == 'INSTALLING') {
          yield const UpdateProgress(UpdatePhase.installing);
        } else if (name.contains('DONE')) {
          yield const UpdateProgress(UpdatePhase.done);
        } else if (name.contains('ERROR') || name == 'CANCELED') {
          yield UpdateProgress(UpdatePhase.error, error: _friendlyError(name, event.value));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('downloadAndInstall failed: $e');
      yield const UpdateProgress(UpdatePhase.error, error: 'อัปเดตไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  String _friendlyError(String statusName, String? value) {
    if (statusName.contains('PERMISSION')) {
      return 'ต้องอนุญาตการติดตั้งแอปจากแหล่งนี้ก่อน';
    }
    if (statusName == 'CANCELED') return 'ยกเลิกการอัปเดตแล้ว';
    if (statusName.contains('DOWNLOAD')) return 'ดาวน์โหลดไฟล์ติดตั้งไม่สำเร็จ';
    if (statusName.contains('CHECKSUM')) return 'ไฟล์ติดตั้งเสียหาย ลองใหม่อีกครั้ง';
    return 'อัปเดตไม่สำเร็จ ลองใหม่อีกครั้ง';
  }
}
