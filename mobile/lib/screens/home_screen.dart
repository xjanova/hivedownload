import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../state/catalog_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/poster_card.dart';

/// 02 — Home / Discover · หน้าแรก.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenExplore});
  final VoidCallback? onOpenExplore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CatalogState>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    final catalog = context.watch<CatalogState>();

    return RefreshIndicator(
      color: T.accent,
      backgroundColor: T.screen,
      onRefresh: () => catalog.load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _greeting(l),
          const SizedBox(height: 16),
          _searchField(l),
          const SizedBox(height: 16),
          _chips(catalog),
          const SizedBox(height: 20),
          if (catalog.loading && catalog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: T.accent)),
            )
          else if (catalog.error != null && catalog.isEmpty)
            _errorBox(l, catalog)
          else ...[
            SectionHeader(
              title: l.bi('แนวตั้ง', 'Vertical'),
              badge: const Pill(text: 'ดูฟรี', filled: true),
              trailing: l.pick('ทั้งหมด ›', 'See all ›'),
              onTrailingTap: widget.onOpenExplore,
            ),
            SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: catalog.visible.length.clamp(0, 15),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => PortraitPosterCard(series: catalog.visible[i]),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: l.bi('ยอดนิยม', 'Popular'),
              trailing: l.pick('ทั้งหมด ›', 'See all ›'),
              onTrailingTap: widget.onOpenExplore,
            ),
            if (catalog.featured.isNotEmpty) FeaturedCard(series: catalog.featured.first),
            const SizedBox(height: 16),
            for (final s in catalog.featured.skip(1).take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeaturedCard(series: s),
              ),
          ],
        ],
      ),
    );
  }

  Widget _greeting(L10n l) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.bi('สวัสดี', 'Hello'), style: AppTheme.body(12, color: T.textMuted)),
              Text(l.pick('ยินดีต้อนรับ 🐝', 'Welcome 🐝'),
                  style: AppTheme.display(20, weight: FontWeight.w700)),
            ],
          ),
        ),
        const HexAvatar(size: 44, child: Icon(Icons.person, color: T.accentHi, size: 20)),
      ],
    );
  }

  Widget _searchField(L10n l) {
    return GestureDetector(
      onTap: widget.onOpenExplore,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: T.hairline),
        ),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: T.textMuted),
          const SizedBox(width: 10),
          Text(l.bi('ค้นหาซีรีส์ หนัง', 'Search series, movies…'),
              style: AppTheme.body(13.5, color: T.textMuted)),
        ]),
      ),
    );
  }

  Widget _chips(CatalogState catalog) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in CatalogFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(catalog, f),
            ),
        ],
      ),
    );
  }

  Widget _chip(CatalogState catalog, CatalogFilter f) {
    final active = catalog.filter == f;
    final label = context.read<AppState>().l.isTh ? f.th : f.en;
    return GestureDetector(
      onTap: () => catalog.setFilter(f),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: active ? T.accentGradient : null,
          color: active ? null : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: active ? Colors.transparent : T.hairline),
        ),
        child: Text(label,
            style: AppTheme.body(12.5,
                weight: FontWeight.w600, color: active ? T.onAccent : T.textSecondary)),
      ),
    );
  }

  Widget _errorBox(L10n l, CatalogState catalog) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: T.textFaint),
          const SizedBox(height: 12),
          Text(catalog.error ?? '', textAlign: TextAlign.center, style: AppTheme.body(13, color: T.textMuted)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: AccentButton(
              label: l.pick('ลองใหม่', 'Retry'),
              height: 46,
              onPressed: () => catalog.load(force: true),
            ),
          ),
        ],
      ),
    );
  }
}
