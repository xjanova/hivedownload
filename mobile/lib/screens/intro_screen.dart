import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'app_shell.dart';
import 'onboarding_screen.dart';

/// NetWix brand intro — plays `logomedia3.mp4` once on cold start, then routes
/// to the app (or onboarding). Tap to skip; a hard timeout guarantees we never
/// get stuck if the clip fails to load.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    // Never let the splash outlast this, even if the asset stalls.
    _failsafe = Timer(const Duration(seconds: 7), _finish);
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.asset('assets/video/logomedia3.mp4');
      _controller = c;
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_watch);
      await c.setVolume(1);
      await c.play();
      setState(() {});
    } catch (_) {
      _finish();
    }
  }

  void _watch() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    if (d > Duration.zero && c.value.position >= d - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final onboarded = context.read<AppState>().onboarded;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => onboarded ? const AppShell() : const OnboardingScreen(),
    ));
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _controller?.removeListener(_watch);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return GestureDetector(
      onTap: _finish,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(color: Colors.black),
                child: Center(child: CircularProgressIndicator(color: T.accent)),
              ),
          ],
        ),
      ),
    );
  }
}
