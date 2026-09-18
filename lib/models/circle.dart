/// Data shapes for a rotating savings circle ("ajo"/"esusu"/"tanda"-style
/// pool). These mirror how the eventual Anchor program will most likely lay
/// out its accounts:
///
///   Circle account  -> one per circle (name, mint, contribution amount,
///                       cadence, member list / member PDAs, current round)
///   Member          -> one per seat in the circle (owner pubkey, whether
///                       they've paid the current round, payout position)
///
/// Keeping that shape now — even while every value comes from
/// [MockCircleRepository] — means the swap to real on-chain reads later is
/// just a new [CircleRepository] implementation that deserializes account
/// data into these same classes, not a rewrite of every screen that
/// consumes them.
library;

enum ContributionFrequency {
  weekly,
  biweekly,
  monthly;

  /// Roughly how long one round lasts — used to derive display dates
  /// (e.g. when the round *after* the current one lands) without a
  /// separate stored field.
  Duration get interval => switch (this) {
        ContributionFrequency.weekly => const Duration(days: 7),
        ContributionFrequency.biweekly => const Duration(days: 14),
        ContributionFrequency.monthly => const Duration(days: 30),
      };
}

/// Whether a member has settled their contribution for the *current* round.
/// [pending] and [overdue] are both "not yet paid" — [overdue] specifically
/// means the round deadline has passed, which the UI surfaces differently
/// (a status-overdue color, a "reminder sent" note) than a simple pending
/// state.
enum MemberPaymentStatus { paid, pending, overdue }

class Member {
  const Member({
    required this.pubkey,
    required this.displayName,
    required this.payoutPosition,
    this.status = MemberPaymentStatus.pending,
    this.paidAt,
    this.isCurrentUser = false,
  });

  /// Base58 wallet address. This is the on-chain identity; [displayName] is
  /// purely local/off-chain (from contacts or a nickname set at invite
  /// time) since the chain has no notion of names.
  final String pubkey;
  final String displayName;

  /// Zero-based turn order — which round this member receives the payout.
  final int payoutPosition;

  final MemberPaymentStatus status;

  /// When this member paid their current-round contribution. Null unless
  /// [status] is [MemberPaymentStatus.paid].
  final DateTime? paidAt;

  /// Whether this seat belongs to the connected wallet. Real reads will set
  /// this by comparing [pubkey] to the authorized session's address; mock
  /// data just flags one seat per circle directly.
  final bool isCurrentUser;

  bool get hasPaidCurrentRound => status == MemberPaymentStatus.paid;

  String get truncatedPubkey {
    if (pubkey.length <= 10) return pubkey;
    return '${pubkey.substring(0, 4)}…${pubkey.substring(pubkey.length - 4)}';
  }

  Member copyWith({MemberPaymentStatus? status, DateTime? paidAt}) => Member(
        pubkey: pubkey,
        displayName: displayName,
        payoutPosition: payoutPosition,
        status: status ?? this.status,
        paidAt: paidAt ?? this.paidAt,
        isCurrentUser: isCurrentUser,
      );
}

class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.members,
    required this.contributionAmountUsdc,
    required this.frequency,
    required this.nextRoundDate,
    required this.currentRoundIndex,
    required this.currentRoundDeadline,
  });

  /// On-chain circle account address once real reads land; a stable mock
  /// id for now.
  final String id;
  final String name;
  final List<Member> members;
  final double contributionAmountUsdc;
  final ContributionFrequency frequency;

  /// Next time something happens for this circle worth surfacing in a
  /// summary list — in practice the same moment as [currentRoundDeadline].
  final DateTime nextRoundDate;

  /// Index into [members] identifying whose turn it is to receive the pot
  /// this round.
  final int currentRoundIndex;

  /// When the current round's contribution window closes.
  final DateTime currentRoundDeadline;

  int get totalRounds => members.length;

  /// 1-based, for display ("Round 5 of 8").
  int get currentRoundNumber => currentRoundIndex + 1;

  Member get currentRecipient => members[currentRoundIndex % members.length];

  /// Who receives the payout the round after this one.
  Member get nextRecipient => members[(currentRoundIndex + 1) % members.length];

  /// When [nextRecipient]'s round is expected to close.
  DateTime get followingRoundDeadline => currentRoundDeadline.add(frequency.interval);

  double get potTotalUsdc => contributionAmountUsdc * members.length;

  int get membersPaidThisRound => members.where((m) => m.hasPaidCurrentRound).length;

  /// Fraction of members who've paid this round — drives the deadline
  /// progress meter.
  double get roundProgress => members.isEmpty ? 0 : membersPaidThisRound / members.length;

  /// How far through the circle's full rotation this round is — drives the
  /// rotation-ring visual, distinct from [roundProgress].
  double get rotationProgress => totalRounds == 0 ? 0 : currentRoundNumber / totalRounds;

  /// The member seat belonging to the connected wallet, if this circle has
  /// one (mock data always does; real data will filter by pubkey).
  Member? get currentUserMember {
    for (final member in members) {
      if (member.isCurrentUser) return member;
    }
    return null;
  }
}
