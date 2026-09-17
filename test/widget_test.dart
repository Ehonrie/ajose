// Basic smoke test for the Onboarding screen. WalletSessionNotifier.build()
// talks to real platform channels (secure storage, MWA) that aren't mocked
// in the widget-test environment, so the provider is overridden directly
// here rather than booting the whole app and hoping session-restore fails
// fast — that's what an integration test against a real device is for.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ajose/core/mwa_session_manager.dart';
import 'package:ajose/core/providers.dart';
import 'package:ajose/core/theme.dart';
import 'package:ajose/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Shows a Connect Wallet button when no wallet session is active',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSessionProvider.overrideWith(() => _FakeWalletSessionNotifier()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect Wallet'), findsOneWidget);
    expect(find.text('Save together, grow together'), findsOneWidget);
  });
}

class _FakeWalletSessionNotifier extends WalletSessionNotifier {
  @override
  Future<WalletSession?> build() async => null;
}
