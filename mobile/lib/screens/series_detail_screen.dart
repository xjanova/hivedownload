import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/series.dart';
import '../services/rongyok_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/poster_image.dart';
import 'playback_screen.dart';

/// 03 — Content Preview / Series Detail · รายละเอียด. Stream-only: pick a title,
/// browse episodes, tap to watch. Everything is free.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});
  final Series series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<int> _episodes = [];
  bool _loading = true;
  String? _error;

  Series get s => widget.series;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nums = await context.read<RongYokClient>().fetchEpisodeNumbers(s.id);
      if (!mounted) return;
      setState(() {
        _episodes = nums;
        s.episodesCount = nums.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดรายชื่อตอนไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  void _play(int ep) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaybackScreen(series: s, episodes: _episodes, startEpisode: ep),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;

    return Scaffold(
      body: DecoratedBox(
        decoration: T.screenBackground,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(l)),
            SliverToBoxAdapter(child: _meta(l)),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: T.accent)),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(child: _errorRow(l))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: SectionHeader(
                    title: l.bi('ตอนทั้งหมด', 'Episodes'),
                    trailing: '${_episodes.length} ${l.pick('ตอน', 'eps')}',
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: _episodes.length,
                itemBuilder: (_, i) => _episodeRow(l, _episodes[i]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _loading || _episodes.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: AccentButton(
                label: l.bi('เล่นตอนที่ 1', 'Play EP1'),
                icon: Icons.play_arrow_rounded,
                height: 54,
                onPressed: () => _play(_episodes.first),
              ),
            ),
    );
  }

  Widget _hero(L10n l) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PosterImage(url: s.displayImageUrl, seed: s.id, radius: 0),
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x660D0B08), Color(0xE614110B)],
                  ),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: _episodes.isEmpty ? null : () => _play(_episodes.first),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: T.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: T.accentGlow, blurRadius: 24, spreadRadius: -4)],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: T.onAccent, size: 32),
                  ),
                ),
              ),
              Positioned(left: 12, top: 4, child: Pill(text: l.pick('ดูฟรี', 'FREE'), filled: true)),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
          ),
        ),
      ],
    );
  }

  Widget _meta(L10n l) {
    final metaText = [
      if (s.yearText.isNotEmpty) s.yearText,
      s.typeThai,
      if (_episodes.isNotEmpty) '${_episodes.length} ${l.pick('ตอน', 'eps')}',
      'HD · ${l.pick('สตรีม', 'Stream')}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.cleanTitle.isEmpty ? s.title : s.cleanTitle,
              style: AppTheme.display(23, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(metaText, style: AppTheme.body(12.5, color: T.textMuted)),
          if (s.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.description, style: AppTheme.body(13.5, color: T.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _episodeRow(L10n l, int ep) {
    return InkWell(
      onTap: () => _play(ep),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(url: s.displayImageUrl, seed: s.id + ep, radius: 8),
                    const Center(child: Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l.pick('ตอนที่', 'EP')} $ep',
                      style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
                  Text(l.pick('ดูฟรี', 'Free'), style: AppTheme.body(11.5, color: T.textFaint)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline_rounded, color: T.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _errorRow(L10n l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 18),
        child: Column(
          children: [
            Text(_error ?? '', style: AppTheme.body(13, color: T.textMuted)),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: AccentButton(label: l.pick('ลองใหม่', 'Retry'), height: 44, onPressed: _loadEpisodes),
            ),
          ],
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Color(0x800D0B08), shape: BoxShape.circle),
          child: Icon(icon, color: T.textPrimary, size: 20),
        ),
      );
}
