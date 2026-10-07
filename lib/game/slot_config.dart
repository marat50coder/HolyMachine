// Configuration for the Holy Machine slot engine.
// Grid: 5 reels x 3 rows. 20 fixed paylines. Wilds substitute every non-scatter
// symbol. Scatters pay nothing on their own but trigger the bonus round.
//
// Payouts are expressed in "coins", where a single spin costs
// [SlotConfig.lineCount] coins (one coin per activated line) multiplied by the
// current bet-per-line value. Payouts are per-line and are multiplied by the
// current bet-per-line value as well, exactly the same way as real-money slots.

import 'dart:math';

/// Enumeration of all symbols used by the game.
enum SlotSymbol {
  ten,
  j,
  q,
  k,
  a,
  watch,
  headphones,
  sneaker,
  laptop,
  boxes,
  basket,
  wild,
  bonus,
}

/// Metadata for rendering a symbol.
class SymbolMeta {
  const SymbolMeta({required this.asset, required this.label});
  final String asset;
  final String label;
}

/// Static metadata lookup for every symbol.
const Map<SlotSymbol, SymbolMeta> symbolMeta = {
  SlotSymbol.ten: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/10_slot_asset.webp',
    label: '10',
  ),
  SlotSymbol.j: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/J_slot_asset.webp',
    label: 'J',
  ),
  SlotSymbol.q: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/Q_slot_asset.webp',
    label: 'Q',
  ),
  SlotSymbol.k: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/K_slot_asset.webp',
    label: 'K',
  ),
  SlotSymbol.a: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/A_slot_asset.webp',
    label: 'A',
  ),
  SlotSymbol.watch: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/watch_slot_asset.webp',
    label: 'WATCH',
  ),
  SlotSymbol.headphones: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/headphones_slot_asset.webp',
    label: 'HEADPHONES',
  ),
  SlotSymbol.sneaker: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/sneaker_slot_asset.webp',
    label: 'SNEAKER',
  ),
  SlotSymbol.laptop: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/laptop_slot_asset.webp',
    label: 'LAPTOP',
  ),
  SlotSymbol.boxes: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/boxes_slot_asset.webp',
    label: 'BOXES',
  ),
  SlotSymbol.basket: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/basket_slot_asset.webp',
    label: 'CART',
  ),
  SlotSymbol.wild: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/wild_slot_asset.webp',
    label: 'WILD',
  ),
  SlotSymbol.bonus: SymbolMeta(
    asset: 'assets/Holy_Machine_gameplay_assets/bonus_slot_asset.webp',
    label: 'BONUS',
  ),
};

/// Pay table: payout per matching-symbol count. Keys are the count of
/// matching symbols on a line (3, 4 or 5). Values are coin multipliers of the
/// per-line bet.
///
/// All values are tuned together with the reel weights to achieve a target
/// RTP of ~98% (see test_rtp.dart).
const Map<SlotSymbol, Map<int, double>> payTable = {
  // Low pay (card ranks)
  SlotSymbol.ten: {3: 15, 4: 40, 5: 150},
  SlotSymbol.j: {3: 15, 4: 40, 5: 150},
  SlotSymbol.q: {3: 20, 4: 60, 5: 200},
  SlotSymbol.k: {3: 20, 4: 60, 5: 200},
  SlotSymbol.a: {3: 25, 4: 80, 5: 250},
  // Mid pay
  SlotSymbol.watch: {3: 40, 4: 120, 5: 400},
  SlotSymbol.headphones: {3: 40, 4: 120, 5: 400},
  SlotSymbol.sneaker: {3: 60, 4: 180, 5: 600},
  SlotSymbol.laptop: {3: 75, 4: 250, 5: 750},
  // High pay
  SlotSymbol.boxes: {3: 125, 4: 400, 5: 1250},
  SlotSymbol.basket: {3: 200, 4: 600, 5: 2000},
  // Wild also pays as a standalone 5-of-a-kind. Typically matches the top.
  SlotSymbol.wild: {3: 200, 4: 600, 5: 2000},
};

/// Reel strips: one strip per reel. Each reel contains an ordered sequence of
/// symbols; a spin picks a random window of three consecutive symbols.
///
/// We allow multiple bonus symbols per strip but space them out so that at
/// most ONE bonus is ever visible per reel in any 3-row window.
final List<List<SlotSymbol>> reelStrips = _buildReelStrips(
  kTestingHighHitRate ? _testBuildWeights : _productionWeights,
  seed: 0xC0FFEE,
);

/// Separate reel strips used **inside the free-spin bonus**. They have:
///   * a small number of BONUS symbols → retriggers are rare, just like the
///     base-game trigger;
///   * a boosted number of WILD symbols → the final wild sprinkle actually
///     has material to work with.
/// Independent of [kTestingHighHitRate].
final List<List<SlotSymbol>> bonusReelStrips = _buildReelStrips(
  _bonusWeights,
  seed: 0xBEEF,
);

/// RELEASE / TEST toggle for the base game. Set `true` only for local
/// debugging - production RTP is only correct when this is `false`.
const bool kTestingHighHitRate = false;

List<List<SlotSymbol>> _buildReelStrips(
  List<Map<SlotSymbol, int>> perReelWeights, {
  required int seed,
}) {
  final rng = Random(seed);
  final strips = <List<SlotSymbol>>[];
  for (final weights in perReelWeights) {
    final nonBonus = <SlotSymbol>[];
    weights.forEach((symbol, count) {
      if (symbol == SlotSymbol.bonus) return;
      for (var i = 0; i < count; i++) {
        nonBonus.add(symbol);
      }
    });
    nonBonus.shuffle(rng);

    final bonusCount = weights[SlotSymbol.bonus] ?? 0;
    final totalLen = nonBonus.length + bonusCount;
    final strip = List<SlotSymbol?>.filled(totalLen, null);
    if (bonusCount > 0) {
      final step = totalLen / bonusCount;
      final offset = rng.nextInt((step).floor());
      assert(step >= 4, 'bonus spacing < 4 breaks "max 1 bonus per reel" rule');
      for (var b = 0; b < bonusCount; b++) {
        final idx = ((offset + b * step).floor()) % totalLen;
        var slot = idx;
        while (strip[slot] != null) {
          slot = (slot + 1) % totalLen;
        }
        strip[slot] = SlotSymbol.bonus;
      }
    }
    var p = 0;
    for (var i = 0; i < totalLen; i++) {
      if (strip[i] == null) {
        strip[i] = nonBonus[p++];
      }
    }
    strips.add(List<SlotSymbol>.unmodifiable(strip.cast<SlotSymbol>()));
  }
  return List<List<SlotSymbol>>.unmodifiable(strips);
}

/// Production weights — tuned (together with [payTable] and
/// [rtpBalancingMultiplier]) to a measured RTP of ~98%.
final List<Map<SlotSymbol, int>> _productionWeights = List.generate(5, (_) => {
      SlotSymbol.ten: 12,
      SlotSymbol.j: 12,
      SlotSymbol.q: 10,
      SlotSymbol.k: 10,
      SlotSymbol.a: 8,
      SlotSymbol.watch: 7,
      SlotSymbol.headphones: 7,
      SlotSymbol.sneaker: 6,
      SlotSymbol.laptop: 5,
      SlotSymbol.boxes: 4,
      SlotSymbol.basket: 3,
      SlotSymbol.wild: 2,
      SlotSymbol.bonus: 3,
    });

/// Weights for the "test build": far more bonuses, wilds and high-pay symbols.
/// Keeps the "max 1 bonus per reel in a window" guarantee because the strip is
/// still long enough to space 7 bonuses apart.
final List<Map<SlotSymbol, int>> _testBuildWeights = List.generate(5, (_) => {
      SlotSymbol.ten: 4,
      SlotSymbol.j: 4,
      SlotSymbol.q: 4,
      SlotSymbol.k: 4,
      SlotSymbol.a: 4,
      SlotSymbol.watch: 5,
      SlotSymbol.headphones: 5,
      SlotSymbol.sneaker: 5,
      SlotSymbol.laptop: 5,
      SlotSymbol.boxes: 4,
      SlotSymbol.basket: 4,
      SlotSymbol.wild: 6,
      SlotSymbol.bonus: 7,
    });

/// Weights used **inside the free-spin bonus**. BONUS stays very rare (3)
/// so the retrigger rate matches the base-game trigger. WILD is heavily
/// boosted (10) so the final sprinkle has lots of material to work with and
/// the bonus round delivers juicy wins.
final List<Map<SlotSymbol, int>> _bonusWeights = List.generate(5, (_) => {
      SlotSymbol.ten: 10,
      SlotSymbol.j: 10,
      SlotSymbol.q: 9,
      SlotSymbol.k: 9,
      SlotSymbol.a: 8,
      SlotSymbol.watch: 7,
      SlotSymbol.headphones: 7,
      SlotSymbol.sneaker: 6,
      SlotSymbol.laptop: 5,
      SlotSymbol.boxes: 4,
      SlotSymbol.basket: 3,
      SlotSymbol.wild: 10,
      SlotSymbol.bonus: 3,
    });


/// 20 fixed paylines. Each line is a list of row indices (0=top, 2=bottom)
/// one entry per reel.
const List<List<int>> paylines = [
  [1, 1, 1, 1, 1], // middle
  [0, 0, 0, 0, 0], // top
  [2, 2, 2, 2, 2], // bottom
  [0, 1, 2, 1, 0], // V
  [2, 1, 0, 1, 2], // ^
  [1, 0, 0, 0, 1],
  [1, 2, 2, 2, 1],
  [0, 0, 1, 2, 2],
  [2, 2, 1, 0, 0],
  [1, 2, 1, 0, 1],
  [1, 0, 1, 2, 1],
  [0, 1, 1, 1, 0],
  [2, 1, 1, 1, 2],
  [0, 1, 0, 1, 0],
  [2, 1, 2, 1, 2],
  [1, 1, 0, 1, 1],
  [1, 1, 2, 1, 1],
  [0, 2, 0, 2, 0],
  [2, 0, 2, 0, 2],
  [1, 0, 2, 0, 1],
];

/// Multiplier applied to every pay-table entry at evaluation time. Used to
/// fine-tune the RTP to its target value (98%) without having to redesign the
/// pay table every time. Keep this close to 1.0 -- it exists purely as a last
/// adjustment knob and is covered by the automated RTP test.
const double rtpBalancingMultiplier = 1.371;

class SlotConfig {
  static int get reelCount => reelStrips.length;
  static int get rowCount => 3;
  static int get lineCount => paylines.length;

  /// Returns the payout for [symbol] with [count] matches, including the
  /// RTP balancing multiplier.
  static double payFor(SlotSymbol symbol, int count) {
    final base = payTable[symbol]?[count] ?? 0;
    return base * rtpBalancingMultiplier;
  }
}
