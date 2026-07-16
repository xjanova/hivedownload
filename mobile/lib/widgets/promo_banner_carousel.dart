import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/notice.dart';
import '../services/netwix_api.dart';
import '../theme/tokens.dart';

/// Admin-controlled promo banner carousel at the top of Home
/// (`GET /api/app/banners`). Auto-advances every 5s, dots indicator, taps open
/// the campaign link. Renders nothing while loading / when admin has no active
/// banner, so Home never shows an empty box.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  List<PromoBanner> _banners = const [];
  final PageController _page = PageController();
  Timer? _auto;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final banners = await context.read<NetwixApi>().fetchBanners();
    if (!mounted) return;
    setState(() => _banners = banners);
    _restartAuto();
  }

  void _restartAuto() {
    _auto?.cancel();
    if (_banners.length < 2) return;
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_page.hasClients) return;
      final next = (_index + 1) % _banners.length;
      _page.animateToPage(next,
          duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  Future<void> _open(PromoBanner b) async {
    final url = b.linkUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 5 / 2,
          child: PageView.builder(
            controller: _page,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final b = _banners[i];
              return GestureDetector(
                onTap: () => _open(b),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(T.rMedia),
                  child: CachedNetworkImage(
                    imageUrl: b.image,
                    fit: BoxFit.cover,
                    memCacheWidth: 1200,
                    placeholder: (_, _) =>
                        DecoratedBox(decoration: BoxDecoration(gradient: T.posterFill(b.id))),
                    errorWidget: (_, _, _) =>
                        DecoratedBox(decoration: BoxDecoration(gradient: T.posterFill(b.id))),
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: i == _index ? T.accentGradient : null,
                    color: i == _index ? null : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
