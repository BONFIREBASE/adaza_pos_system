import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'sign_in_card.dart';

/// Branded landing flow (Req 9.1): the logo + trading name over the main
/// background fade out, then the sign-in modal emerges.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  static const _introDuration = Duration(milliseconds: 2600);

  bool _showLogin = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_introDuration, () {
      if (mounted) setState(() => _showLogin = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_main.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: AppColors.cream),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.cream.withValues(alpha: 0.45),
                  AppColors.cream.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 24,
            right: 24,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.18,
                child: Text(
                  'ADAZA',
                  style: TextStyle(
                    fontFamily: AppTheme.fontBrandOutline,
                    fontSize: 64,
                    color: AppColors.bronze,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _showLogin
                  ? const SignInCard(key: ValueKey('signin'))
                  : const _Intro(key: ValueKey('intro')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 480;
    final logoHeight = isCompact ? 180.0 : 280.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/adazalogo.png',
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'ADAZA',
                style: AppTheme.brand(
                  fontSize: isCompact ? 32 : 40,
                  letterSpacing: 8,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'POINT OF SALE SYSTEM',
            textAlign: TextAlign.center,
            style: AppTheme.brand(
              fontSize: isCompact ? 18 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.teal,
              letterSpacing: isCompact ? 3 : 5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Adaza School and Office Supplies Trading and Apparel',
            textAlign: TextAlign.center,
            style: AppTheme.brand(
              fontSize: isCompact ? 15 : 18,
              fontWeight: FontWeight.w600,
              color: AppColors.bronze,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
