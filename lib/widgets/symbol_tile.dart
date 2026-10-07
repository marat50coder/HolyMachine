import 'package:flutter/material.dart';

import '../game/slot_config.dart';

class SymbolTile extends StatelessWidget {
  const SymbolTile({
    super.key,
    required this.symbol,
    this.highlighted = false,
    this.dimmed = false,
  });

  final SlotSymbol symbol;
  final bool highlighted;
  final bool dimmed;

  /// Artwork has different transparent margins. We render each symbol so its
  /// opaque content fills ~98% of the cell (same visual size for BONUS, WILD
  /// and plain card ranks).
  double get _fillScale {
    switch (symbol) {
      case SlotSymbol.bonus:
        return 1.30;
      case SlotSymbol.wild:
        return 1.18;
      case SlotSymbol.basket:
      case SlotSymbol.boxes:
      case SlotSymbol.laptop:
      case SlotSymbol.sneaker:
      case SlotSymbol.headphones:
      case SlotSymbol.watch:
        return 1.14;
      default:
        return 1.06;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = symbolMeta[symbol]!;
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final paintedSize = Size(size.width * _fillScale,
            size.height * _fillScale);
        return ColoredBox(
          color: const Color(0xFF0a0604),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              Opacity(
                opacity: dimmed ? 0.35 : 1,
                child: SizedBox(
                  width: paintedSize.width,
                  height: paintedSize.height,
                  child: Image.asset(
                    meta.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              if (highlighted)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFFFB638), width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xAAFF8A1A), blurRadius: 14),
                      ],
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
