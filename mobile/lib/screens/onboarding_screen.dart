import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'app_shell.dart';

/// 01 — Onboarding · เริ่มต้นใช้งาน. First-run pitch + entry.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = app.l;

    return Scaffold(
      body: DecoratedBox(
        decoration: T.screenBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // hero gem cluster
                Floating(
                  child: SizedBox(
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const GemCrest(size: 118, icon: Icons.download_rounded),
                        Positioned(left: 30, top: 8, child: _facet(30)),
                        Positioned(right: 26, top: 18, child: _facet(24)),
                        Positioned(right: 44, bottom: 6, child: _facet(18)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _pager(),
                const SizedBox(height: 22),
                Text(
                  l.pick('ดูฟรีทุกเรื่อง\nไม่มีโฆษณากวนใจ', 'Watch everything free\nNo annoying ads'),
                  textAlign: TextAlign.center,
                  style: AppTheme.display(25, weight: FontWeight.w700, letterSpacing: -0.02),
                ),
                const SizedBox(height: 10),
                Text('Series & movies — free, no ads.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(13, weight: FontWeight.w600, color: T.accent)),
                const SizedBox(height: 12),
                Text(
                  l.pick(
                    'ดูฟรีทุกเรื่อง ทุกประเภท · ไม่ต้องหยอดเหรียญ\nสมัคร Pro เพียง 129฿/เดือน เพื่อรับชมแบบไม่มีโฆษณา',
                    'Everything free · no coins per episode\nGo Pro for just 129฿/month to watch ad-free',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTheme.body(12.5, color: T.textMuted),
                ),
                const Spacer(flex: 2),
                AccentButton(
                  label: l.bi('เริ่มเลย', 'Get Started'),
                  onPressed: () async {
                    await app.completeOnboarding();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: l.bi('เข้าสู่ระบบ', 'Sign in'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.pick('การเข้าสู่ระบบจะมาในเวอร์ชันถัดไป', 'Sign-in coming soon'))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _facet(double s) => HexBox(
        size: s,
        child: const DecoratedBox(decoration: BoxDecoration(gradient: T.gemGradient)),
      );

  Widget _pager() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(true),
          _dot(false),
          _dot(false),
        ],
      );

  Widget _dot(bool active) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 22 : 7,
        height: 7,
        decoration: BoxDecoration(
          color: active ? T.accent : T.hairlineStrong,
          borderRadius: BorderRadius.circular(100),
        ),
      );
}
