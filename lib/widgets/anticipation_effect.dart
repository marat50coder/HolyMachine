import 'dart:math';

import 'package:flutter/material.dart';

/// Pragmatic-style "anticipation" effect painted over a single reel.
///
/// Two bright fire columns pulse on the left and right edges, a halo blooms
/// around the whole reel and a shimmer streak sweeps across it. Used while the
/// final reel is spinning after 2+ scatters have already landed.
class AnticipationEffect extends StatefulWidget {
  const AnticipationEffect({super.key, this.active = true});

  final bool active;

  @override
  State<AnticipationEffect> createState() => _AnticipationEffectState();
}

class _AnticipationEffectState extends State<AnticipationEffect>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _shimmer]),
        builder: (context, _) {
          final pulse = _pulse.value; // 0..1
          final shimmer = _shimmer.value; // 0..1
          return CustomPaint(
            size: Size.infinite,
            painter: _FirePainter(pulse: pulse, shimmer: shimmer),
          );
        },
      ),
    );
  }
}

class _FirePainter extends CustomPainter {
  _FirePainter({required this.pulse, required this.shimmer});

  final double pulse;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // --- Side fire columns ---
    final sideWidth = size.width * (0.14 + 0.04 * pulse);
    final leftRect = Rect.fromLTWH(0, 0, sideWidth, size.height);
    final rightRect = Rect.fromLTWH(
        size.width - sideWidth, 0, sideWidth, size.height);

    final hotColor = Color.lerp(
      const Color(0xFFFFF2C8),
      const Color(0xFFFF4500),
      0.3 + 0.4 * pulse,
    )!;
    final midColor = Color.lerp(
      const Color(0xFFFFB638),
      const Color(0xFFFF7A00),
      pulse,
    )!;

    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [hotColor.withValues(alpha: 0.95), midColor.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(leftRect)
      ..blendMode = BlendMode.plus;
    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [hotColor.withValues(alpha: 0.95), midColor.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(rightRect)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(leftRect, leftPaint);
    canvas.drawRect(rightRect, rightPaint);

    // --- Top & bottom fire caps ---
    final capHeight = size.height * (0.07 + 0.03 * pulse);
    final topRect = Rect.fromLTWH(0, 0, size.width, capHeight);
    final botRect = Rect.fromLTWH(
        0, size.height - capHeight, size.width, capHeight);
    final capPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xDDFFF2C8), Color(0x00000000)],
      ).createShader(topRect)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(topRect, capPaint);
    final capPaint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xDDFFF2C8), Color(0x00000000)],
      ).createShader(botRect)
      ..blendMode = BlendMode.plus;
    canvas.drawRect(botRect, capPaint2);

    // --- Outer glow (soft bloom around the reel) ---
    canvas.drawRect(
      rect.inflate(10),
      Paint()
        ..color = midColor.withValues(alpha: 0.35 + 0.25 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + 12 * pulse)
        ..blendMode = BlendMode.plus,
    );

    // --- Shimmer streaks sweeping top -> bottom ---
    final streakCount = 3;
    for (var i = 0; i < streakCount; i++) {
      final phase = (shimmer + i / streakCount) % 1;
      final y = -size.height * 0.4 + phase * (size.height * 1.6);
      final streakHeight = size.height * 0.22;
      final streakRect = Rect.fromLTWH(0, y, size.width, streakHeight);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00FFFFFF),
            Colors.white.withValues(alpha: 0.18),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(streakRect)
        ..blendMode = BlendMode.plus;
      canvas.drawRect(streakRect, paint);
    }

    // --- Flicker specks for "sparks" feel ---
    final rng = Random((shimmer * 1000).toInt());
    final sparkPaint = Paint()
      ..color = const Color(0xFFFFF2C8)
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < 10; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.6 + rng.nextDouble() * 1.4, sparkPaint);
    }

    // --- Final outer stroke (chrome edge glow) ---
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFF2C8).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _FirePainter old) =>
      old.pulse != pulse || old.shimmer != shimmer;
}
