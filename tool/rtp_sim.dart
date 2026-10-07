// Standalone RTP simulation for the Holy Machine slot game.
// Run with: `dart run tool/rtp_sim.dart`
//
// Simulates N base-game spins (which may trigger bonus rounds) and prints the
// measured RTP. The bonus round model reproduces exactly what the UI does:
//   - 5 / 8 / 12 free spins for 3 / 4 / 5+ scatters
//   - For each spin we count visible wilds and accumulate them.
//   - On the final free spin the accumulated wild counter is "sprinkled" onto
//     the grid as additional wilds, and payouts are evaluated.

import 'dart:math';

import '../lib/game/slot_config.dart';
import '../lib/game/slot_engine.dart';

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args.first) : 1000000;
  final engine = SlotEngine(random: Random(42));

  const betPerLine = 1.0;
  final totalBet = betPerLine * SlotConfig.lineCount;

  var totalWagered = 0.0;
  var totalPaidBase = 0.0;
  var totalPaidBonus = 0.0;
  var bonusHits = 0;
  var scatterHistogram = <int, int>{};
  var winHistogram = <int, int>{}; // multiplier buckets
  var biggestMultiplier = 0.0;

  for (var i = 0; i < n; i++) {
    final res = engine.spin(betPerLine: betPerLine);
    totalWagered += totalBet;
    totalPaidBase += res.totalWin;
    scatterHistogram[res.scatterCount] =
        (scatterHistogram[res.scatterCount] ?? 0) + 1;
    if (res.multiplier > biggestMultiplier) {
      biggestMultiplier = res.multiplier;
    }
    final bucket = res.multiplier.floor();
    winHistogram[bucket] = (winHistogram[bucket] ?? 0) + 1;

    if (res.scatterCount >= 3) {
      bonusHits++;
      totalPaidBonus += _simulateBonus(engine, res.scatterCount, betPerLine);
    }
  }

  final totalPaid = totalPaidBase + totalPaidBonus;
  final rtp = totalPaid / totalWagered;
  print('Spins:            $n');
  print('Total wagered:    ${totalWagered.toStringAsFixed(0)}');
  print('Base game paid:   ${totalPaidBase.toStringAsFixed(0)}  '
      '(RTP ${(totalPaidBase / totalWagered * 100).toStringAsFixed(3)}%)');
  print('Bonus paid:       ${totalPaidBonus.toStringAsFixed(0)}  '
      '(RTP ${(totalPaidBonus / totalWagered * 100).toStringAsFixed(3)}%)');
  print('Total RTP:        ${(rtp * 100).toStringAsFixed(3)}%');
  print('Bonus hit rate:   1 in ${(n / bonusHits).toStringAsFixed(1)}');
  print('Biggest multiplier: ${biggestMultiplier.toStringAsFixed(2)}x');
  print('Scatter histogram: $scatterHistogram');
}

double _simulateBonus(SlotEngine engine, int scatters, double betPerLine) {
  final spins = SlotEngine.freeSpinsForScatters(scatters);
  var paid = 0.0;
  var collectedWilds = 0;
  List<List<SlotSymbol>>? lastGrid;
  for (var s = 0; s < spins; s++) {
    if (s == spins - 1) {
      // Final spin: use last grid as base and sprinkle collected wilds.
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
