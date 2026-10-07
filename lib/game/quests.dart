import 'package:flutter/foundation.dart';

/// Simple in-memory quest tracker. Lives for a single app session.
///
/// Each quest exposes a progress value, a target, a FUNS reward and a flag
/// that says the player has already claimed the reward. The quest UI listens
/// via [ChangeNotifier].
enum QuestId {
  spinCount,
  winTotal,
  triggerBonus,
  hitBigWin,
  winFiveLines,
}

class Quest {
  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
  });

  final QuestId id;
  final String title;
  final String description;
  final int target;
  final int reward;

  int progress = 0;
  bool claimed = false;

  bool get completed => progress >= target && !claimed;
  bool get finished => claimed;
  double get progressFraction =>
      target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);
}

class QuestManager extends ChangeNotifier {
  QuestManager._();
  static final QuestManager instance = QuestManager._();

  final List<Quest> quests = [
    Quest(
      id: QuestId.spinCount,
      title: 'Warm up',
      description: 'Make 50 spins.',
      target: 50,
      reward: 300,
    ),
    Quest(
      id: QuestId.winTotal,
      title: 'Rolling in FUNS',
      description: 'Win 1 000 FUNS in total.',
      target: 1000,
      reward: 500,
    ),
    Quest(
      id: QuestId.triggerBonus,
      title: 'Scatter hunter',
      description: 'Trigger the free-spin bonus once.',
      target: 1,
      reward: 500,
    ),
    Quest(
      id: QuestId.hitBigWin,
      title: 'Taste of fortune',
      description: 'Hit a BIG WIN (15× total bet).',
      target: 1,
      reward: 300,
    ),
    Quest(
      id: QuestId.winFiveLines,
      title: 'Line collector',
      description: 'Win on 5 different lines in one spin.',
      target: 1,
      reward: 400,
    ),
  ];

  Quest _byId(QuestId id) => quests.firstWhere((q) => q.id == id);

  /// Called after every base-game spin.
  void onSpin({
    required double totalWin,
    required int scatterCount,
    required double multiplier,
    required int lineWinCount,
  }) {
    _advance(QuestId.spinCount, 1);
    if (totalWin > 0) {
      _advance(QuestId.winTotal, totalWin.round());
    }
    if (scatterCount >= 3) {
      _advance(QuestId.triggerBonus, 1);
    }
    if (multiplier >= 15) {
      _advance(QuestId.hitBigWin, 1);
    }
    if (lineWinCount >= 5) {
      _advance(QuestId.winFiveLines, 1);
    }
    notifyListeners();
  }

  void onBonusTotalWin(double amount) {
    if (amount > 0) {
      _advance(QuestId.winTotal, amount.round());
      notifyListeners();
    }
  }

  void _advance(QuestId id, int delta) {
    final q = _byId(id);
    if (q.claimed) return;
    q.progress = (q.progress + delta).clamp(0, q.target);
  }

  /// Returns the claimed reward amount, or 0 if nothing to claim.
  int claim(QuestId id) {
    final q = _byId(id);
    if (q.claimed || q.progress < q.target) return 0;
    q.claimed = true;
    notifyListeners();
    return q.reward;
  }

  int get unclaimedCount =>
      quests.where((q) => q.progress >= q.target && !q.claimed).length;
}
