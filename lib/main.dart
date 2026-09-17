import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/circles/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() {
  runApp(const ProviderScope(child: AjoseApp()));
}

class AjoseApp extends StatelessWidget {
  const AjoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ajose',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _RootRouter(),
    );
  }
}

/// Routes to Onboarding or Home based on whether a wallet session could be
/// (re)established. [WalletSessionNotifier.build] runs `reauthorize()`
/// against any persisted auth token on startup, so a returning user skips
/// straight to Home without seeing the connect button again.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(walletSessionProvider);

    return sessionState.when(
      data: (session) => session != null ? const HomeScreen() : const OnboardingScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Silent-reauthorize failures still land here as data(null) inside
      // WalletService, but guard the unexpected-error case too.
      error: (_, _) => const OnboardingScreen(),
    );
  }
}
