import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/settings_store.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'go_pro_screen.dart';
import 'whats_new_screen.dart';

/// 07 — Menu / Settings · เมนู. Bilingual rows (Thai bold + English muted).
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = app.l;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text(l.bi('เมนู', 'Menu'), style: AppTheme.display(21, weight: FontWeight.w700)),
        const SizedBox(height: 16),
        _profileCard(context, app),
        const SizedBox(height: 16),
        _languageRow(context, app),
        const SizedBox(height: 8),
        _row(context, Icons.notifications_rounded, 'การแจ้งเตือน', 'Notifications',
            onTap: () => _soon(context, l)),
        _row(context, Icons.system_update_rounded, 'อัปเดต', 'Updates',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WhatsNewScreen()))),
        _row(context, Icons.info_rounded, 'เกี่ยวกับ', 'About', onTap: () => _about(context, l)),
        const SizedBox(height: 20),
        if (!app.isPro) _upgradeBanner(context, l) else _proActiveBanner(l),
      ],
    );
  }

  Widget _profileCard(BuildContext context, AppState app) {
    final l = app.l;
    return GlassCard(
      child: Row(
        children: [
          const HexAvatar(size: 52, child: Icon(Icons.person, color: T.accentHi, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.pick('ผู้ใช้ทั่วไป', 'Guest'),
                    style: AppTheme.body(15, weight: FontWeight.w700, color: T.textPrimary)),
                Text(app.isPro ? l.bi('แผน Pro', 'Pro plan') : l.bi('แผนฟรี', 'Free plan'),
                    style: AppTheme.body(12, color: T.textMuted)),
              ],
            ),
          ),
          if (app.isPro) const Pill(text: 'PRO', filled: true),
        ],
      ),
    );
  }

  Widget _languageRow(BuildContext context, AppState app) {
    final l = app.l;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.accentSoft,
        borderRadius: BorderRadius.circular(T.rCard),
      ),
      child: Row(
        children: [
          const HexIcon(icon: Icons.translate_rounded, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.bi('ภาษา', 'Language'),
                style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
          ),
          _segToggle(context, app),
        ],
      ),
    );
  }

  Widget _segToggle(BuildContext context, AppState app) {
    Widget seg(String label, bool active, AppLang lang) => GestureDetector(
          onTap: () => app.setLang(lang),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: active ? T.accentGradient : null,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: AppTheme.body(12.5,
                    weight: FontWeight.w700, color: active ? T.onAccent : T.textMuted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: T.hairline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('ไทย', app.lang == AppLang.th, AppLang.th),
        seg('EN', app.lang == AppLang.en, AppLang.en),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String th, String en, {VoidCallback? onTap, String? value}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.rCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            HexIcon(icon: icon, size: 34, color: T.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(th, style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
                  Text(en, style: AppTheme.body(11, color: T.textFaint)),
                ],
              ),
            ),
            if (value != null) Text(value, style: AppTheme.body(12.5, color: T.textMuted)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: T.textFaint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _upgradeBanner(BuildContext context, L10n l) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoProScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: T.accentGradient, borderRadius: BorderRadius.circular(T.rCard)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.pick('อัปเกรดเป็น Pro', 'Go Pro'),
                      style: AppTheme.display(16, weight: FontWeight.w700, color: T.onAccent)),
                  Text(l.pick('รับชมแบบไม่มีโฆษณา · ฿129/เดือน', 'Ad-free viewing · ฿129/mo'),
                      style: AppTheme.body(12, color: Color(0xCC2A1C05))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: T.onAccent),
          ],
        ),
      ),
    );
  }

  Widget _proActiveBanner(L10n l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.accentSoft,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: T.accentGlow),
      ),
      child: Row(
        children: [
          const HexIcon(icon: Icons.verified_rounded, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.bi('กำลังรับชมแบบไม่มีโฆษณา', 'Watching ad-free'),
                style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _soon(BuildContext context, L10n l) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pick('จะมาในเวอร์ชันถัดไป', 'Coming soon'))),
      );

  void _about(BuildContext context, L10n l) => showAboutDialog(
        context: context,
        applicationName: 'Hive Download',
        applicationVersion: l.pick('ดูฟรี · สตรีมมิ่ง', 'Free streaming'),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l.pick(
                'สำหรับการรับชมส่วนตัวเท่านั้น ทุกเรื่องดูฟรี · Pro 129฿ เพื่อรับชมแบบไม่มีโฆษณา',
                'For personal viewing only. Everything is free · Pro 129฿ for ad-free.',
              ),
              style: AppTheme.body(12.5, color: T.textMuted),
            ),
          ),
        ],
      );
}
