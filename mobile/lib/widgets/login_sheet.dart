import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../screens/legal_screen.dart';
import '../services/auth_service.dart';
import '../services/netwix_api.dart';
import '../state/app_state.dart';
import '../state/member_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Opens the NetWix sign-in sheet. Returns true if the user signed in.
Future<bool> showLoginSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LoginSheet(),
  );
  return ok ?? false;
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  AuthProvider? _busy;

  /// Server-configured social providers (null = still loading). Providers
  /// without credentials are hidden so nobody taps a dead button.
  Map<String, bool>? _social;

  /// ToS/privacy consent. Persisted once accepted, so a returning user sees a
  /// plain "การเข้าสู่ระบบถือว่ายอมรับ..." line instead of the checkbox.
  bool _agreed = false;
  bool _alreadyConsented = false;

  @override
  void initState() {
    super.initState();
    _alreadyConsented = context.read<AppState>().settings.consentAccepted;
    _agreed = _alreadyConsented;
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final p = await context.read<NetwixApi>().fetchAuthProviders();
    if (mounted) setState(() => _social = p);
  }

  bool _lineEnabled() => _social?['line'] == true;
  bool _googleEnabled() => _social?['google'] == true;

  Future<void> _login(AuthProvider provider) async {
    if (_busy != null) return;
    final l = context.read<AppState>().l;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.pick('กรุณายอมรับข้อตกลงการใช้งานก่อนเข้าสู่ระบบ',
                'Please accept the terms before signing in'))),
      );
      return;
    }
    if (!_alreadyConsented) {
      _alreadyConsented = true;
      await context.read<AppState>().settings.setConsentAccepted(true);
    }
    if (!mounted) return;
    setState(() => _busy = provider);
    try {
      await context.read<MemberState>().login(provider);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthCancelled {
      if (mounted) setState(() => _busy = null); // user backed out — no error
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pick('เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง', 'Sign-in failed, please try again'))),
      );
    }
  }

  Future<void> _openLineDownload() async {
    try {
      await launchUrl(Uri.parse('https://line.me/download'), mode: LaunchMode.externalApplication);
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 22,
        bottom: 22 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: T.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: T.hairlineStrong)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pick('เข้าสู่ระบบ NetWix', 'Sign in to NetWix'),
              style: AppTheme.display(20, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              l.pick('บันทึกประวัติดู รายการโปรด และรับ 10 เหรียญฟรีครั้งแรก',
                  'Save history, favorites & get 10 free coins on first sign-in'),
              style: AppTheme.body(13, color: T.textMuted)),
          const SizedBox(height: 14),
          _consent(l),
          const SizedBox(height: 14),

          // Social providers load from the server; only configured ones show.
          if (_social == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: T.accent)),
              ),
            )
          else ...[
            if (_lineEnabled()) ...[
              _providerBtn(AuthProvider.line, l),
              const SizedBox(height: 10),
            ],
            if (_googleEnabled()) ...[
              _providerBtn(AuthProvider.google, l),
              const SizedBox(height: 10),
            ],
          ],

          // Email is always available (no external credentials needed).
          _providerBtn(AuthProvider.email, l),

          if (_lineEnabled()) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy == null ? _openLineDownload : null,
                child: Text(l.pick('ยังไม่มีบัญชี LINE? ติดตั้งแอป LINE', "No LINE account? Install LINE"),
                    style: AppTheme.body(12.5, color: T.textMuted)),
              ),
            ),
          ],

          const SizedBox(height: 2),
          Center(
            child: TextButton(
              onPressed: _busy == null ? () => Navigator.of(context).pop(false) : null,
              child: Text(l.pick('ไว้ทีหลัง', 'Maybe later'),
                  style: AppTheme.body(13, color: T.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  /// ToS/privacy consent line. First run: a required checkbox. After the user
  /// has consented once: an informational line with the same links.
  Widget _consent(L10n l) {
    Widget link(String label, String doc) => GestureDetector(
          onTap: _busy == null
              ? () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)))
              : null,
          child: Text(label,
              style: AppTheme.body(12,
                  weight: FontWeight.w700,
                  color: T.accent,
                  ).copyWith(decoration: TextDecoration.underline, decorationColor: T.accent)),
        );

    final text = Expanded(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
              _alreadyConsented
                  ? l.pick('การเข้าสู่ระบบถือว่าคุณยอมรับ', 'By signing in you agree to the')
                  : l.pick('ฉันได้อ่านและยอมรับ', 'I have read and accept the'),
              style: AppTheme.body(12, color: T.textMuted)),
          link(l.pick('ข้อตกลงการใช้งาน', 'Terms'), 'terms'),
          Text(l.pick('และ', 'and'), style: AppTheme.body(12, color: T.textMuted)),
          link(l.pick('นโยบายความเป็นส่วนตัว', 'Privacy Policy'), 'privacy'),
        ],
      ),
    );

    if (_alreadyConsented) {
      return Row(children: [
        const Icon(Icons.verified_user_rounded, size: 16, color: T.textFaint),
        const SizedBox(width: 8),
        text,
      ]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _agreed,
            onChanged: _busy == null ? (v) => setState(() => _agreed = v ?? false) : null,
            activeColor: T.accent,
            side: const BorderSide(color: T.textMuted, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        text,
      ],
    );
  }

  /// Brand-styled provider button: LINE green, Google white, email neutral.
  Widget _providerBtn(AuthProvider provider, L10n l) {
    final busy = _busy == provider;
    final disabled = _busy != null && !busy;

    final Color bg, fg, border;
    final Widget mark;
    final String label;
    switch (provider) {
      case AuthProvider.line:
        bg = const Color(0xFF06C755);
        fg = Colors.white;
        border = Colors.transparent;
        mark = const Icon(Icons.chat_bubble_rounded, size: 20, color: Colors.white);
        label = l.pick('ดำเนินการต่อด้วย LINE', 'Continue with LINE');
      case AuthProvider.google:
        bg = Colors.white;
        fg = const Color(0xFF1F1F1F);
        border = Colors.transparent;
        mark = const Text('G',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)));
        label = l.pick('ดำเนินการต่อด้วย Google', 'Continue with Google');
      case AuthProvider.email:
        bg = const Color(0x14FFFFFF);
        fg = T.textPrimary;
        border = T.hairlineStrong;
        mark = Icon(Icons.mail_outline_rounded, size: 20, color: T.textPrimary);
        label = l.pick('อีเมล / รหัสผ่าน', 'Email / password');
    }

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => _login(provider),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(T.rButton),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else
                mark,
              const SizedBox(width: 10),
              Text(label, style: AppTheme.body(14, weight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
