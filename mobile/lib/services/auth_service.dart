import 'package:flutter/foundation.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/member.dart';
import 'netwix_client.dart';

enum AuthProvider { google, line }

class AuthResult {
  const AuthResult(this.member, {this.fromBackend = false});
  final Member member;
  final bool fromBackend;
}

/// Google + LINE sign-in, exchanged with netwix.online for a session.
///
/// The real provider flows are wired. Until the OAuth apps + netwix backend are
/// configured they throw, and we fall back to a **local account of that
/// provider** so the sign-in → coins → unlock loop is fully testable today.
/// Fill [googleServerClientId] / [lineChannelId] (or configure natively) to go
/// live.
class AuthService {
  AuthService(this._netwix);
  final NetwixClient _netwix;
  bool _googleReady = false;

  static const String googleServerClientId = ''; // web OAuth client id
  static const String lineChannelId = ''; // LINE Login channel id

  Future<AuthResult> signIn(AuthProvider provider, {String? ref}) async {
    switch (provider) {
      case AuthProvider.google:
        return _google(ref);
      case AuthProvider.line:
        return _line(ref);
    }
  }

  Future<AuthResult> _google(String? ref) async {
    try {
      final g = GoogleSignIn.instance;
      if (!_googleReady) {
        await g.initialize(
            serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId);
        _googleReady = true;
      }
      final account = await g.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken != null) {
        final m = await _netwix.authWithGoogle(idToken, ref: ref);
        if (m != null) return AuthResult(m, fromBackend: true);
      }
      return AuthResult(_local('google', account.displayName ?? account.email, account.photoUrl));
    } catch (e) {
      if (kDebugMode) debugPrint('google sign-in fell back to local: $e');
      return AuthResult(_local('google', 'ผู้ใช้ Google', null));
    }
  }

  Future<AuthResult> _line(String? ref) async {
    try {
      if (lineChannelId.isNotEmpty) {
        LineSDK.instance.setup(lineChannelId);
      }
      final result = await LineSDK.instance.login(scopes: const ['profile', 'openid']);
      final token = result.accessToken.value;
      final m = await _netwix.authWithLine(token, ref: ref);
      if (m != null) return AuthResult(m, fromBackend: true);
      final p = result.userProfile;
      return AuthResult(_local('line', p?.displayName ?? 'ผู้ใช้ LINE', p?.pictureUrl));
    } catch (e) {
      if (kDebugMode) debugPrint('line sign-in fell back to local: $e');
      return AuthResult(_local('line', 'ผู้ใช้ LINE', null));
    }
  }

  Member _local(String provider, String name, String? avatar) => Member(
        id: 'local-$provider',
        name: name,
        avatar: avatar,
        provider: provider,
        referralCode: _refCode(),
      );

  String _refCode() {
    final n = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'HD${n.toString().padLeft(6, '0')}';
  }
}
