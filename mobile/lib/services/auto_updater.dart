import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'netwix_api.dart';
import 'update_info.dart';

/// Progress of an in-flight update install.
class UpdateProgress {
  const UpdateProgress(this.phase, {this.percent, this.error});
  final UpdatePhase phase;
  final int? percent;
  final String? error;
}

enum UpdatePhase { downloading, installing, done, error }

/// In-app self-update: reads the latest release manifest from netwix.online,
/// compares versions, and (on Android) downloads + installs the APK via
/// `ota_update`.
///
/// Distribution is sideloaded (NOT Play Store), so we use `ota_update` rather
/// than `in_app_update`. Both the version check (`/api/app/version`) and the APK
/// download (`/download/apk`) go entirely through our own domain — the app never
/// contacts or reveals where the binary is actually built. Because every release
/// keeps the same `applicationId` and signing key, Android installs the new APK
/// over the old one and **user data is preserved**.
class AutoUpdater {
  AutoUpdater({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  /// Version manifest on our own API (`https://netwix.online/api/app/version`).
  static String get versionApi => '${NetwixApi.baseUrl}/version';

  /// Where the APK is downloaded from — a fixed route on our own domain that
  /// mirrors + streams the latest build. Kept as our canonical origin (not a
  /// server-supplied link) so the download target can never point off-domain.
  static String get apkDownloadUrl => '${NetwixApi.origin}/download/apk';

  final Dio _dio;

  /// Library-global guard so two concurrent checks can't fire two network calls
  /// and stack two update sheets (learned from Juntra's double-tap bug).
  static bool _checkInFlight = false;

  /// Asks our API for the latest release and reports whether it's newer than the
  /// running build. Returns null on any network/parse failure (callers show a
  /// generic message — never a raw exception, and never anything off-domain).
  Future<UpdateInfo?> checkForUpdate() async {
    if (_checkInFlight) return null;
    _checkInFlight = true;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final curVer = pkg.version; // e.g. "1.0.0"
      final curBuild = int.tryParse(pkg.buildNumber) ?? 0;

      final resp = await _dio.get<Map<String, dynamic>>(versionApi);
      final body = resp.data;
      // Envelope: {success, data}. A null `data` means "no release / up to date".
      final data = (body != null &&
              body['success'] == true &&
              body['data'] is Map)
          ? (body['data'] as Map).cast<String, dynamic>()
          : null;
      if (data == null) return null;

      final tag = (data['tag'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;

      final parsed = ReleaseVersion.parse(tag);
      final latestVersion = parsed.parts.join('.');
      final latestBuild = parsed.build;
      final notes = _sanitizeNotes((data['notes'] as String?) ?? '');
      final apkSize = (data['size'] as num?)?.toInt() ?? 0;

      final available =
          isReleaseNewer(curVer, curBuild, latestVersion, latestBuild);

      return UpdateInfo(
        available: available,
        currentVersion: curVer,
        currentBuild: curBuild,
        latestVersion: latestVersion,
        latestBuild: latestBuild,
        tag: tag,
        notes: notes,
        // Always our own domain — see [apkDownloadUrl].
        apkUrl: available ? apkDownloadUrl : null,
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
        destinationFilename: 'netwix-${info.latestVersion}.apk',
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

  /// Defence-in-depth: strip GitHub's auto-appended "Full Changelog" line and any
  /// github.com links from the release notes before they reach the update sheet.
  /// The server sanitises too, but the app must never render an off-domain link
  /// even if it somehow receives one (old server, tampered response).
  static String _sanitizeNotes(String raw) {
    var s = raw.replaceAll(
        RegExp(r'^\s*\*{0,2}Full Changelog\*{0,2}:.*$',
            multiLine: true, caseSensitive: false),
        '');
    s = s.replaceAll(
        RegExp(r'https?://\S*github(usercontent)?\.com/\S*', caseSensitive: false),
        '');
    return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
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
