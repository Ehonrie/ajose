/// Data shapes for a rotating savings circle ("ajo"/"esusu"/"tanda"-style
/// pool), mirroring the deployed Anchor program's own account layout:
///
///   Circle account  -> one per circle (name, mint, contribution amount,
///                       cadence, member list, current round)
///   Member          -> one per seat in the circle (owner pubkey, whether
///                       they've paid the current round, payout position)
///
/// `OnChainCircleRepository` (in `services/circle_repository.dart`)
/// deserializes real account data straight into these classes, so every
/// screen built against them works unchanged regardless of where the data
/// came from.
library;

enum ContributionFrequency {
  weekly,
  biweekly,
  monthly,
  /// A 10-minute round. Appended last (not inserted) so its on-chain
  /// ordinal matches the Rust enum's — existing circles decode unaffected.
  /// Exists purely to exercise a circle's full lifecycle without waiting on
  /// a real cadence; not meant to be offered outside testing.
  testFast;

  /// Roughly how long one round lasts — used to derive display dates
  /// (e.g. when the round *after* the current one lands) without a
  /// separate stored field.
  Duration get interval => switch (this) {
        ContributionFrequency.weekly => const Duration(days: 7),
        ContributionFrequency.biweekly => const Duration(days: 14),
        ContributionFrequency.monthly => const Duration(days: 30),
        ContributionFrequency.testFast => const Duration(minutes: 10),
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
    this.bondPostedUsdc = 0,
    this.bondRemainingUsdc = 0,
    this.bondClaimed = false,
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

  /// What this seat originally posted as collateral — zero if the circle
  /// doesn't require it, or this seat hasn't posted yet.
  final double bondPostedUsdc;

  /// [bondPostedUsdc] minus whatever's since been forfeited to cover this
  /// member's own missed contributions. What `claim_collateral` actually
  /// pays out, once the circle's fully complete.
  final double bondRemainingUsdc;

  /// Whether this seat has already claimed its collateral back.
  final bool bondClaimed;

  bool get hasPaidCurrentRound => status == MemberPaymentStatus.paid;

  bool get hasPostedCollateral => bondPostedUsdc > 0;

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
        bondPostedUsdc: bondPostedUsdc,
        bondRemainingUsdc: bondRemainingUsdc,
        bondClaimed: bondClaimed,
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
    required this.createdAt,
    this.completedRounds = 0,
    this.lastPayoutRecipientPubkey,
    this.lastPayoutAmountUsdc = 0,
    this.lastPayoutAt,
    this.collateralAmountUsdc = 0,
  });

  /// On-chain circle account address.
  final String id;
  final String name;
  final List<Member> members;
  final double contributionAmountUsdc;
  final ContributionFrequency frequency;

  /// When this circle was launched — the on-chain account's own
  /// `created_at`. Drives the "Circle launched" entry in History.
  final DateTime createdAt;

  /// Next time something happens for this circle worth surfacing in a
  /// summary list — in practice the same moment as [currentRoundDeadline].
  final DateTime nextRoundDate;

  /// Index into [members] identifying whose turn it is to receive the pot
  /// this round.
  final int currentRoundIndex;

  /// When the current round's contribution window closes.
  final DateTime currentRoundDeadline;

  /// How many rounds have paid out so far. The circle has finished its one
  /// full rotation — every member paid exactly once — once this reaches
  /// `members.length`; see [isComplete].
  final int completedRounds;

  /// The most recent real on-chain payout, snapshotted by the program at
  /// the moment it fired (atomically with the contribution that completed
  /// that round). Null until the circle's first payout.
  final String? lastPayoutRecipientPubkey;
  final double lastPayoutAmountUsdc;
  final DateTime? lastPayoutAt;

  bool get hasPayoutHistory => lastPayoutAt != null;

  /// Required bond to hold a seat. Zero means this circle doesn't require
  /// collateral at all — entirely optional, set once at creation.
  final double collateralAmountUsdc;

  bool get requiresCollateral => collateralAmountUsdc > 0;

  /// Sum of what every member still has posted — what's actually left in
  /// the bond pool once any forfeitures and claims are accounted for.
  double get totalBondRemainingUsdc => members.fold(0, (sum, m) => sum + m.bondRemainingUsdc);

  /// The member who received [lastPayoutAmountUsdc], looked up by pubkey
  /// since the payout may belong to an earlier round than the one
  /// [currentRecipient] now points to.
  Member? get lastPayoutRecipientMember {
    final pubkey = lastPayoutRecipientPubkey;
    if (pubkey == null) return null;
    for (final member in members) {
      if (member.pubkey == pubkey) return member;
    }
    return null;
  }

  int get totalRounds => members.length;

  /// Whether every member has now received their payout once. Once true,
  /// the on-chain program itself rejects any further `contribute` calls.
  bool get isComplete => completedRounds >= members.length;

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
