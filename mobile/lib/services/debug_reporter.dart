import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'netwix_api.dart';

/// Ships lightweight diagnostics to netwix.online (`POST /api/app/debug`) so
/// issues on real devices — especially sign-in / LINE — can be analysed
/// server-side. Fire-and-forget, never throws, and MUST NOT carry secrets
/// (bearer tokens, passwords, one-time login codes). Keep events terse and put
/// only non-sensitive detail in [context].
class DebugReporter {
  DebugReporter._();
  static final DebugReporter instance = DebugReporter._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Accept': 'application/json'},
  ));

  String _appVersion = '';
  bool _enabled = true;

  void configure({required String appVersion, bool enabled = true}) {
    _appVersion = appVersion;
    _enabled = enabled;
  }

  String get _platform =>
      Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');

  /// Report one diagnostic line. [event] is a short dotted key
  /// (e.g. `auth.line.exchange_fail`); [level] is info|warn|error.
  Future<void> report(
    String event, {
    String level = 'info',
    String? message,
    Map<String, dynamic>? context,
  }) async {
    if (!_enabled) return;
    try {
      await _dio.post(
        '${NetwixApi.baseUrl}/debug',
        data: {
          'level': level,
          'event': event,
          'message': ?message,
          'context': ?context,
          'app_version': _appVersion,
          'platform': _platform,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('debug report failed: $e');
    }
  }
}

/// Shorthand for [DebugReporter.instance.report].
Future<void> debugReport(
  String event, {
  String level = 'info',
  String? message,
  Map<String, dynamic>? context,
}) =>
    DebugReporter.instance.report(event, level: level, message: message, context: context);
