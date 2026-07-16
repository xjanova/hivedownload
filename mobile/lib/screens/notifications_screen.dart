import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/notice.dart';
import '../services/format.dart';
import '../state/app_state.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';

/// การแจ้งเตือน — the in-app inbox for admin broadcasts, with per-category
/// mute toggles (หนังมาใหม่ / ข่าวจากทีมงาน / อื่น ๆ).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ns = context.read<NotificationState>();
      ns.refresh();
      ns.markAllSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    final ns = context.watch<NotificationState>();
    final notices = ns.notices;

    return Scaffold(
      backgroundColor: T.screen,
      appBar: AppBar(
        backgroundColor: T.screen,
        title: Text(l.pick('การแจ้งเตือน', 'Notifications'),
            style: AppTheme.display(18, weight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: l.pick('ตั้งค่าการแจ้งเตือน', 'Notification settings'),
            onPressed: () => setState(() => _showSettings = !_showSettings),
            icon: Icon(_showSettings ? Icons.tune_rounded : Icons.settings_outlined,
                color: _showSettings ? T.accent : T.textSecondary, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: T.accent,
        backgroundColor: T.screen,
        onRefresh: () => ns.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            if (_showSettings) ...[
              _settingsCard(l, ns),
              const SizedBox(height: 16),
            ],
            if (ns.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: T.accent)),
              )
            else if (notices.isEmpty)
              _empty(l)
            else
              for (final n in notices) _noticeCard(l, n),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(L10n l, String category) => switch (category) {
        'new_content' => l.pick('หนังมาใหม่', 'New releases'),
        'news' => l.pick('ข่าวจากทีมงาน', 'Team news'),
        _ => l.pick('อื่น ๆ', 'Other'),
      };

  IconData _categoryIcon(String category) => switch (category) {
        'new_content' => Icons.movie_filter_rounded,
        'news' => Icons.campaign_rounded,
        _ => Icons.notifications_rounded,
      };

  Widget _settingsCard(L10n l, NotificationState ns) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: T.accentSoft,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: T.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pick('รับการแจ้งเตือนเรื่อง', 'Notify me about'),
              style: AppTheme.body(13, weight: FontWeight.w700, color: T.textPrimary)),
          for (final c in NotificationState.categories)
            SwitchListTile(
              value: ns.categoryEnabled(c),
              onChanged: (v) => ns.setCategoryEnabled(c, v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: T.accent,
              title: Text(_categoryLabel(l, c),
                  style: AppTheme.body(13.5, color: T.textSecondary)),
              secondary: Icon(_categoryIcon(c), size: 18, color: T.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _noticeCard(L10n l, AppNotice n) {
    final hasLink = (n.linkUrl ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rCard),
        onTap: hasLink ? () => _openLink(n.linkUrl!) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: T.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HexIcon(icon: _categoryIcon(n.category), size: 30, color: T.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title,
                            style: AppTheme.body(14, weight: FontWeight.w700, color: T.textPrimary)),
                        Text('${_categoryLabel(l, n.category)} · ${_ago(l, n.publishedAt)}',
                            style: AppTheme.body(10.5, color: T.textFaint)),
                      ],
                    ),
                  ),
                  if (hasLink)
                    const Icon(Icons.chevron_right_rounded, color: T.textFaint, size: 20),
                ],
              ),
              if (n.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(n.body, style: AppTheme.body(12.5, color: T.textSecondary)),
              ],
              if ((n.imageUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(T.rMedia),
                  child: Image.network(
                    n.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 140,
                    cacheWidth: 800,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(L10n l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          const Icon(Icons.notifications_off_rounded, size: 44, color: T.textFaint),
          const SizedBox(height: 12),
          Text(l.pick('ยังไม่มีการแจ้งเตือน', 'No notifications yet'),
              style: AppTheme.body(13.5, color: T.textMuted)),
        ],
      ),
    );
  }

  String _ago(L10n l, DateTime? t) => t == null ? '' : Format.ago(t, thai: l.isTh);

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* best-effort */}
  }
}
