import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/l10n.dart';
import '../models/series.dart';
import '../services/format.dart';
import '../services/rongyok_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/ad_banner.dart';

/// 08 — Series Playback · เล่นซีรีส์. Streaming-only: resolves a fresh CDN MP4
/// per episode and plays it with custom transport + an episode list.
/// Free users see a rotating ad banner; Pro (129฿/mo) removes it.
class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({
    super.key,
    required this.series,
    required this.episodes,
    required this.startEpisode,
  });

  final Series series;
  final List<int> episodes;
  final int startEpisode;

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  VideoPlayerController? _controller;
  late int _ep;
  bool _loading = true;
  String? _error;
  bool _controlsVisible = true;

  Series get s => widget.series;

  @override
  void initState() {
    super.initState();
    _ep = widget.startEpisode;
    WakelockPlus.enable();
    _load(_ep);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _load(int ep) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Read the provider BEFORE any await so we never touch context across a gap.
    final client = context.read<RongYokClient>();

    _controller?.removeListener(_onTick);
    await _controller?.dispose();
    _controller = null;

    try {
      final url = await client.getVideoUrl(s.id, ep);
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _error = 'ไม่พบลิงก์วิดีโอ (อาจหมดอายุ) ลองใหม่อีกครั้ง';
          _loading = false;
        });
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: RongYokClient.mediaHeaders,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller
        ..addListener(_onTick)
        ..setLooping(false)
        ..play();
      setState(() {
        _controller = controller;
        _ep = ep;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'เล่นวิดีโอไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isInitialized &&
        c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero &&
        !c.value.isPlaying) {
      _next();
    }
    if (mounted) setState(() {});
  }

  int get _epIndex => widget.episodes.indexOf(_ep);
  bool get _hasPrev => _epIndex > 0;
  bool get _hasNext => _epIndex >= 0 && _epIndex < widget.episodes.length - 1;

  void _prev() {
    if (_hasPrev) _load(widget.episodes[_epIndex - 1]);
  }

  void _next() {
    if (_hasNext) _load(widget.episodes[_epIndex + 1]);
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _player(l),
          const AdBanner(placement: 'player'),
          Expanded(child: _details(l)),
        ],
      ),
    );
  }

  Widget _player(L10n l) {
    final c = _controller;
    return GestureDetector(
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Container(
        color: Colors.black,
        height: MediaQuery.of(context).size.height * 0.34,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
              ),
            if (_loading) const Center(child: CircularProgressIndicator(color: T.accent)),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: AppTheme.body(13, color: T.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _load(_ep),
                        child: Text(l.pick('ลองใหม่', 'Retry'), style: AppTheme.body(13, color: T.accent)),
                      ),
                    ],
                  ),
                ),
              ),
            if (_controlsVisible && _error == null) _controls(c),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(VideoPlayerController? c) {
    final playing = c?.value.isPlaying ?? false;
    return Container(
      color: const Color(0x33000000),
      child: Column(
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleBtn(Icons.skip_previous_rounded, _hasPrev ? _prev : null, size: 44),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: T.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: T.accentGlow, blurRadius: 22, spreadRadius: -4)],
                  ),
                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: T.onAccent, size: 32),
                ),
              ),
              const SizedBox(width: 24),
              _circleBtn(Icons.skip_next_rounded, _hasNext ? _next : null, size: 44),
            ],
          ),
          const Spacer(),
          if (c != null && c.value.isInitialized) _scrubber(c),
        ],
      ),
    );
  }

  Widget _scrubber(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Text(Format.duration(pos.inSeconds), style: AppTheme.body(11, color: Colors.white70)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: T.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: T.accentHi,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: dur.inMilliseconds == 0
                    ? 0
                    : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
                onChanged: (v) => c.seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          Text(Format.duration(dur.inSeconds), style: AppTheme.body(11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _details(L10n l) {
    return DecoratedBox(
      decoration: T.screenBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Text(s.cleanTitle.isEmpty ? s.title : s.cleanTitle,
              style: AppTheme.display(20, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${l.pick('ตอนที่', 'EP')} $_ep  ·  ${s.typeThai}  ·  ${widget.episodes.length} ${l.pick('ตอน', 'eps')}',
              style: AppTheme.body(12.5, color: T.accent)),
          const SizedBox(height: 16),
          Text(l.bi('ตอนทั้งหมด', 'Episodes'), style: AppTheme.display(16, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final ep in widget.episodes) _epRow(l, ep),
        ],
      ),
    );
  }

  Widget _epRow(L10n l, int ep) {
    final current = ep == _ep;
    return InkWell(
      onTap: () => _load(ep),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: current ? T.accentSoft : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: current ? T.accentGlow : T.hairline),
        ),
        child: Row(
          children: [
            Text('$ep',
                style: AppTheme.display(15, weight: FontWeight.w700, color: current ? T.accent : T.textSecondary)),
            const SizedBox(width: 14),
            Expanded(
              child: Text('${l.pick('ตอนที่', 'Episode')} $ep',
                  style: AppTheme.body(13.5, weight: FontWeight.w500, color: T.textPrimary)),
            ),
            if (current)
              Text(l.pick('กำลังเล่น', 'Now playing'), style: AppTheme.body(11, color: T.accent)),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback? onTap, {double size = 38}) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      );
}
