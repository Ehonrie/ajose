import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/onboarding/splash_view.dart';

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
      // SplashView owns the Onboarding-vs-Home routing decision: it awaits
      // walletSessionProvider's initial resolution, then replaces itself.
      home: const SplashView(),
    );
  }
}
