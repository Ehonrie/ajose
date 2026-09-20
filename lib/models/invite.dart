import 'circle.dart';

/// A rotation seat as previewed *before* joining — distinct from [Member]
/// because an invite preview needs states [Member] has no notion of: a
/// seat nobody has claimed yet ([SeatStatus.open]), and the seat reserved
/// for whoever is looking at this invite ([SeatStatus.reservedForYou]).
/// Once joined, a seat becomes a real [Member] with a wallet address.
enum SeatStatus { completed, current, reservedForYou, open }

class InviteSeat {
  const InviteSeat({
    required this.turnNumber,
    required this.status,
    this.memberName,
    this.turnDate,
  });

  /// 1-based position in the rotation.
  final int turnNumber;
  final SeatStatus status;

  /// Null only when [status] is [SeatStatus.open].
  final String? memberName;

  /// When this turn's payout lands. Shown for the viewer's own seat and
  /// for the still-open seat; omitted for turns already completed.
  final DateTime? turnDate;
}

/// A circle invite as resolved from a code — everything the Join Via
/// Invite screen needs to preview the circle before the viewer commits.
class CircleInvite {
  const CircleInvite({
    required this.code,
    required this.circleCategory,
    required this.circleName,
    required this.inviterName,
    required this.inviterReliabilityLabel,
    required this.contributionAmountUsdc,
    required this.frequency,
    required this.yourTurnNumber,
    required this.firstContributionDueDate,
    required this.seats,
  });

  final String code;

  /// A category label shown above the circle name (e.g. "Family Ajo
  /// Savings") — purely descriptive, not a stored on-chain field.
  final String circleCategory;
  final String circleName;
  final String inviterName;
  final String inviterReliabilityLabel;
  final double contributionAmountUsdc;
  final ContributionFrequency frequency;
  final int yourTurnNumber;
  final DateTime firstContributionDueDate;
  final List<InviteSeat> seats;

  int get totalSeats => seats.length;

  int get filledSeats => seats.where((s) => s.status == SeatStatus.completed || s.status == SeatStatus.current).length;

  double get lumpSumPayoutUsdc => contributionAmountUsdc * totalSeats;

  InviteSeat get yourSeat => seats.firstWhere((s) => s.turnNumber == yourTurnNumber);

  InviteSeat? get currentTurnSeat {
    for (final seat in seats) {
      if (seat.status == SeatStatus.current) return seat;
    }
    return null;
  }
}
