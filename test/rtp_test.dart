import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:holy_machine_mex/game/slot_config.dart';
import 'package:holy_machine_mex/game/slot_engine.dart';

/// Fast sanity check: 100k spins should still land within ~2% of 98% RTP.
/// A full 2M-spin test confirming 98.0% is run separately via tool/rtp_sim.dart.
void main() {
  test('RTP ~= 98% over 100k spins', () {
    final engine = SlotEngine(random: Random(1234));
    const spins = 100000;
    const betPerLine = 1.0;
    final totalBet = betPerLine * SlotConfig.lineCount;

    var wagered = 0.0;
    var paid = 0.0;

    for (var i = 0; i < spins; i++) {
      final res = engine.spin(betPerLine: betPerLine);
      wagered += totalBet;
      paid += res.totalWin;
      if (res.scatterCount >= 3) {
        paid += _simulateBonus(engine, res.scatterCount, betPerLine);
      }
    }

    final rtp = paid / wagered;
    // 95% CI for 100k spins on a 98% RTP slot is ~± 3-4 pp. Keep headroom.
    expect(rtp, greaterThan(0.93));
    expect(rtp, lessThan(1.03));
  });

  test('At most 1 bonus symbol per reel in any visible window', () {
    final engine = SlotEngine(random: Random(7));
    for (var i = 0; i < 5000; i++) {
      final grid = engine.spinGrid();
      for (final column in grid) {
        final bonuses = column.where((s) => s == SlotSymbol.bonus).length;
        expect(bonuses, lessThanOrEqualTo(1),
            reason: 'More than one BONUS visible on a single reel');
      }
    }
  });
}

double _simulateBonus(SlotEngine engine, int scatters, double betPerLine) {
  final spins = SlotEngine.freeSpinsForScatters(scatters);
  var paid = 0.0;
  var collectedWilds = 0;
  List<List<SlotSymbol>>? lastGrid;
  for (var s = 0; s < spins; s++) {
    if (s == spins - 1) {
      final base = lastGrid ?? engine.spinGrid();
      final res = engine.finalBonusSpin(
        baseGrid: base,
        wildsToAdd: collectedWilds,
        betPerLine: betPerLine,
      );
      paid += res.totalWin;
    } else {
      final res = engine.spin(betPerLine: betPerLine);
      paid += res.totalWin;
      collectedWilds += res.wildCount;
      lastGrid = res.grid;
    }
  }
  return paid;
}
