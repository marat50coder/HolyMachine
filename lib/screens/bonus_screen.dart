import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/slot_config.dart';
import '../game/slot_engine.dart';
import '../widgets/reel.dart';

/// Free-spin bonus screen. Returns the total win amount via Navigator.pop.
///
/// Rules (per spec):
///   - 3/4/5 scatters → 5/8/12 free spins.
///   - Each spin's visible WILDs are collected into a counter.
///   - Final spin: the collected wild counter is "sprinkled" randomly onto the
///     grid, replacing non-wild/non-bonus cells, then payouts are evaluated.
class BonusScreen extends StatefulWidget {
  const BonusScreen({
    super.key,
    required this.scatterCount,
    required this.betPerLine,
  });

  final int scatterCount;
  final double betPerLine;

  @override
  State<BonusScreen> createState() => _BonusScreenState();
}

class _BonusScreenState extends State<BonusScreen>
    with TickerProviderStateMixin {
  final SlotEngine _engine = SlotEngine();
  final List<GlobalKey<ReelState>> _reelKeys =
      List.generate(SlotConfig.reelCount, (_) => GlobalKey<ReelState>());

  int _totalSpins = 0;
  int _spinsRemaining = 0;
  int _spinIndex = 0;
  int _wildsCollected = 0;
  int _retriggers = 0;
  double _totalBonusWin = 0;
  bool _running = false;
  bool _introDone = false;
  bool _finalSprinkle = false;
  bool _showRetrigger = false;
  List<List<SlotSymbol>>? _lastGrid;

  @override
  void initState() {
    super.initState();
    _totalSpins = SlotEngine.freeSpinsForScatters(widget.scatterCount);
    _spinsRemaining = _totalSpins;
    WidgetsBinding.instance.addPostFrameCallback((_) => _playIntro());
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _playIntro() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      _safeSetState(() => _introDone = true);
      await _runBonus();
    } catch (e, s) {
      debugPrint('Bonus screen crashed: $e\n$s');
      if (mounted) Navigator.of(context).pop(_totalBonusWin);
    }
  }

  Future<void> _runBonus() async {
    if (_running) return;
    _running = true;
    while (_spinsRemaining > 0) {
      if (!mounted) return;
      _spinIndex += 1;
      _safeSetState(() {});
      // Short pre-spin pause (was 350).
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final isFinal = _spinsRemaining == 1;
      await _spin(isFinal: isFinal);
      _spinsRemaining -= 1;
      _safeSetState(() {});
      if (!mounted) return;
      // Short post-spin pause (was 500).
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pop(_totalBonusWin);
  }

  Future<void> _spin({required bool isFinal}) async {
    SpinResult result;
    if (isFinal) {
      // Final spin: fresh roll on the bonus strips, then sprinkle every wild
      // the player collected during the free spins on top of that result.
      final base = _engine.spinGrid(useBonusStrips: true);
      await _animateSpin(base);
      if (!mounted) return;
      _safeSetState(() => _finalSprinkle = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final grid = base.map((c) => List<SlotSymbol>.from(c)).toList();
      final candidates = <(int, int)>[];
      for (var r = 0; r < grid.length; r++) {
        for (var row = 0; row < grid[r].length; row++) {
          final s = grid[r][row];
          if (s != SlotSymbol.wild && s != SlotSymbol.bonus) {
            candidates.add((r, row));
          }
        }
      }
      final rng = Random();
      candidates.shuffle(rng);
      final n = _wildsCollected.clamp(0, candidates.length);
      for (var k = 0; k < n; k++) {
        if (!mounted) return;
        final (reel, row) = candidates[k];
        grid[reel][row] = SlotSymbol.wild;
        _reelKeys[reel].currentState?.setStaticVisible(grid[reel]);
        await Future<void>.delayed(const Duration(milliseconds: 85));
      }
      result = _engine.evaluate(grid: grid, betPerLine: widget.betPerLine);
      _safeSetState(() => _finalSprinkle = false);
    } else {
      // Use the low-scatter bonus strips so retriggers happen roughly as
      // rarely as the base-game trigger (independent of test weights).
      result = _engine.spin(
        betPerLine: widget.betPerLine,
        useBonusStrips: true,
      );
      await _animateSpin(result.grid);
    }
    if (!mounted) return;

    _safeSetState(() {
      _lastGrid = result.grid;
      _wildsCollected += isFinal ? 0 : result.wildCount;
      _totalBonusWin += result.totalWin;
    });

    // RETRIGGER: 3+ scatters inside the bonus award extra free spins (same
    // table as the base game trigger). Final spin cannot retrigger because
    // the sprinkle grid never contains BONUS symbols.
    if (!isFinal && result.scatterCount >= 3) {
      final extra = SlotEngine.freeSpinsForScatters(result.scatterCount);
      _retriggers += 1;
      _totalSpins += extra;
      _spinsRemaining += extra;
      _safeSetState(() {
        _showRetrigger = true;
      });
      await _playRetriggerBanner(extra);
      if (!mounted) return;
      _safeSetState(() => _showRetrigger = false);
    }

    if (result.totalWin > 0) {
      _highlightWins(result);
      // Shorter win hold so bonus doesn't drag (was 900).
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _clearHighlights();
    }
  }

  Future<void> _playRetriggerBanner(int extra) async {
    // Flash the banner for ~1.6s so the player clearly sees "+N FREE SPINS".
    debugPrint('Retrigger: +$extra free spins');
    await Future<void>.delayed(const Duration(milliseconds: 1600));
  }

  Future<void> _animateSpin(List<List<SlotSymbol>> grid) async {
    for (final k in _reelKeys) {
      k.currentState?.startSpin();
    }
    final start = DateTime.now();
    final futures = <Future<void>>[];
    // Fast bonus spin: ~250ms baseline + 90ms stagger per reel so the whole
    // thing lands in ~610ms (vs ~1330ms before).
    for (var i = 0; i < SlotConfig.reelCount; i++) {
      final stopAt = start.add(Duration(milliseconds: 250 + i * 90));
      futures.add(_reelKeys[i].currentState!.stopOn(
            symbols: grid[i],
            atTime: stopAt,
          ));
    }
    await Future.wait(futures);
  }

  void _highlightWins(SpinResult result) {
    final winning = List<Set<int>>.generate(SlotConfig.reelCount, (_) => {});
    for (final w in result.lineWins) {
      for (var reel = 0; reel < w.count; reel++) {
        winning[reel].add(w.positions[reel]);
      }
    }
    for (var i = 0; i < SlotConfig.reelCount; i++) {
      final dimmed = <int>{};
      for (var r = 0; r < SlotConfig.rowCount; r++) {
        if (!winning[i].contains(r)) dimmed.add(r);
      }
      _reelKeys[i].currentState?.setHighlights(
            winning: winning[i],
            dimmed: dimmed,
          );
    }
  }

  void _clearHighlights() {
    for (final k in _reelKeys) {
      k.currentState?.setHighlights(winning: const {}, dimmed: const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Holy_Machine_gameplay_assets/image 16.webp',
            fit: BoxFit.cover,
            cacheWidth: 1080,
          ),
          // Purple-golden bonus tint.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC2a0a2a),
                  Color(0xDD0a0206),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _BonusHeader(
                  currentSpin: _spinIndex,
                  totalSpins: _totalSpins,
                  wildsCollected: _wildsCollected,
                  totalWin: _totalBonusWin,
                ),
                Expanded(
                  child: Center(
                    child: _BonusSlotFrame(
                      reelKeys: _reelKeys,
                      finalSprinkle: _finalSprinkle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_showRetrigger)
            _RetriggerBanner(
              extraSpins: SlotEngine.freeSpinsForScatters(3),
              retriggerCount: _retriggers,
            ),
          if (!_introDone) _BonusIntro(spins: _totalSpins),
        ],
      ),
    );
  }
}

class _RetriggerBanner extends StatefulWidget {
  const _RetriggerBanner({
    required this.extraSpins,
    required this.retriggerCount,
  });

  final int extraSpins;
  final int retriggerCount;

  @override
  State<_RetriggerBanner> createState() => _RetriggerBannerState();
}

class _RetriggerBannerState extends State<_RetriggerBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final enter = Curves.elasticOut.transform((_c.value * 1.6).clamp(0.0, 1.0));
        final exit = _c.value < 0.85 ? 1.0 : 1 - (_c.value - 0.85) / 0.15;
        return IgnorePointer(
          child: Opacity(
            opacity: exit.clamp(0.0, 1.0),
            child: Center(
              child: Transform.scale(
                scale: 0.4 + 0.6 * enter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3a1a07), Color(0xFF2a0a2a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFFFFF2C8), width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xCCFF8A1A),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'RETRIGGER!',
                        style: TextStyle(
                          color: Color(0xFFFFF2C8),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: Color(0xFFFF8A1A), blurRadius: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '+${widget.extraSpins} FREE SPINS',
                        style: const TextStyle(
                          color: Color(0xFFFFD17A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      if (widget.retriggerCount > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          'x${widget.retriggerCount}',
                          style: const TextStyle(
                            color: Color(0xFFFFF2C8),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BonusHeader extends StatelessWidget {
  const _BonusHeader({
    required this.currentSpin,
    required this.totalSpins,
    required this.wildsCollected,
    required this.totalWin,
  });

  final int currentSpin;
  final int totalSpins;
  final int wildsCollected;
  final double totalWin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC150a05),
              border: Border.all(color: const Color(0xFFFFB638)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x88FF8A1A), blurRadius: 20),
              ],
            ),
            child: const Text(
              'FREE SPINS BONUS',
              style: TextStyle(
                color: Color(0xFFFFF2C8),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BonusMetric(
                  label: 'SPIN',
                  value: '$currentSpin / $totalSpins',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BonusMetric(
                  label: 'WILDS',
                  value: '$wildsCollected',
                  color: const Color(0xFFFFD17A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BonusMetric(
                  label: 'TOTAL WIN',
                  value: totalWin.toStringAsFixed(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BonusMetric extends StatelessWidget {
  const _BonusMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        border: Border.all(color: const Color(0xFFFF8A1A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD17A),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? const Color(0xFFFFF2C8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

const double _bonusFrameAspect = 1792 / 1043;

Size _bonusFrameSize(BoxConstraints c) {
  final maxW = c.maxWidth;
  final maxH = c.maxHeight.isFinite ? c.maxHeight : maxW / _bonusFrameAspect;
  var width = maxW;
  var height = width / _bonusFrameAspect;
  if (height > maxH) {
    height = maxH;
    width = height * _bonusFrameAspect;
  } else {
    final grown = height * 1.46;
    height = grown < maxH ? grown : maxH;
  }
  return Size(width, height);
}

Rect _bonusInnerRect(Size frame) {
  const leftF = 0.072;
  const topF = 0.112;
  const rightF = 0.928;
  const bottomF = 0.858;
  return Rect.fromLTWH(
    frame.width * leftF,
    frame.height * topF,
    frame.width * (rightF - leftF),
    frame.height * (bottomF - topF),
  );
}

class _BonusSlotFrame extends StatelessWidget {
  const _BonusSlotFrame({
    required this.reelKeys,
    required this.finalSprinkle,
  });

  final List<GlobalKey<ReelState>> reelKeys;
  final bool finalSprinkle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final frame = _bonusFrameSize(c);
        final inner = _bonusInnerRect(frame);
        final cellH = inner.height / SlotConfig.rowCount;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: frame.width,
          height: frame.height,
          decoration: BoxDecoration(
            boxShadow: finalSprinkle
                ? [
                    const BoxShadow(
                      color: Color(0xBBFFD17A),
                      blurRadius: 60,
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Image.asset(
                'assets/Holy_Machine_gameplay_assets/slot_frame_asset.webp',
                width: frame.width,
                height: frame.height,
                fit: BoxFit.fill,
              ),
              Positioned(
                left: inner.left,
                top: inner.top,
                width: inner.width,
                height: inner.height,
                child: Row(
                  children: [
                    for (var i = 0; i < SlotConfig.reelCount; i++)
                      Expanded(
                        child: SizedBox(
                          height: cellH * SlotConfig.rowCount,
                          child: Reel(
                            key: reelKeys[i],
                            reelIndex: i,
                            cellHeight: cellH,
                            rowCount: SlotConfig.rowCount,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BonusIntro extends StatefulWidget {
  const _BonusIntro({required this.spins});
  final int spins;

  @override
  State<_BonusIntro> createState() => _BonusIntroState();
}

class _BonusIntroState extends State<_BonusIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final fade = _c.value < 0.9
            ? 1.0
            : 1 - (_c.value - 0.9) / 0.1;
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            color: const Color(0xDD0a0206),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.6 + 0.4 * Curves.elasticOut.transform(
                        (_c.value * 1.4).clamp(0.0, 1.0)),
                    child: Image.asset(
                      symbolMeta[SlotSymbol.bonus]!.asset,
                      height: 170,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'BONUS GAME!',
                    style: TextStyle(
                      color: Color(0xFFFFF2C8),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      shadows: [
                        Shadow(color: Color(0xFFFF8A1A), blurRadius: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.spins} FREE SPINS',
                    style: const TextStyle(
                      color: Color(0xFFFFD17A),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Collect WILDS during the free spins. On the final '
                      'spin all collected wilds are sprinkled across the '
                      'reels!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD17A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
