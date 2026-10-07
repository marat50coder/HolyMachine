import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/slot_config.dart';
import 'symbol_tile.dart';

/// A single spinning reel. During a spin we draw a rolling random strip. When
/// stop is requested we quickly animate a short deceleration strip followed
/// by the three target symbols, leaving them "pinned" in the visible window.
class Reel extends StatefulWidget {
  const Reel({
    super.key,
    required this.reelIndex,
    required this.cellHeight,
    required this.rowCount,
  });

  final int reelIndex;
  final double cellHeight;
  final int rowCount;

  @override
  State<Reel> createState() => ReelState();
}

class ReelState extends State<Reel> with TickerProviderStateMixin {
  late Ticker _spinTicker;
  late final List<SlotSymbol> _strip;

  // Rolling strip of random symbols drawn while spinning.
  final List<SlotSymbol> _rollingSymbols = [];
  // Scroll offset in pixels (how far the rolling strip has moved upward).
  double _rollingOffset = 0;
  double _spinSpeed = 0;

  // Visible frame when not spinning.
  List<SlotSymbol> _visible = const [];
  Set<int> _highlightedRows = const {};
  Set<int> _dimmedRows = const {};

  bool _spinning = false;
  final Random _rng = Random();
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _strip = reelStrips[widget.reelIndex];
    _visible = _strip.take(widget.rowCount).toList();
    _spinTicker = createTicker(_onTick);
    _fillRollingBuffer();
  }

  void _fillRollingBuffer() {
    _rollingSymbols.clear();
    for (var i = 0; i < widget.rowCount + 8; i++) {
      _rollingSymbols.add(_strip[_rng.nextInt(_strip.length)]);
    }
  }

  @override
  void dispose() {
    _spinTicker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == null
        ? 1 / 60
        : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_spinning) return;
    _rollingOffset += _spinSpeed * dt;
    // When we scroll past one cell, pop top and push bottom.
    while (_rollingOffset >= widget.cellHeight) {
      _rollingOffset -= widget.cellHeight;
      _rollingSymbols.removeAt(0);
      _rollingSymbols.add(_strip[_rng.nextInt(_strip.length)]);
    }
    setState(() {});
  }

  Future<void> startSpin() async {
    if (_spinning) return;
    _spinning = true;
    _lastTick = null;
    // Slightly slower than the previous cruise so a normal spin is readable.
    _spinSpeed = 1050 + widget.reelIndex * 30;
    _highlightedRows = const {};
    _dimmedRows = const {};
    _spinTicker.start();
    setState(() {});
  }

  /// Smoothly switch to the "anticipation" spin speed. Starts a tiny tween so
  /// the reel decelerates visibly instead of snapping to the slow speed.
  Future<void> setAnticipationSpeed(bool anticipated) async {
    if (!_spinning || !mounted) return;
    // Zoom scrolls slowly, the way a normal spin used to feel.
    final target = anticipated ? 520.0 : (1050.0 + widget.reelIndex * 30);
    final start = _spinSpeed;
    final tween = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final curve = CurvedAnimation(parent: tween, curve: Curves.easeOutCubic);
    void onTick() {
      _spinSpeed = start + (target - start) * curve.value;
    }
    tween.addListener(onTick);
    try {
      await tween.forward();
    } finally {
      tween.removeListener(onTick);
      tween.dispose();
      _spinSpeed = target;
    }
  }

  /// Stop the reel and land on the given 3 symbols. [atTime] gives the earliest
  /// moment the reel is allowed to stop. Returns when the reel is locked.
  Future<void> stopOn({
    required List<SlotSymbol> symbols,
    required DateTime atTime,
    bool longStop = false,
  }) async {
    while (DateTime.now().isBefore(atTime)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    _spinning = false;
    _spinTicker.stop();

    // Normal stop is a short settle. Zoom uses the old long roll-out:
    // five extra cells over ~450–900ms, same as a regular spin used to be.
    final decel = <SlotSymbol>[];
    final extraCells = longStop ? 5 : 2;
    for (var i = 0; i < extraCells; i++) {
      decel.add(_strip[_rng.nextInt(_strip.length)]);
    }
    decel.addAll(symbols);

    final ac = AnimationController(
      vsync: this,
      duration: longStop
          ? Duration(milliseconds: 450 + widget.reelIndex * 110)
          : const Duration(milliseconds: 340),
    );
    final curve = CurvedAnimation(parent: ac, curve: Curves.easeOutCubic);
    final completer = Completer<void>();
    ac.addListener(() {
      final t = curve.value;
      setState(() {
        _landProgress = t;
        _landStrip = decel;
      });
      if (ac.isCompleted) {
        _visible = List<SlotSymbol>.from(symbols);
        _landProgress = null;
        _landStrip = null;
        _rollingOffset = 0;
        _fillRollingBuffer();
        completer.complete();
      }
    });
    ac.forward();
    await completer.future;
    ac.dispose();

    // Small bounce.
    final bounce = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: longStop ? 160 : 100),
    );
    final bc = CurvedAnimation(parent: bounce, curve: Curves.easeOutSine);
    bounce.addListener(() {
      setState(() {
        _bounceOffset = -5 * (1 - bc.value);
      });
    });
    await bounce.forward();
    bounce.dispose();
    setState(() {
      _bounceOffset = 0;
    });
  }

  double _bounceOffset = 0;
  double? _landProgress;
  List<SlotSymbol>? _landStrip;

  void setHighlights({Set<int>? winning, Set<int>? dimmed}) {
    setState(() {
      _highlightedRows = winning ?? const {};
      _dimmedRows = dimmed ?? const {};
    });
  }

  void setStaticVisible(List<SlotSymbol> symbols) {
    setState(() {
      _visible = List<SlotSymbol>.from(symbols);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalHeight = widget.cellHeight * widget.rowCount;
    return SizedBox(
      height: totalHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: _buildContent(totalHeight),
        ),
      ),
    );
  }

  Widget _buildContent(double totalHeight) {
    if (_spinning) {
      // Rolling display: offset the strip downward by _rollingOffset.
      return Transform.translate(
        offset: Offset(0, -widget.cellHeight + _rollingOffset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in _rollingSymbols)
              SizedBox(
                width: double.infinity,
                height: widget.cellHeight,
                child: SymbolTile(symbol: s),
              ),
          ],
        ),
      );
    }
    if (_landProgress != null && _landStrip != null) {
      // Animate scroll of _landStrip until the last widget.rowCount symbols
      // are perfectly aligned with the visible frame.
      final totalDistance = (_landStrip!.length - widget.rowCount) *
          widget.cellHeight;
      final travelled = totalDistance * _landProgress!;
      return Transform.translate(
        offset: Offset(0, -travelled),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in _landStrip!)
              SizedBox(
                width: double.infinity,
                height: widget.cellHeight,
                child: SymbolTile(symbol: s),
              ),
          ],
        ),
      );
    }
    // Static visible frame.
    return Transform.translate(
      offset: Offset(0, _bounceOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _visible.length; i++)
            SizedBox(
              width: double.infinity,
              height: widget.cellHeight,
              child: SymbolTile(
                symbol: _visible[i],
                highlighted: _highlightedRows.contains(i),
                dimmed: _dimmedRows.contains(i),
              ),
            ),
        ],
      ),
    );
  }
}
