import 'package:flutter/material.dart';

import '../game/quests.dart';
import 'game_screen.dart';
import 'paytable_screen.dart';
import 'quests_screen.dart';
import 'webview_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Holy_Machine_additional_assets/Vertical_Loading_Screen.webp',
            fit: BoxFit.cover,
            cacheWidth: 1080,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 10),
                  const _CurrencyBanner(),
                  const Spacer(),
                  _PlayButton(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const GameScreen(),
                          transitionDuration:
                              const Duration(milliseconds: 400),
                          transitionsBuilder: (_, animation, __, child) =>
                              FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _LinkButton(
                          label: 'PAYTABLE',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PaytableScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuestsButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LinkButton(
                          label: 'PRIVACY POLICY',
                          onTap: () => _openWebView(
                            context,
                            title: 'Privacy Policy',
                            url:
                                'https://hollymachine.com/privacy-policy.html',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LinkButton(
                          label: 'SUPPORT',
                          onTap: () => _openWebView(
                            context,
                            title: 'Support',
                            url: 'https://hollymachine.com/support.html',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWebView(BuildContext context,
      {required String title, required String url}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }
}

class _CurrencyBanner extends StatelessWidget {
  const _CurrencyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC150a05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF8A1A), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x66FF7A00), blurRadius: 14),
        ],
      ),
      child: const Text(
        'FUNS • NOT REAL MONEY',
        style: TextStyle(
          color: Color(0xFFFFD17A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 10 + 14 * _pulse.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 220,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD17A),
                  Color(0xFFFF8A1A),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFF2C8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A1A).withValues(alpha: 0.75),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PLAY',
              style: TextStyle(
                color: Color(0xFF401500),
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 6,
                shadows: [
                  Shadow(color: Color(0x66FFFFFF), blurRadius: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuestsButton extends StatefulWidget {
  @override
  State<_QuestsButton> createState() => _QuestsButtonState();
}

class _QuestsButtonState extends State<_QuestsButton> {
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _LinkButton(
          label: 'QUESTS',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuestsScreen(),
            ),
          ),
        ),
        if (unclaimed > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4500),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFF2C8), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FF4500), blurRadius: 10),
                ],
              ),
              child: Text(
                '$unclaimed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF8A1A), width: 1),
          color: const Color(0xB3100805),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFD17A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
