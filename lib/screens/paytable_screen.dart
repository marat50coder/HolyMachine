import 'package:flutter/material.dart';

import '../game/slot_config.dart';
import '../widgets/symbol_tile.dart';

/// Shows the paytable (symbol → payout per match count) and all 20 paylines.
class PaytableScreen extends StatelessWidget {
  const PaytableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paying = const [
      SlotSymbol.basket,
      SlotSymbol.boxes,
      SlotSymbol.laptop,
      SlotSymbol.sneaker,
      SlotSymbol.headphones,
      SlotSymbol.watch,
      SlotSymbol.a,
      SlotSymbol.k,
      SlotSymbol.q,
      SlotSymbol.j,
      SlotSymbol.ten,
      SlotSymbol.wild,
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0d0806),
      appBar: AppBar(
        backgroundColor: const Color(0xCC150a05),
        foregroundColor: const Color(0xFFFFD17A),
        title: const Text(
          'PAYTABLE & LINES',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const _SectionTitle(text: 'SYMBOL PAYOUTS'),
          const SizedBox(height: 6),
          const Text(
            'Payouts shown per 1 FUNS bet-per-line, for 3 / 4 / 5 matching '
            'symbols from the leftmost reel.',
            style: TextStyle(color: Color(0xBBFFE2A8), fontSize: 11),
          ),
          const SizedBox(height: 10),
          for (final s in paying) _PayRow(symbol: s),
          const SizedBox(height: 10),
          const _SpecialTile(
            icon: SlotSymbol.bonus,
            title: 'BONUS',
            body:
                '3+ BONUS symbols anywhere trigger free spins: '
                '3 → 5 spins, 4 → 8 spins, 5 → 12 spins. '
                'Three bonus symbols during the free spins retrigger extra '
                'spins. On the final free spin, all WILDs collected during '
                'the round are sprinkled onto the grid.',
          ),
          const SizedBox(height: 10),
          const _SpecialTile(
            icon: SlotSymbol.wild,
            title: 'WILD',
            body:
                'Substitutes for every symbol except BONUS. Three or more '
                'WILDs in a row pay as the top symbol.',
          ),
          const SizedBox(height: 20),
          const _SectionTitle(text: '20 PAYLINES'),
          const SizedBox(height: 8),
          _PaylineGrid(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66FF8A1A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFF2C8),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.symbol});
  final SlotSymbol symbol;

  @override
  Widget build(BuildContext context) {
    final pays = payTable[symbol] ?? const {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xCC150a05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4a2510)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: SymbolTile(symbol: symbol),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbolMeta[symbol]?.label ?? '',
                    style: const TextStyle(
                      color: Color(0xFFFFD17A),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _PayCell(count: 3, pay: pays[3] ?? 0),
                      const SizedBox(width: 6),
                      _PayCell(count: 4, pay: pays[4] ?? 0),
                      const SizedBox(width: 6),
                      _PayCell(count: 5, pay: pays[5] ?? 0),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayCell extends StatelessWidget {
  const _PayCell({required this.count, required this.pay});
  final int count;
  final double pay;

  @override
  Widget build(BuildContext context) {
    final value = pay * rtpBalancingMultiplier;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2a1507),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4a2510)),
        ),
        child: Column(
          children: [
            Text(
              '${count}×',
              style: const TextStyle(
                color: Color(0xBBFFE2A8),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(
                color: Color(0xFFFFF2C8),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialTile extends StatelessWidget {
  const _SpecialTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final SlotSymbol icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB638)),
        boxShadow: const [
          BoxShadow(color: Color(0x55FF8A1A), blurRadius: 12),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: SymbolTile(symbol: icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFF2C8),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xBBFFE2A8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaylineGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: paylines.length,
      itemBuilder: (_, i) => _PaylineTile(index: i, line: paylines[i]),
    );
  }
}

class _PaylineTile extends StatelessWidget {
  const _PaylineTile({required this.index, required this.line});
  final int index;
  final List<int> line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4a2510)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '#${index + 1}',
              style: const TextStyle(
                color: Color(0xFFFFD17A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: AspectRatio(
              aspectRatio: 5 / 3,
              child: CustomPaint(
                painter: _MiniLinePainter(line: line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  _MiniLinePainter({required this.line});
  final List<int> line;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 5;
    final cellH = size.height / 3;

    // Grid cells.
    final cellPaint = Paint()..color = const Color(0xFF2a1507);
    final borderPaint = Paint()
      ..color = const Color(0xFF4a2510)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var r = 0; r < 5; r++) {
      for (var row = 0; row < 3; row++) {
        final rect = Rect.fromLTWH(
          r * cellW + 1,
          row * cellH + 1,
          cellW - 2,
          cellH - 2,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)), cellPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            borderPaint);
      }
    }

    // Payline + nodes.
    final linePaint = Paint()
      ..color = const Color(0xFFFFB638)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()..color = const Color(0xFFFFF2C8);
    final path = Path();
    for (var r = 0; r < line.length; r++) {
      final cx = r * cellW + cellW / 2;
      final cy = line[r] * cellH + cellH / 2;
      if (r == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var r = 0; r < line.length; r++) {
      final cx = r * cellW + cellW / 2;
      final cy = line[r] * cellH + cellH / 2;
      canvas.drawCircle(Offset(cx, cy), 3.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) =>
      oldDelegate.line != line;
}
