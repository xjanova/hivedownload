import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../models/member.dart';
import 'netwix_api.dart';

enum AuthProvider { google, line, email }

extension AuthProviderX on AuthProvider {
  String? get query => switch (this) {
        AuthProvider.google => 'google',
        AuthProvider.line => 'line',
        AuthProvider.email => null,
      };
  String get label => switch (this) {
        AuthProvider.google => 'Google',
        AuthProvider.line => 'LINE',
        AuthProvider.email => 'อีเมล',
      };
}

class AuthResult {
  const AuthResult(this.member);
  final Member member;
}

/// Thrown when the user dismisses the in-app browser without finishing.
class AuthCancelled implements Exception {}

/// Sign-in that reuses the NetWix **web** login (Google / LINE / email). Opens
/// `/mauth/start` in an in-app browser tab, lets the user authenticate on the
/// site, then captures the `netwix://auth?code=…` deep link and exchanges the
/// one-time code for a bearer token. No native OAuth client / SDK needed.
class AuthService {
  AuthService(this._api);
  final NetwixApi _api;

  static const String _callbackScheme = 'netwix';

  Future<AuthResult> signIn(AuthProvider provider) async {
    final q = provider.query;
    final url = '${NetwixApi.origin}/mauth/start${q != null ? '?provider=$q' : ''}';

    final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: _callbackScheme,
      );
    } catch (e) {
      // The plugin throws on user-cancel (tab closed); surface it cleanly.
      if (kDebugMode) debugPrint('web auth cancelled/failed: $e');
      throw AuthCancelled();
    }

    final code = Uri.tryParse(callback)?.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('ไม่ได้รับรหัสยืนยันจากการเข้าสู่ระบบ');
    }

    final data = await _api.exchangeCode(code);
    final token = data?['token'] as String?;
    final user = data?['user'];
    if (token == null || user is! Map) {
      throw Exception('แลกรหัสเข้าสู่ระบบไม่สำเร็จ');
    }

    return AuthResult(Member.fromNetwixUser(user.cast<String, dynamic>(), token: token));
  }
}
