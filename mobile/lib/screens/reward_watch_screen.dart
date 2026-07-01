import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../services/reward_config.dart';
import '../state/app_state.dart';
import '../state/member_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// ดูคลิปรับรางวัล — watch a designated clip for [rewardWatchSeconds] to earn
/// coins. Uses a placeholder sample clip until netwix.online serves real reward
/// creatives (GET /api/rewards/tasks); the watch-time gate is the same.
class RewardWatchScreen extends StatefulWidget {
  const RewardWatchScreen({super.key});

  @override
  State<RewardWatchScreen> createState() => _RewardWatchScreenState();
}

class _RewardWatchScreenState extends State<RewardWatchScreen> {
  // Placeholder reward clip (replaced by netwix reward creatives later).
  static const _clipUrl =
      'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

  VideoPlayerController? _c;
  int _watched = 0;
  int _target = RewardConfig.rewardWatchSeconds;
  bool _reached = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(_clipUrl));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      // If the clip is shorter than the target, watching it fully counts.
      _target = c.value.duration.inSeconds > 0
          ? (RewardConfig.rewardWatchSeconds < c.value.duration.inSeconds
              ? RewardConfig.rewardWatchSeconds
              : c.value.duration.inSeconds - 1)
          : RewardConfig.rewardWatchSeconds;
      c
        ..addListener(_tick)
        ..setLooping(false)
        ..play();
      setState(() => _c = c);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _tick() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final w = c.value.position.inSeconds;
    if (w != _watched) {
      setState(() {
        _watched = w;
        if (_watched >= _target) _reached = true;
      });
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (!_reached || _claimed) return;
    setState(() => _claimed = true);
    final got = await context.read<MemberState>().claimRewardWatch();
    if (!mounted) return;
    final l = context.read<AppState>().l;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(got > 0 ? '+$got ${l.pick('เหรียญ', 'coins')} 🎉' : l.pick('รับครบวันนี้แล้ว', 'Maxed for today'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    final c = _c;
    final progress = _target > 0 ? (_watched / _target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.bi('ดูคลิปรับรางวัล', 'Watch to earn'), style: AppTheme.display(16, weight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: c != null && c.value.isInitialized ? c.value.aspectRatio : 16 / 9,
            child: c != null && c.value.isInitialized
                ? VideoPlayer(c)
                : const Center(child: CircularProgressIndicator(color: T.accent)),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: T.hairlineStrong,
                  valueColor: const AlwaysStoppedAnimation(T.accent),
                ),
              ),
              Text(
                _reached ? '✓' : '${(_target - _watched).clamp(0, _target)}s',
                style: AppTheme.display(_reached ? 30 : 20, weight: FontWeight.w700, color: T.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _reached
                ? l.pick('ดูครบแล้ว รับเหรียญได้เลย', 'Done — claim your coins')
                : l.pick('ดูให้ครบเวลาเพื่อรับ ${RewardConfig.rewardWatchCoins} เหรียญ', 'Watch fully to earn ${RewardConfig.rewardWatchCoins} coins'),
            textAlign: TextAlign.center,
            style: AppTheme.body(13.5, color: T.textSecondary),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
            child: AccentButton(
              label: '${l.pick('รับ', 'Claim')} ${RewardConfig.rewardWatchCoins} ${l.pick('เหรียญ', 'coins')}',
              icon: Icons.monetization_on_rounded,
              enabled: _reached && !_claimed,
              onPressed: _claim,
            ),
          ),
        ],
      ),
    );
  }
}
