import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Pragmatic-style "Big Win" overlay with staged labels (NICE / BIG WIN /
/// SENSATION / MEGA WIN) and a counter that races up to the final amount.
///
/// Trigger thresholds (multiplier of total bet):
///   >= 15x  : NICE WIN
///   >= 30x  : BIG WIN
///   >= 60x  : SENSATION
///   >= 120x : MEGA WIN
class BigWinOverlay extends StatefulWidget {
  const BigWinOverlay({
    super.key,
    required this.amount,
    required this.multiplier,
    required this.currency,
    required this.onDone,
  });

  final double amount;
  final double multiplier;
  final String currency;
  final VoidCallback onDone;

  @override
  State<BigWinOverlay> createState() => _BigWinOverlayState();
}

class _BigWinOverlayState extends State<BigWinOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _counter;
  late final AnimationController _labelScale;
  int _stage = 0;
  final List<_Stage> _stages = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _stages.add(const _Stage('NICE WIN!', Color(0xFFFFD17A)));
    if (widget.multiplier >= 30) {
      _stages.add(const _Stage('BIG WIN!', Color(0xFFFFB638)));
    }
    if (widget.multiplier >= 60) {
      _stages.add(const _Stage('SENSATION!', Color(0xFFFF7A00)));
    }
    if (widget.multiplier >= 120) {
      _stages.add(const _Stage('MEGA WIN!!!', Color(0xFFFF4500)));
    }

    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    // Counter duration scales with number of stages.
    _counter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1600 + _stages.length * 900),
    );
    _counter.addListener(() => setState(() {}));

    _labelScale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _runSequence();
  }

  Future<void> _runSequence() async {
    _counter.forward();
    final stageDuration =
        Duration(milliseconds: (_counter.duration!.inMilliseconds /
                _stages.length)
            .round());
    for (var i = 0; i < _stages.length; i++) {
      if (!mounted || _finished) return;
      _stage = i;
      _labelScale
        ..reset()
        ..forward();
      setState(() {});
      await Future<void>.delayed(stageDuration);
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || _finished) return;
    await _finish();
  }

  Future<void> _finish() async {
    if (_finished || !mounted) return;
    _finished = true;
    try {
      await _fade.reverse();
    } catch (_) {
      // Controller may have been disposed if the overlay was removed.
    }
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _fade.dispose();
    _counter.dispose();
    _labelScale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _stages[_stage];
    final animatedAmount = widget.amount * _counter.value;
    final labelT = Curves.elasticOut.transform(_labelScale.value);
    // Wrap in a Material so Text widgets inherit the default style and the
    // debug "no DefaultTextStyle" yellow underline doesn't show up.
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFFFF2C8),
          decoration: TextDecoration.none,
        ),
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: () async {
              if (_finished || !mounted) return;
              _counter.value = 1.0;
              _stage = _stages.length - 1;
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 200));
              if (!mounted) return;
              await _finish();
            },
            child: Stack(
          fit: StackFit.expand,
          children: [
            // Vignette / dark backdrop.
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xDD1a0e07), Color(0xFF000000)],
                  radius: 1.2,
                ),
              ),
            ),
            // Decorative rotating rays.
            Center(
              child: _Rays(controller: _counter),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: 0.4 + 0.6 * labelT,
                    child: _GlowLabel(
                      text: current.label,
                      color: current.color,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _AmountDisplay(
                    amount: animatedAmount,
                    currency: widget.currency,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${widget.multiplier.toStringAsFixed(1)}× TOTAL BET',
                    style: const TextStyle(
                      color: Color(0xFFFFD17A),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  const Text(
                    'TAP TO SKIP',
                    style: TextStyle(
                      color: Color(0x99FFD17A),
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _Stage {
  const _Stage(this.label, this.color);
  final String label;
  final Color color;
}

class _GlowLabel extends StatelessWidget {
  const _GlowLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        color: color,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.9), blurRadius: 35),
          const Shadow(color: Colors.black, blurRadius: 2, offset: Offset(2, 2)),
        ],
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount, required this.currency});
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2a1507), Color(0xFF4a2510)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFFFFB638), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x99FF8A1A), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFF2C8),
              letterSpacing: 2,
              shadows: [
                Shadow(color: Color(0xFFFF8A1A), blurRadius: 18),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currency,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFD17A),
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rays extends StatelessWidget {
  const _Rays({required this.controller});
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Transform.rotate(
          angle: controller.value * 2 * pi,
          child: CustomPaint(
            size: const Size.square(900),
            painter: _RaysPainter(),
          ),
        );
      },
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x33FF8A1A),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width));
    canvas.drawCircle(center, size.width / 2, paint);
    final rayPaint = Paint()
      ..color = const Color(0x22FFB638)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 24; i++) {
      final angle = i * pi / 12;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(angle - 0.03) * size.width,
            center.dy + sin(angle - 0.03) * size.width)
        ..lineTo(center.dx + cos(angle + 0.03) * size.width,
            center.dy + sin(angle + 0.03) * size.width)
        ..close();
      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
