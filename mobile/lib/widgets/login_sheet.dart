import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
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

  Future<void> _login(AuthProvider provider) async {
    if (_busy != null) return;
    setState(() => _busy = provider);
    final l = context.read<AppState>().l;
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
          Text(l.pick('บันทึกประวัติดู รายการโปรด และรับ 10 เหรียญฟรีครั้งแรก',
              'Save history, favorites & get 10 free coins on first sign-in'),
              style: AppTheme.body(13, color: T.textMuted)),
          const SizedBox(height: 20),
          _providerBtn(AuthProvider.google, Icons.g_mobiledata_rounded, l),
          const SizedBox(height: 10),
          _providerBtn(AuthProvider.line, Icons.chat_bubble_rounded, l),
          const SizedBox(height: 10),
          _providerBtn(AuthProvider.email, Icons.mail_outline_rounded, l),
          const SizedBox(height: 8),
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

  Widget _providerBtn(AuthProvider provider, IconData icon, l) {
    final busy = _busy == provider;
    final disabled = _busy != null && !busy;
    final label = switch (provider) {
      AuthProvider.google => l.pick('ดำเนินการต่อด้วย Google', 'Continue with Google'),
      AuthProvider.line => l.pick('ดำเนินการต่อด้วย LINE', 'Continue with LINE'),
      AuthProvider.email => l.pick('อีเมล / รหัสผ่าน', 'Email / password'),
    };
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => _login(provider),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(T.rButton),
            border: Border.all(color: T.hairlineStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: T.accent))
              else
                Icon(icon, size: 22, color: T.textPrimary),
              const SizedBox(width: 10),
              Text(label, style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
