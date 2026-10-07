import 'dart:async';

import 'package:flutter/material.dart';

import '../game/quests.dart';
import '../game/slot_config.dart';
import '../game/slot_engine.dart';
import '../game/wallet.dart';
import '../widgets/anticipation_effect.dart';
import '../widgets/big_win_overlay.dart';
import '../widgets/reel.dart';
import 'bonus_screen.dart';
import 'quests_screen.dart';

/// Base game screen. Portrait only.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final SlotEngine _engine = SlotEngine();
  final List<GlobalKey<ReelState>> _reelKeys =
      List.generate(SlotConfig.reelCount, (_) => GlobalKey<ReelState>());

  // Economy.
  double _betPerLine = 1.0;
  final List<double> _betOptions = [0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0];
  double _lastWin = 0.0;

  double get _balance => Wallet.instance.balance;

  bool _spinning = false;

  // Set of reel indices currently playing the "anticipation" (fire) effect.
  final Set<int> _anticipationReels = <int>{};

  // Winning paylines currently drawn above the slot grid.
  List<LineWin> _activeWins = const [];
  int _lineBannerIndex = 0; // which winning line's amount is displayed
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    Wallet.instance.addListener(_onWalletChange);
  }

  void _onWalletChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    Wallet.instance.removeListener(_onWalletChange);
    super.dispose();
  }

  void _startLineBannerCycle(List<LineWin> wins) {
    _bannerTimer?.cancel();
    if (wins.isEmpty) return;
    setState(() {
      _activeWins = wins;
      _lineBannerIndex = 0;
    });
    if (wins.length == 1) return;
    _bannerTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted || _activeWins.isEmpty) {
        t.cancel();
        return;
      }
      setState(() {
        _lineBannerIndex = (_lineBannerIndex + 1) % _activeWins.length;
      });
    });
  }

  void _clearLineBanners() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (!mounted) return;
    setState(() {
      _activeWins = const [];
      _lineBannerIndex = 0;
    });
  }

  Future<void> _spin() async {
    if (_spinning) return;
    final totalBet = _betPerLine * SlotConfig.lineCount;
    if (_balance < totalBet) {
      await _offerFreeFuns();
      return;
    }
    _clearLineBanners();
    Wallet.instance.trySpend(totalBet);
    setState(() {
      _spinning = true;
      _lastWin = 0;
    });

    final result = _engine.spin(betPerLine: _betPerLine);

    // Start all reels spinning.
    for (final k in _reelKeys) {
      k.currentState?.startSpin();
    }

    // All reels spin together and stop in a short cascade. Anticipation is
    // the only slow path, and it starts only after the 2nd scatter is visible.
    final start = DateTime.now();
    var scattersSoFar = 0;
    int? anticipateAfter;

    Future<void> stopReel(int index, DateTime at, {bool longStop = false}) {
      return _reelKeys[index].currentState!.stopOn(
            symbols: result.grid[index],
            atTime: at,
            longStop: longStop,
          );
    }

    final early = <Future<void>>[];
    for (var i = 0; i < SlotConfig.reelCount; i++) {
      final hasScatter = result.grid[i].contains(SlotSymbol.bonus);
      final bringsSecond =
          (scattersSoFar + (hasScatter ? 1 : 0)) == 2 &&
              i < SlotConfig.reelCount - 1;
      early.add(stopReel(
        i,
        start.add(Duration(milliseconds: 520 + i * 170)),
      ));
      if (hasScatter) scattersSoFar++;
      if (bringsSecond) {
        anticipateAfter = i;
        break;
      }
    }
    await Future.wait(early);
    if (!mounted) return;

    if (anticipateAfter != null) {
      final from = anticipateAfter + 1;
      // Zoom focus walks one reel at a time: light up only the next reel,
      // land it, then move the glow to the one after. When a scatter does
      // land on a lit reel we keep going; a miss drops the zoom immediately.
      var step = 0;
      for (var j = from; j < SlotConfig.reelCount; j++) {
        if (!mounted) return;
        setState(() {
          _anticipationReels
            ..clear()
            ..add(j);
        });
        unawaited(
          _reelKeys[j].currentState?.setAnticipationSpeed(true) ??
              Future<void>.value(),
        );
        await stopReel(
          j,
          DateTime.now().add(Duration(milliseconds: 420 + step * 180)),
          longStop: true,
        );
        if (!mounted) return;
        // Turn off the glow on this reel before moving on.
        setState(() => _anticipationReels.remove(j));
        final landedScatter = result.grid[j].contains(SlotSymbol.bonus);
        if (landedScatter) {
          step++; // Keep tension: next reel waits a bit longer.
        } else {
          // Scatter didn't land - no reason to keep zooming the rest, but
          // keep landing them normally so the spin doesn't just hang.
          step = 0;
        }
      }
    }

    if (!mounted) return;
    if (_anticipationReels.isNotEmpty) {
      setState(() => _anticipationReels.clear());
    }

    // Track quest progress based on this spin's result.
    QuestManager.instance.onSpin(
      totalWin: result.totalWin,
      scatterCount: result.scatterCount,
      multiplier: result.multiplier,
      lineWinCount: result.lineWins.length,
    );

    // Pay out winnings.
    if (result.totalWin > 0 && mounted) {
      Wallet.instance.add(result.totalWin);
      setState(() {
        _lastWin = result.totalWin;
      });
      _highlightWinningSymbols(result);
      _startLineBannerCycle(result.lineWins);
      final hold = (result.lineWins.length <= 1
              ? 1400
              : 900 * result.lineWins.length + 300)
          .clamp(1400, 5000);
      await Future<void>.delayed(Duration(milliseconds: hold));
      if (!mounted) return;
      _clearHighlights();
      _clearLineBanners();
    }

    // Big Win overlay if multiplier threshold reached.
    if (result.multiplier >= 15 && mounted) {
      await _showBigWin(result.totalWin, result.multiplier);
    }

    if (!mounted) return;
    setState(() {
      _spinning = false;
    });

    // Trigger bonus if >= 3 scatters.
    if (result.scatterCount >= 3 && mounted) {
      await _launchBonus(result.scatterCount);
    }
  }

  void _highlightWinningSymbols(SpinResult result) {
    // Build sets of winning cells per reel.
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

  Future<void> _showBigWin(double amount, double multiplier) async {
    if (!mounted) return;
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;
    final completer = Completer<void>();
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => BigWinOverlay(
        amount: amount,
        multiplier: multiplier,
        currency: 'FUNS',
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    try {
      overlayState.insert(entry);
      await completer.future;
    } catch (e, s) {
      debugPrint('BigWin overlay error: $e\n$s');
    } finally {
      try {
        if (entry.mounted) entry.remove();
      } catch (_) {}
    }
  }

  Future<void> _launchBonus(int scatters) async {
    if (!mounted) return;
    double? bonusWin;
    try {
      bonusWin = await Navigator.of(context).push<double>(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, __, ___) => BonusScreen(
            scatterCount: scatters,
            betPerLine: _betPerLine,
          ),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    } catch (e, s) {
      debugPrint('Bonus route error: $e\n$s');
      return;
    }
    if (!mounted) return;
    if (bonusWin != null && bonusWin > 0) {
      QuestManager.instance.onBonusTotalWin(bonusWin);
      Wallet.instance.add(bonusWin);
      setState(() {
        _lastWin = bonusWin!;
      });
      final mult = bonusWin / (_betPerLine * SlotConfig.lineCount);
      if (mult >= 15 && mounted) {
        // Let the UI settle for a frame before pushing the big-win overlay -
        // this avoids inserting into an Overlay that is still rebuilding after
        // the bonus route popped.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _showBigWin(bonusWin, mult);
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2a1507),
      ),
    );
  }

  /// Shown when the player cannot afford a spin. Credits 200 free FUNS so the
  /// game is never stuck on a zero balance.
  Future<void> _offerFreeFuns() async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a0d05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFB638), width: 2),
        ),
        title: const Text(
          'OUT OF FUNS',
          style: TextStyle(
            color: Color(0xFFFFF2C8),
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        content: const Text(
          'Here are 200 free FUNS to keep the fun going.',
          style: TextStyle(color: Color(0xFFFFD17A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'CLAIM 200 FUNS',
              style: TextStyle(
                color: Color(0xFFFFB638),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
    if (granted == true) {
      Wallet.instance.add(200);
    }
  }

  Future<void> _openQuests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuestsScreen(),
      ),
    );
  }

  void _changeBet(int delta) {
    final idx = _betOptions.indexOf(_betPerLine);
    final next = (idx + delta).clamp(0, _betOptions.length - 1);
    setState(() => _betPerLine = _betOptions[next]);
  }

  @override
  Widget build(BuildContext context) {
    final totalBet = _betPerLine * SlotConfig.lineCount;
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
          Container(color: const Color(0xAA000000)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  balance: _balance,
                  onClose: () => Navigator.of(context).pop(),
                  onQuests: _openQuests,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: _SlotFrame(
                      reelKeys: _reelKeys,
                      anticipationReels: _anticipationReels,
                      activeWins: _activeWins,
                      bannerIndex: _lineBannerIndex,
                    ),
                  ),
                ),
                _TotalWinBar(
                  totalWin: _lastWin,
                  spinning: _spinning,
                  hasActiveWins: _activeWins.isNotEmpty,
                ),
                const SizedBox(height: 8),
                _BottomBar(
                  betPerLine: _betPerLine,
                  totalBet: totalBet,
                  spinning: _spinning,
                  onSpin: _spin,
                  onBetUp: () => _changeBet(1),
                  onBetDown: () => _changeBet(-1),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({
    required this.reelKeys,
    required this.anticipationReels,
    required this.activeWins,
    required this.bannerIndex,
  });

  final List<GlobalKey<ReelState>> reelKeys;
  final Set<int> anticipationReels;
  final List<LineWin> activeWins;
  final int bannerIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final frame = _frameSize(c);
        final inner = _innerRect(frame);
        final cellH = inner.height / SlotConfig.rowCount;
        final cellW = inner.width / SlotConfig.reelCount;

        final activeLine = (activeWins.isEmpty || bannerIndex >= activeWins.length)
            ? null
            : activeWins[bannerIndex];

        return SizedBox(
          width: frame.width,
          height: frame.height,
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
                        child: _ReelContainer(
                          height: cellH * SlotConfig.rowCount,
                          anticipated: anticipationReels.contains(i),
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
              if (activeLine != null)
                Positioned.fromRect(
                  rect: inner,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PaylinePainter(
                        line: paylines[activeLine.lineIndex],
                        matchedCount: activeLine.count,
                        cellWidth: cellW,
                        cellHeight: cellH,
                      ),
                    ),
                  ),
                ),
              if (activeLine != null)
                Positioned(
                  left: inner.left,
                  right: 0,
                  top: inner.top +
                      paylines[activeLine.lineIndex][0] * cellH -
                      26,
                  child: IgnorePointer(
                    child: _LineWinBadge(
                      amount: activeLine.coins,
                      count: activeLine.count,
                      symbolLabel:
                          symbolMeta[activeLine.symbol]!.label,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PaylinePainter extends CustomPainter {
  _PaylinePainter({
    required this.line,
    required this.matchedCount,
    required this.cellWidth,
    required this.cellHeight,
  });

  final List<int> line;
  final int matchedCount;
  final double cellWidth;
  final double cellHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    for (var reel = 0; reel < matchedCount; reel++) {
      final row = line[reel];
      points.add(Offset(
        cellWidth * (reel + 0.5),
        cellHeight * (row + 0.5),
      ));
    }
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Outer soft glow.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0x66FFB638)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Main stroke.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF2C8), Color(0xFFFF8A1A)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // Highlight nodes.
    for (final p in points) {
      canvas.drawCircle(
        p,
        9,
        Paint()..color = const Color(0xFFFFF2C8),
      );
      canvas.drawCircle(
        p,
        5,
        Paint()..color = const Color(0xFFFF7A00),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaylinePainter old) =>
      old.line != line ||
      old.matchedCount != matchedCount ||
      old.cellWidth != cellWidth ||
      old.cellHeight != cellHeight;
}

class _LineWinBadge extends StatelessWidget {
  const _LineWinBadge({
    required this.amount,
    required this.count,
    required this.symbolLabel,
  });

  final double amount;
  final int count;
  final String symbolLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xEE1a0e07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB638), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x99FF8A1A), blurRadius: 18),
          ],
        ),
        child: Text(
          '$count× $symbolLabel  +${amount.toStringAsFixed(2)} FUNS',
          style: const TextStyle(
            color: Color(0xFFFFF2C8),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _TotalWinBar extends StatelessWidget {
  const _TotalWinBar({
    required this.totalWin,
    required this.spinning,
    required this.hasActiveWins,
  });

  final double totalWin;
  final bool spinning;
  final bool hasActiveWins;

  @override
  Widget build(BuildContext context) {
    final glowing = hasActiveWins && totalWin > 0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: spinning ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC150a05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: glowing
                  ? const Color(0xFFFFF2C8)
                  : const Color(0xFF8A5A14),
              width: glowing ? 2 : 1,
            ),
            boxShadow: glowing
                ? const [
                    BoxShadow(
                      color: Color(0xAAFF8A1A),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL WIN',
                style: TextStyle(
                  color: Color(0xFFFFD17A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Row(
                children: [
                  Text(
                    totalWin.toStringAsFixed(2),
                    style: TextStyle(
                      color: glowing
                          ? const Color(0xFFFFF2C8)
                          : const Color(0xFFFFD17A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: glowing
                          ? const [
                              Shadow(
                                color: Color(0xFFFF8A1A),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'FUNS',
                    style: TextStyle(
                      color: Color(0xFFFFD17A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real pixel size of slot_frame_asset.webp.
const double _frameAspect = 1792 / 1043;

/// Inner window of the frame (fractions of the image) where the reels sit.
/// Symbols cover this whole window, including the gold divider lines.
const double _innerLeft = 0.072;
const double _innerTop = 0.112;
const double _innerRight = 0.928;
const double _innerBottom = 0.858;

Size _frameSize(BoxConstraints c) {
  final maxW = c.maxWidth;
  final maxH = c.maxHeight.isFinite ? c.maxHeight : maxW / _frameAspect;
  var width = maxW;
  var height = width / _frameAspect;
  if (height > maxH) {
    height = maxH;
    width = height * _frameAspect;
  } else {
    // Use the free vertical space so the board is larger than the raw image.
    final grown = height * 1.46;
    height = grown < maxH ? grown : maxH;
  }
  return Size(width, height);
}

Rect _innerRect(Size frame) {
  final left = frame.width * _innerLeft;
  final top = frame.height * _innerTop;
  return Rect.fromLTWH(
    left,
    top,
    frame.width * (_innerRight - _innerLeft),
    frame.height * (_innerBottom - _innerTop),
  );
}

class _ReelContainer extends StatelessWidget {
  const _ReelContainer({
    required this.height,
    required this.anticipated,
    required this.child,
  });

  final double height;
  final bool anticipated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (anticipated)
            const Positioned.fill(child: AnticipationEffect()),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.balance,
    required this.onClose,
    required this.onQuests,
  });

  final double balance;
  final VoidCallback onClose;
  final VoidCallback onQuests;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  @override
  void initState() {
    super.initState();
    QuestManager.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    QuestManager.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final unclaimed = QuestManager.instance.unclaimedCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          _IconBtn(icon: Icons.close, onTap: widget.onClose),
          const SizedBox(width: 6),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _IconBtn(
                icon: Icons.emoji_events_outlined,
                onTap: widget.onQuests,
              ),
              if (unclaimed > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4500),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFFF2C8), width: 1),
                    ),
                    child: Text(
                      '$unclaimed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          const _NotRealMoneyBadge(),
          const Spacer(),
          _MetricTile(label: 'BALANCE', value: widget.balance),
        ],
      ),
    );
  }
}

class _NotRealMoneyBadge extends StatelessWidget {
  const _NotRealMoneyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF8A1A), width: 1),
      ),
      child: const Text(
        'FUNS • NOT REAL MONEY',
        style: TextStyle(
          color: Color(0xFFFFD17A),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF8A1A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD17A),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFFFFF2C8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xCC150a05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF8A1A), width: 1),
        ),
        child: Icon(icon, color: const Color(0xFFFFD17A), size: 20),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.betPerLine,
    required this.totalBet,
    required this.spinning,
    required this.onSpin,
    required this.onBetUp,
    required this.onBetDown,
  });

  final double betPerLine;
  final double totalBet;
  final bool spinning;
  final VoidCallback onSpin;
  final VoidCallback onBetUp;
  final VoidCallback onBetDown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _BetControl(
            label: 'BET/LINE',
            value: betPerLine,
            onUp: onBetUp,
            onDown: onBetDown,
          ),
          const Spacer(),
          _SpinButton(spinning: spinning, onTap: onSpin),
          const Spacer(),
          _TotalBetDisplay(totalBet: totalBet),
        ],
      ),
    );
  }
}

class _BetControl extends StatelessWidget {
  const _BetControl({
    required this.label,
    required this.value,
    required this.onUp,
    required this.onDown,
  });

  final String label;
  final double value;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFD17A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _MiniBtn(icon: Icons.remove, onTap: onDown),
            SizedBox(
              width: 56,
              child: Center(
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Color(0xFFFFF2C8),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            _MiniBtn(icon: Icons.add, onTap: onUp),
          ],
        ),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xCC2a1507),
          border: Border.all(color: const Color(0xFFFF8A1A)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFFFD17A), size: 16),
      ),
    );
  }
}

class _SpinButton extends StatefulWidget {
  const _SpinButton({required this.spinning, required this.onTap});
  final bool spinning;
  final VoidCallback onTap;

  @override
  State<_SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<_SpinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotate;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant _SpinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning) {
      if (!_rotate.isAnimating) _rotate.repeat();
    } else {
      _rotate.stop();
      _rotate.value = 0;
    }
  }

  @override
  void dispose() {
    _rotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.spinning ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _rotate,
        builder: (_, child) {
          return Transform.rotate(
            angle: _rotate.value * 6.283,
            child: child,
          );
        },
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFD17A), Color(0xFFFF7A00), Color(0xFF8A2A00)],
            ),
            border: Border.all(color: const Color(0xFFFFF2C8), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAAFF7A00),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.autorenew, color: Color(0xFF401500), size: 42),
        ),
      ),
    );
  }
}

class _TotalBetDisplay extends StatelessWidget {
  const _TotalBetDisplay({required this.totalBet});
  final double totalBet;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'TOTAL BET',
          style: TextStyle(
            color: Color(0xFFFFD17A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC2a1507),
            border: Border.all(color: const Color(0xFFFF8A1A)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            totalBet.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFFFFF2C8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
