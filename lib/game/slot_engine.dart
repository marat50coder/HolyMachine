// Core RNG + payout logic for the Holy Machine slot. 100% deterministic
// (seedable) for testing and 100% stateless so it can be reused for the base
// game and the free-spin bonus.

import 'dart:math';

import 'slot_config.dart';

/// Result of a single spin.
class SpinResult {
  SpinResult({
    required this.grid,
    required this.lineWins,
    required this.totalWin,
    required this.scatterCount,
    required this.wildCount,
    required this.betPerLine,
    required this.totalBet,
  });

  /// `grid[reel][row]` – the visible 5x3 window.
  final List<List<SlotSymbol>> grid;

  /// Winning paylines (populated only in the base game).
  final List<LineWin> lineWins;

  /// Total coin win for this spin.
  final double totalWin;

  /// Number of bonus/scatter symbols currently visible.
  final int scatterCount;

  /// Number of wild symbols currently visible.
  final int wildCount;

  /// Bet per line used for this spin.
  final double betPerLine;

  /// Total bet (= [betPerLine] * active lines).
  final double totalBet;

  /// Win expressed as a multiplier of the total bet. Useful for triggering
  /// "big win" animations when it exceeds configured thresholds.
  double get multiplier => totalBet <= 0 ? 0 : totalWin / totalBet;
}

class LineWin {
  LineWin({
    required this.lineIndex,
    required this.symbol,
    required this.count,
    required this.coins,
    required this.positions,
  });

  final int lineIndex;
  final SlotSymbol symbol;
  final int count;
  final double coins;

  /// `positions[i]` is the row index on reel `i` that participates in the win,
  /// for the first [count] reels.
  final List<int> positions;
}

class SlotEngine {
  SlotEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Generate the visible grid of symbols. Enforces "at most one bonus per
  /// reel", which is already guaranteed by the strip construction (there's
  /// only one bonus per strip), but we re-check as a safety net.
  ///
  /// [useBonusStrips] switches to the low-scatter strip set used inside the
  /// free-spin bonus, so retriggering stays rare even in a test build.
  List<List<SlotSymbol>> spinGrid({bool useBonusStrips = false}) {
    final strips = useBonusStrips ? bonusReelStrips : reelStrips;
    final grid = <List<SlotSymbol>>[];
    for (var reel = 0; reel < SlotConfig.reelCount; reel++) {
      final strip = strips[reel];
      final start = _random.nextInt(strip.length);
      final column = <SlotSymbol>[];
      for (var row = 0; row < SlotConfig.rowCount; row++) {
        column.add(strip[(start + row) % strip.length]);
      }
      // Safety: if somehow 2 scatters appear on same reel, replace extras.
      var bonusSeen = 0;
      for (var row = 0; row < column.length; row++) {
        if (column[row] == SlotSymbol.bonus) {
          bonusSeen++;
          if (bonusSeen > 1) {
            // Replace with a random low-pay symbol.
            final replacements = [
              SlotSymbol.ten,
              SlotSymbol.j,
              SlotSymbol.q,
              SlotSymbol.k,
              SlotSymbol.a,
            ];
            column[row] = replacements[_random.nextInt(replacements.length)];
          }
        }
      }
      grid.add(column);
    }
    return grid;
  }

  /// Full spin: compute grid, line wins and totals.
  SpinResult spin({required double betPerLine, bool useBonusStrips = false}) {
    final grid = spinGrid(useBonusStrips: useBonusStrips);
    return evaluate(grid: grid, betPerLine: betPerLine);
  }

  /// Evaluate an arbitrary grid (used by bonus "wild sprinkle" too).
  SpinResult evaluate({
    required List<List<SlotSymbol>> grid,
    required double betPerLine,
  }) {
    final totalBet = betPerLine * SlotConfig.lineCount;
    final wins = <LineWin>[];
    var totalWin = 0.0;

    for (var li = 0; li < paylines.length; li++) {
      final line = paylines[li];
      // Collect the symbol path.
      final path = <SlotSymbol>[];
      for (var reel = 0; reel < line.length; reel++) {
        path.add(grid[reel][line[reel]]);
      }

      final lineWin = _evaluatePath(path);
      if (lineWin == null) continue;
      final coins = SlotConfig.payFor(lineWin.$1, lineWin.$2) * betPerLine;
      if (coins <= 0) continue;
      wins.add(LineWin(
        lineIndex: li,
        symbol: lineWin.$1,
        count: lineWin.$2,
        coins: coins,
        positions: List<int>.generate(lineWin.$2, (i) => line[i]),
      ));
      totalWin += coins;
    }

    // Count scatters & wilds.
    var scatters = 0;
    var wilds = 0;
    for (final column in grid) {
      for (final symbol in column) {
        if (symbol == SlotSymbol.bonus) scatters++;
        if (symbol == SlotSymbol.wild) wilds++;
      }
    }

    return SpinResult(
      grid: grid,
      lineWins: wins,
      totalWin: totalWin,
      scatterCount: scatters,
      wildCount: wilds,
      betPerLine: betPerLine,
      totalBet: totalBet,
    );
  }

  /// Returns (symbol, count) for a winning path, or null if no win.
  /// Standard left-to-right evaluation with wild substitution.
  (SlotSymbol, int)? _evaluatePath(List<SlotSymbol> path) {
    // Pick the symbol: first non-wild, non-bonus; if first symbols are wilds,
    // we try to extend the "best" leading symbol.
    SlotSymbol? winSymbol;
    for (final s in path) {
      if (s == SlotSymbol.bonus) break;
      if (s != SlotSymbol.wild) {
        winSymbol = s;
        break;
      }
    }

    // All-wild line: pay as wild.
    if (winSymbol == null) {
      var count = 0;
      for (final s in path) {
        if (s == SlotSymbol.wild) {
          count++;
        } else {
          break;
        }
      }
      if (count >= 3) return (SlotSymbol.wild, count);
      return null;
    }

    // Count how far the match extends (with wild subs).
    var count = 0;
    for (final s in path) {
      if (s == winSymbol || s == SlotSymbol.wild) {
        count++;
      } else {
        break;
      }
    }

    // Compare with a hypothetical "wilds-as-wild" variant. If starting wild
    // run is longer and wild pays more, prefer wilds.
    var wildRun = 0;
    for (final s in path) {
      if (s == SlotSymbol.wild) {
        wildRun++;
      } else {
        break;
      }
    }
    if (wildRun >= 3) {
      final wildPay = SlotConfig.payFor(SlotSymbol.wild, wildRun);
      final symbolPay = SlotConfig.payFor(winSymbol, count);
      if (wildPay > symbolPay) {
        return (SlotSymbol.wild, wildRun);
      }
    }

    if (count < 3) return null;
    return (winSymbol, count);
  }

  /// For the final bonus spin: start with [baseGrid] and sprinkle [wildsToAdd]
  /// extra wilds onto random non-wild, non-bonus cells. Then evaluate.
  SpinResult finalBonusSpin({
    required List<List<SlotSymbol>> baseGrid,
    required int wildsToAdd,
    required double betPerLine,
  }) {
    final grid = baseGrid.map((c) => List<SlotSymbol>.from(c)).toList();
    final candidates = <(int, int)>[];
    for (var r = 0; r < grid.length; r++) {
      for (var row = 0; row < grid[r].length; row++) {
        final s = grid[r][row];
        if (s != SlotSymbol.wild && s != SlotSymbol.bonus) {
          candidates.add((r, row));
        }
      }
    }
    candidates.shuffle(_random);
    final n = wildsToAdd.clamp(0, candidates.length);
    for (var i = 0; i < n; i++) {
      final (reel, row) = candidates[i];
      grid[reel][row] = SlotSymbol.wild;
    }
    return evaluate(grid: grid, betPerLine: betPerLine);
  }

  /// Convenience: convert "scatter count" to free spins according to spec.
  static int freeSpinsForScatters(int scatters) {
    if (scatters >= 5) return 12;
    if (scatters == 4) return 8;
    if (scatters >= 3) return 5;
    return 0;
  }
}
