import 'package:flutter/material.dart';

import '../game/quests.dart';
import '../game/wallet.dart';

/// Scrollable list of quests with progress bars and a Claim button. Rewards
/// are credited directly to [Wallet.instance], so this screen works the same
/// way whether it's opened from the menu or from the game.
class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
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

  void _onChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _claim(Quest q) {
    final reward = QuestManager.instance.claim(q.id);
    if (reward > 0) {
      Wallet.instance.add(reward.toDouble());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$reward FUNS added to your balance'),
          backgroundColor: const Color(0xFF2a1507),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quests = QuestManager.instance.quests;
    return Scaffold(
      backgroundColor: const Color(0xFF0d0806),
      appBar: AppBar(
        backgroundColor: const Color(0xCC150a05),
        foregroundColor: const Color(0xFFFFD17A),
        title: const Text(
          'QUESTS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: AnimatedBuilder(
                animation: Wallet.instance,
                builder: (_, __) => Text(
                  '${Wallet.instance.balance.toStringAsFixed(0)} FUNS',
                  style: const TextStyle(
                    color: Color(0xFFFFD17A),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: quests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _QuestTile(quest: quests[i], onClaim: _claim),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.onClaim});

  final Quest quest;
  final ValueChanged<Quest> onClaim;

  @override
  Widget build(BuildContext context) {
    final completed = quest.completed;
    final finished = quest.finished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: finished
              ? const Color(0xFF4a3015)
              : (completed
                  ? const Color(0xFFFFB638)
                  : const Color(0xFFFF8A1A)),
          width: completed && !finished ? 2 : 1,
        ),
        boxShadow: completed && !finished
            ? const [
                BoxShadow(color: Color(0x66FFB638), blurRadius: 18),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quest.title.toUpperCase(),
                  style: TextStyle(
                    color: finished
                        ? const Color(0xFF806040)
                        : const Color(0xFFFFF2C8),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FF8A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF8A1A), width: 1),
                ),
                child: Text(
                  '+${quest.reward} FUNS',
                  style: const TextStyle(
                    color: Color(0xFFFFD17A),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            quest.description,
            style: const TextStyle(
              color: Color(0xBBFFE2A8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: quest.progressFraction,
                    backgroundColor: const Color(0xFF2a1507),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      finished
                          ? const Color(0xFF806040)
                          : (completed
                              ? const Color(0xFFFFB638)
                              : const Color(0xFFFF8A1A)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${quest.progress} / ${quest.target}',
                style: const TextStyle(
                  color: Color(0xFFFFD17A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _ClaimButton(
              enabled: completed,
              claimed: finished,
              onTap: () => onClaim(quest),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.enabled,
    required this.claimed,
    required this.onTap,
  });

  final bool enabled;
  final bool claimed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = claimed
        ? const Color(0xFF503820)
        : (enabled ? const Color(0xFFFFB638) : const Color(0xFF3a1a07));
    return GestureDetector(
      onTap: enabled && !claimed ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: enabled && !claimed
                  ? const Color(0xFFFFF2C8)
                  : const Color(0xFF80602a),
              width: 1.2),
        ),
        child: Text(
          claimed
              ? 'CLAIMED'
              : (enabled ? 'CLAIM' : 'LOCKED'),
          style: TextStyle(
            color: claimed
                ? const Color(0xFF8f7050)
                : (enabled
                    ? const Color(0xFF401500)
                    : const Color(0xFF806040)),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
