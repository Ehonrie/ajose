import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../circles/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../savings/savings_screen.dart';

/// The app's persistent tab shell — Circles, Savings, Activity, Profile.
/// Owns the bottom nav bar directly (rather than each tab having its own),
/// so it stays on screen and genuinely tracks whichever tab is showing, as
/// opposed to the old setup where only Circles had a nav bar at all and
/// the other three were full-screen pushes that covered it entirely.
///
/// Each tab keeps its own `Scaffold` (AppBar, FAB, etc.) nested inside this
/// shell's `IndexedStack` — only the bottom nav itself is hoisted up to the
/// outer `Scaffold`, so nothing about an individual tab's own layout had to
/// change. Drilling into a detail screen (a circle, Create Circle, a
/// savings target) still uses the app's normal root `Navigator.push` and
/// covers the shell entirely, same as before — the nav bar is fixed across
/// the four top-level tabs, not glued to every screen underneath them.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    SavingsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            // IndexedStack keeps every tab mounted, just hidden — without
            // this, a background tab's own timers (AutoSettleTicker, one
            // per active circle on Home) keep firing and can pop a dialog
            // from a tab the user isn't looking at, colliding with
            // whatever dialog they're actually interacting with on the
            // visible tab. TickerMode doesn't stop a raw Timer by itself;
            // AutoSettleTicker checks it explicitly before acting.
            TickerMode(enabled: i == _index, child: _tabs[i]),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomNavDestination {
  const _BottomNavDestination(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _destinations = [
  _BottomNavDestination(Icons.group_work_outlined, Icons.group_work, 'Circles'),
  _BottomNavDestination(Icons.savings_outlined, Icons.savings_rounded, 'Savings'),
  _BottomNavDestination(Icons.dynamic_feed_outlined, Icons.dynamic_feed, 'Activity'),
  _BottomNavDestination(Icons.person_outline, Icons.person, 'Profile'),
];

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceCard,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _destinations.length; i++)
                _NavItem(
                  destination: _destinations[i],
                  selected: i == currentIndex,
                  scheme: scheme,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final _BottomNavDestination destination;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryFixed.withValues(alpha: 0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(selected ? destination.activeIcon : destination.icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
