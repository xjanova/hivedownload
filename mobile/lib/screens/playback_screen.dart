import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/l10n.dart';
import '../models/series.dart';
import '../services/catalog_db.dart';
import '../services/format.dart';
import '../services/rongyok_client.dart';
import '../state/app_state.dart';
import '../state/member_state.dart';
import '../widgets/unlock_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/ad_banner.dart';

/// 08 — Series Playback · เล่นซีรีส์.
///
/// Full-screen, immersive, **TikTok-style vertical feed**: one episode per page,
/// swipe up = next episode, swipe down = previous. Adjacent episodes are
/// pre-resolved + pre-initialised so swiping plays instantly. Only the current
/// page has audio/plays; neighbours stay paused & ready. Keeps resume (seek +
/// checkpoint), the 12h video-URL cache, and the free-user ad overlay.
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
  late final PageController _pageController;
  late int _current;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _loading = {};
  final Set<int> _failed = {};
  final Set<int> _retried = {}; // one fresh-URL retry per episode
  final Map<int, String> _errMsg = {}; // shown on the failed page for diagnosis

  RongYokClient? _client;
  CatalogDb? _db;
  MemberState? _member;
  bool _isPro = false;

  DateTime _lastResumeSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _advancing = false;

  Series get s => widget.series;
  List<int> get eps => widget.episodes;

  @override
  void initState() {
    super.initState();
    _current = eps.indexOf(widget.startEpisode).clamp(0, eps.length - 1);
    _pageController = PageController(initialPage: _current);
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client == null) {
      _client = context.read<RongYokClient>();
      _db = context.read<CatalogDb>();
      _member = context.read<MemberState>();
      _isPro = context.read<AppState>().isPro;
      // kick off current + neighbours
      _ensure(_current);
      _ensure(_current + 1);
      _ensure(_current - 1);
    }
  }

  @override
  void dispose() {
    _saveResume(_current);
    for (final c in _controllers.values) {
      c.removeListener(_onTick);
      c.dispose();
    }
    _pageController.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ------------------------------------------------------- controller window

  Future<String?> _resolveUrl(int ep) async {
    final db = _db!;
    final cached = await db.freshVideoUrl(s.id, ep);
    if (cached != null) return cached;
    final url = await _client!.getVideoUrl(s.id, ep);
    if (url != null) unawaited(db.cacheVideoUrl(s.id, ep, url));
    return url;
  }

  bool _locked(int index) {
    if (index < 0 || index >= eps.length) return false;
    final m = _member;
    if (m == null) return false;
    return !m.isEpisodeUnlocked(s.id, eps, eps[index], isPro: _isPro);
  }

  Future<void> _unlockAt(int index) async {
    final ok = await showUnlockSheet(context, seriesId: s.id, episode: eps[index]);
    if (!ok || !mounted) return;
    setState(() {});
    await _ensure(index);
    if (index == _current) {
      final c = _controllers[index];
      c
        ?..addListener(_onTick)
        ..play();
    }
  }

  Future<void> _ensure(int index) async {
    if (index < 0 || index >= eps.length) return;
    if (_locked(index)) return; // don't stream a locked episode
    if (_controllers.containsKey(index) || _loading.contains(index)) return;
    _loading.add(index);
    _failed.remove(index);

    final ep = eps[index];
    try {
      final url = await _resolveUrl(ep);
      if (!mounted) return;
      if (url == null) {
        _loading.remove(index);
        _errMsg[index] = 'get_video ไม่คืนลิงก์ (series ${s.id} ep $ep)';
        _failed.add(index);
        if (mounted) setState(() {});
        return;
      }
      // No custom httpHeaders: the CDN serves the MP4 to any User-Agent, and
      // passing a UA to ExoPlayer was causing "Source error" on release builds.
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(false);
      final resume = await _db!.getResume(s.id, ep);
      if (resume != null && resume > 5 && resume < c.value.duration.inSeconds - 10) {
        await c.seekTo(Duration(seconds: resume));
      }
      _controllers[index] = c;
      _loading.remove(index);
      if (index == _current) {
        c.addListener(_onTick);
        await c.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      _loading.remove(index);
      // A cached URL may have expired/died — drop it and re-resolve once.
      if (!_retried.contains(index)) {
        _retried.add(index);
        await _db?.invalidateVideoUrl(s.id, eps[index]);
        if (mounted) {
          await _ensure(index);
          return;
        }
      }
      _errMsg[index] = e.toString();
      _failed.add(index);
      if (mounted) setState(() {});
    }
  }

  void _disposeFarFrom(int center) {
    final far = _controllers.keys.where((i) => (i - center).abs() > 1).toList();
    for (final i in far) {
      _saveResume(i);
      final c = _controllers.remove(i);
      c?.removeListener(_onTick);
      c?.dispose();
    }
  }

  void _onPageChanged(int index) {
    // leaving page: pause + remember
    final prev = _controllers[_current];
    if (prev != null) {
      prev.removeListener(_onTick);
      prev.pause();
      _saveResume(_current);
    }
    _current = index;
    _advancing = false;

    final cur = _controllers[index];
    if (cur != null) {
      cur.addListener(_onTick);
      cur.seekTo(cur.value.position); // nudge so the listener fires
      cur.play();
    } else {
      _ensure(index);
    }
    _ensure(index + 1);
    _ensure(index - 1);
    _disposeFarFrom(index);
    setState(() {});
  }

  void _onTick() {
    final c = _controllers[_current];
    if (c == null || !c.value.isInitialized) return;

    final now = DateTime.now();
    if (c.value.isPlaying && now.difference(_lastResumeSave).inSeconds >= 5) {
      _lastResumeSave = now;
      _saveResume(_current);
    }

    // autoplay-next → swipe to the next episode
    if (!_advancing &&
        c.value.duration > Duration.zero &&
        c.value.position >= c.value.duration &&
        !c.value.isPlaying &&
        _current < eps.length - 1) {
      _advancing = true;
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
    if (mounted) setState(() {});
  }

  void _saveResume(int index) {
    final c = _controllers[index];
    if (c == null || !c.value.isInitialized) return;
    _db?.saveResume(
        s.id, eps[index], c.value.position.inSeconds, c.value.duration.inSeconds);
  }

  void _togglePlay() {
    final c = _controllers[_current];
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  void _openEpisodeSheet() {
    final l = context.read<AppState>().l;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: T.screen,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.bi('ตอนทั้งหมด', 'Episodes'),
                  style: AppTheme.display(16, weight: FontWeight.w700)),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.4),
                itemCount: eps.length,
                itemBuilder: (_, i) {
                  final active = i == _current;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _pageController.jumpToPage(i);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: active ? T.accentGradient : null,
                        color: active ? null : const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? Colors.transparent : T.hairline),
                      ),
                      child: Text('${eps[i]}',
                          style: AppTheme.display(14,
                              weight: FontWeight.w700,
                              color: active ? T.onAccent : T.textSecondary)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    _isPro = context.watch<AppState>().isPro;
    context.watch<MemberState>(); // rebuild lock overlays after unlock/login
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: eps.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, index) => _EpisodePage(
              controller: _controllers[index],
              failed: _failed.contains(index),
              errorText: _errMsg[index],
              locked: _locked(index),
              episode: eps[index],
              unlockCost: _member?.unlockCost ?? 5,
              onUnlock: () => _unlockAt(index),
              onTapVideo: index == _current ? _togglePlay : null,
              onRetry: () => _ensure(index),
              l: l,
            ),
          ),
          // top bar (back + title)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    _circleBtn(Icons.arrow_back_rounded, () => Navigator.of(context).pop()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.cleanTitle.isEmpty ? s.title : s.cleanTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(15,
                                  weight: FontWeight.w700, color: Colors.white)),
                          Text('${l.pick('ตอนที่', 'EP')} ${eps[_current]} · ${_current + 1}/${eps.length}',
                              style: AppTheme.body(11.5, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // right action rail (episodes list)
          Positioned(
            right: 10,
            bottom: 130,
            child: Column(
              children: [
                _railBtn(Icons.grid_view_rounded, l.pick('ตอน', 'Eps'), _openEpisodeSheet),
                const SizedBox(height: 18),
                _railBtn(
                  _controllers[_current]?.value.isPlaying ?? false
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  '',
                  _togglePlay,
                ),
              ],
            ),
          ),
          // bottom: ad (free users) + scrubber
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AdBanner(placement: 'player', height: 56),
                  _scrubber(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrubber() {
    final c = _controllers[_current];
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(height: 24);
    }
    final pos = c.value.position;
    final dur = c.value.duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(
        children: [
          Text(Format.duration(pos.inSeconds),
              style: AppTheme.body(10.5, color: Colors.white70)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.5,
                activeTrackColor: T.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: T.accentHi,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
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
          Text(Format.duration(dur.inSeconds),
              style: AppTheme.body(10.5, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _railBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Color(0x33000000), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label, style: AppTheme.body(10, color: Colors.white70)),
            ],
          ],
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Color(0x55000000), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

/// One full-screen page in the vertical feed.
class _EpisodePage extends StatelessWidget {
  const _EpisodePage({
    required this.controller,
    required this.failed,
    required this.errorText,
    required this.locked,
    required this.episode,
    required this.unlockCost,
    required this.onUnlock,
    required this.onTapVideo,
    required this.onRetry,
    required this.l,
  });

  final VideoPlayerController? controller;
  final bool failed;
  final String? errorText;
  final bool locked;
  final int episode;
  final int unlockCost;
  final VoidCallback onUnlock;
  final VoidCallback? onTapVideo;
  final VoidCallback onRetry;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (locked) {
      return SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF0B0B0C)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: T.accent, size: 56),
                const SizedBox(height: 14),
                Text('${l.pick('ตอนที่', 'EP')} $episode ${l.pick('ถูกล็อก', 'locked')}',
                    style: AppTheme.display(18, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(l.pick('ดูฟรี 3 ตอนแรก · ตอนถัดไปใช้เหรียญ', 'First 3 free · unlock with coins'),
                    style: AppTheme.body(12.5, color: Colors.white70)),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: onUnlock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                        gradient: T.accentGradient, borderRadius: BorderRadius.circular(T.rButton)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_open_rounded, color: T.onAccent, size: 18),
                      const SizedBox(width: 8),
                      Text('${l.pick('ปลดล็อก', 'Unlock')} · $unlockCost ${l.pick('เหรียญ', 'coins')}',
                          style: AppTheme.display(14, weight: FontWeight.w700, color: T.onAccent)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTapVideo,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c != null && c.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            else if (failed)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.pick('เล่นวิดีโอไม่สำเร็จ', 'Playback failed'),
                          style: AppTheme.body(14, weight: FontWeight.w600, color: Colors.white)),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(errorText!,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(11, color: Colors.white54)),
                      ],
                      TextButton(
                        onPressed: onRetry,
                        child: Text(l.pick('ลองใหม่', 'Retry'),
                            style: AppTheme.body(13, color: T.accent)),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: T.accent)),

            // paused indicator (only for the active, tappable page)
            if (onTapVideo != null && c != null && c.value.isInitialized && !c.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 74),
              ),
          ],
        ),
      ),
    );
  }
}
