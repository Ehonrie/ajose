import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mwa_session_manager.dart';
import '../../core/providers.dart';
import '../circles/home_screen.dart';
import 'onboarding_screen.dart';

/// First thing shown on launch: brand mark on the icon's own background
/// while [walletSessionProvider] resolves (always to null — no wallet
/// session is restored automatically), then routes to Onboarding.
///
/// Replaces the bare `CircularProgressIndicator` that used to cover this gap
/// in `_RootRouter` — same routing decision, just branded, and with a
/// minimum on-screen duration so it doesn't just flash by.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  static const _logoAsset = 'assets/images/logo.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_logoAsset), context);
      _restoreSessionAndNavigate();
    });
  }

  Future<void> _restoreSessionAndNavigate() async {
    final stopwatch = Stopwatch()..start();

    // Same provider _RootRouter used to watch — this always resolves to
    // null (see walletSessionProvider.build), so the catch below is only
    // for the unexpected-error case the old router also guarded.
    WalletSession? session;
    try {
      session = await ref.read(walletSessionProvider.future);
    } catch (_) {
      session = null;
    }

    // Ensure a smooth minimum splash duration for branding.
    const minDuration = Duration(milliseconds: 1200);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => session != null ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // Matches the app icon artwork's own background exactly, so the
        // square asset blends into the screen with no visible edge.
        backgroundColor: const Color(0xFF082819),
        body: const Center(
          child: Image(image: AssetImage(_logoAsset), width: 100, height: 100),
        ),
      ),
    );
  }
}
