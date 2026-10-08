/// A personal, time-locked USDC savings vault — mirrors the deployed
/// Anchor program's `SavingsTarget` account. Unrelated to circles: no
/// rotation, no other members, just a label, an unlock date, and a balance
/// that only [owner] can deposit into (anytime) or withdraw from (only
/// once [unlockAt] has passed).
library;

class SavingsTarget {
  const SavingsTarget({
    required this.id,
    required this.owner,
    required this.label,
    required this.targetAmountUsdc,
    required this.unlockAt,
    required this.createdAt,
    required this.balanceUsdc,
  });

  /// On-chain account address.
  final String id;

  /// Owner's wallet address (base58) — the only wallet that can deposit
  /// into or withdraw from this target.
  final String owner;

  final String label;

  /// A goal to visualize progress toward. Zero means no specific goal —
  /// just a locked jar with a free-form balance.
  final double targetAmountUsdc;

  final DateTime unlockAt;
  final DateTime createdAt;

  /// Not stored on the `SavingsTarget` account itself — read separately
  /// from its vault's live token balance, so it's never stale relative to
  /// the account fields decoded alongside it.
  final double balanceUsdc;

  bool get isUnlocked => !unlockAt.isAfter(DateTime.now());

  bool get hasGoal => targetAmountUsdc > 0;

  /// Fraction of [targetAmountUsdc] saved so far, clamped to 1. Only
  /// meaningful when [hasGoal] is true.
  double get progress => hasGoal ? (balanceUsdc / targetAmountUsdc).clamp(0.0, 1.0) : 0.0;
}
