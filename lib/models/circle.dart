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

enum ContributionFrequency { weekly, biweekly, monthly }

class Member {
  const Member({
    required this.pubkey,
    required this.displayName,
    required this.payoutPosition,
    this.hasPaidCurrentRound = false,
  });

  /// Base58 wallet address. This is the on-chain identity; [displayName] is
  /// purely local/off-chain (from contacts or a nickname set at invite
  /// time) since the chain has no notion of names.
  final String pubkey;
  final String displayName;

  /// Zero-based turn order — which round this member receives the payout.
  final int payoutPosition;

  final bool hasPaidCurrentRound;

  String get truncatedPubkey {
    if (pubkey.length <= 10) return pubkey;
    return '${pubkey.substring(0, 4)}…${pubkey.substring(pubkey.length - 4)}';
  }

  Member copyWith({bool? hasPaidCurrentRound}) => Member(
        pubkey: pubkey,
        displayName: displayName,
        payoutPosition: payoutPosition,
        hasPaidCurrentRound: hasPaidCurrentRound ?? this.hasPaidCurrentRound,
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
  });

  /// On-chain circle account address once real reads land; a stable mock
  /// id for now.
  final String id;
  final String name;
  final List<Member> members;
  final double contributionAmountUsdc;
  final ContributionFrequency frequency;
  final DateTime nextRoundDate;

  /// Index into [members] identifying whose turn it is to receive the pot
  /// this round.
  final int currentRoundIndex;

  Member get currentRecipient => members[currentRoundIndex % members.length];

  double get potTotalUsdc => contributionAmountUsdc * members.length;

  int get membersPaidThisRound => members.where((m) => m.hasPaidCurrentRound).length;
}
