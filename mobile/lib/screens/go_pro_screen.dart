import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// 05 — Go Pro · สมัคร Pro. 129฿/mo. Pro = **ad-free** viewing (all content is
/// free either way; Pro just removes ads).
class GoProScreen extends StatelessWidget {
  const GoProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l = app.l;

    final benefits = [
      l.bi('ไม่มีโฆษณาระหว่างดู', 'No ads while watching'),
      l.bi('ดูฟรีทุกเรื่องเหมือนเดิม', 'Everything still free to watch'),
      l.bi('รับชมลื่นไหล ไม่มีสะดุด', 'Smooth, uninterrupted viewing'),
      l.bi('สนับสนุนผู้พัฒนา', 'Support the developer'),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.1,
            colors: [Color(0x33F5A623), Colors.transparent],
            stops: [0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: T.textSecondary),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Center(child: Floating(child: const GemCrest(size: 84, icon: Icons.star_rounded))),
                    const SizedBox(height: 18),
                    Center(
                      child: Text('Hive Download Pro',
                          style: AppTheme.display(24, weight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(l.bi('รับชมแบบไม่มีโฆษณา', 'Watch ad-free'),
                          style: AppTheme.body(13.5, color: T.textMuted)),
                    ),
                    const SizedBox(height: 26),
                    for (final b in benefits) _benefit(b),
                    const SizedBox(height: 24),
                    _planCard(l, primary: true, title: l.bi('รายเดือน', 'Monthly'), price: '฿129', per: l.pick('/เดือน', '/mo'), tag: l.pick('ยอดนิยม', 'POPULAR')),
                    const SizedBox(height: 12),
                    _planCard(l, primary: false, title: l.bi('รายปี', 'Yearly'), price: '฿990', per: l.pick('/ปี', '/yr'), tag: l.pick('ประหยัด 36%', 'Save 36%')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: AccentButton(
                  label: app.isPro ? l.pick('เป็นสมาชิก Pro แล้ว', 'You are Pro') : l.bi('สมัคร Pro', 'Start Pro'),
                  icon: app.isPro ? Icons.check_rounded : Icons.star_rounded,
                  enabled: !app.isPro,
                  onPressed: () async {
                    await app.setPro(true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l.pick('เปิดใช้งาน Pro แล้ว — ไม่มีโฆษณาแล้ว', 'Pro enabled — ads removed')),
                      ));
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.bi('ยกเลิกได้ทุกเมื่อ', 'Cancel anytime'),
                    style: AppTheme.body(11.5, color: T.textFaint)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: T.accentSoft, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 15, color: T.accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTheme.body(14, color: T.textSecondary))),
          ],
        ),
      );

  Widget _planCard(L10n l, {required bool primary, required String title, required String price, required String per, required String tag}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary ? T.accentSoft : const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: primary ? T.accentGlow : T.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: AppTheme.body(15, weight: FontWeight.w700, color: T.textPrimary)),
                  const SizedBox(width: 8),
                  Pill(text: tag, filled: primary, color: primary ? T.accent : T.textMuted),
                ]),
                const SizedBox(height: 4),
                Text(l.pick('เรียกเก็บเป็นรอบ', 'Billed each cycle'),
                    style: AppTheme.body(11.5, color: T.textFaint)),
              ],
            ),
          ),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: price, style: AppTheme.display(22, weight: FontWeight.w700, color: T.textPrimary)),
              TextSpan(text: ' $per', style: AppTheme.body(12, color: T.textMuted)),
            ]),
          ),
        ],
      ),
    );
  }
}
