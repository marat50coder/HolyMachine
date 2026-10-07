import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _dotsTimer;
  int _dotsCount = 0;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    // Progress animates smoothly to ~85% then jumps to 100% just before launch.
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _dotsCount = (_dotsCount + 1) % 4;
      });
    });

    _runLoadingSequence();
    // If the animation ticker never starts, still leave this screen.
    Future<void>.delayed(const Duration(seconds: 4), _openMenu);
  }

  Future<void> _runLoadingSequence() async {
    try {
      await _progressController.animateTo(0.85, curve: Curves.easeOutCubic);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _progressController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutQuad,
      );
    } catch (e) {
      debugPrint('loading animation failed: $e');
    }
    // Never wait on SystemChrome here. On some Android builds
    // setPreferredOrientations never returns and the app stays on this screen.
    _openMenu();
  }

  void _openMenu() {
    if (_opened || !mounted) return;
    _opened = true;
    // Fire-and-forget. A hung platform call must not block navigation.
    unawaited(_lockPortrait());
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _lockPortrait() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('setPreferredOrientations failed: $e');
    }
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    final asset = isLandscape
        ? 'assets/Holy_Machine_additional_assets/Horizontal_Loading_Screen.webp'
        : 'assets/Holy_Machine_additional_assets/Vertical_Loading_Screen.webp';

    return Scaffold(
      backgroundColor: const Color(0xFF0a0604),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fallback gradient — guarantees that even if the image fails to
          // decode (reported on some Impeller/Vulkan devices) the screen is
          // not just white/black.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF3a1a07), Color(0xFF0a0604)],
                radius: 1.2,
              ),
            ),
          ),
          Image.asset(
            asset,
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, e, s) {
              debugPrint('Loading image failed: $e');
              return const SizedBox.shrink();
            },
          ),
          // Subtle darkening at the bottom so the progress bar reads well.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB3000000)],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 32,
                  right: 32,
                  bottom: isLandscape ? 24 : 56,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingLabel(dotsCount: _dotsCount),
                    const SizedBox(height: 14),
                    _ProgressBar(progress: _progressController.value),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  const _LoadingLabel({required this.dotsCount});
  final int dotsCount;

  @override
  Widget build(BuildContext context) {
    final dots = '.' * dotsCount;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
          color: Color(0xFFFFD17A),
          shadows: [
            Shadow(blurRadius: 12, color: Color(0xFFFF7A00)),
            Shadow(blurRadius: 2, color: Colors.black),
          ],
        ),
        children: [
          const TextSpan(text: 'LOADING'),
          TextSpan(
            text: dots.padRight(3),
            style: const TextStyle(
              color: Color(0xFFFFB638),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const barHeight = 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: barHeight,
              child: Stack(
                children: [
                  // Track
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xE6050505),
                      borderRadius: BorderRadius.circular(barHeight),
                      border: Border.all(
                        color: const Color(0xFF8A5A14),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  // Fill (left to right)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: c.maxWidth * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD17A),
                            Color(0xFFFFB638),
                            Color(0xFFFF7A00),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(barHeight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xAAFF8A1A),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Percentage text
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(blurRadius: 2, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
