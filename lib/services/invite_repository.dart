import '../models/circle.dart';
import '../models/invite.dart';

/// Resolves an invite code to a [CircleInvite] preview. Today that's
/// [MockInviteRepository] (every code resolves to the same demo invite);
/// once invites are real (an on-chain PDA or an off-chain link service),
/// an implementation here does the actual lookup — the Join Via Invite
/// screen doesn't change.
abstract class InviteRepository {
  Future<CircleInvite?> resolveCode(String code);
}

class MockInviteRepository implements InviteRepository {
  @override
  Future<CircleInvite?> resolveCode(String code) async {
    if (code.trim().isEmpty) return null;
    return _buildDemoInvite();
  }

  static CircleInvite _buildDemoInvite() {
    final now = DateTime.now();
    const frequency = ContributionFrequency.weekly;
    const currentTurn = 5;
    const yourTurn = 6;

    DateTime dateForTurn(int turn) => now.add(frequency.interval * (turn - currentTurn));

    // Every seat gets a turnDate, even already-completed ones — the slot
    // swap sheet needs a date for any seat someone might still propose
    // swapping into, and it's harmless for the ones it doesn't.
    final seats = [
      InviteSeat(turnNumber: 1, status: SeatStatus.completed, memberName: 'Dapo Williams', turnDate: dateForTurn(1)),
      InviteSeat(turnNumber: 2, status: SeatStatus.completed, memberName: 'Folake M.', turnDate: dateForTurn(2)),
      InviteSeat(turnNumber: 3, status: SeatStatus.completed, memberName: 'Babatunde C.', turnDate: dateForTurn(3)),
      InviteSeat(turnNumber: 4, status: SeatStatus.completed, memberName: 'Kemi A.', turnDate: dateForTurn(4)),
      InviteSeat(turnNumber: 5, status: SeatStatus.current, memberName: 'Chidi O.', turnDate: dateForTurn(5)),
      InviteSeat(turnNumber: 6, status: SeatStatus.reservedForYou, turnDate: dateForTurn(6)),
      InviteSeat(turnNumber: 7, status: SeatStatus.completed, memberName: 'Zainab M.', turnDate: dateForTurn(7)),
      InviteSeat(turnNumber: 8, status: SeatStatus.open, turnDate: dateForTurn(8)),
    ];

    return CircleInvite(
      code: 'DEMO',
      circleCategory: 'Family Ajo Savings',
      circleName: 'Family & Cousins Pot',
      inviterName: 'Dapo Williams',
      inviterReliabilityLabel: '100% on-time payouts',
      contributionAmountUsdc: 100,
      frequency: frequency,
      yourTurnNumber: yourTurn,
      // Joining mid-cycle: your first contribution is due partway through
      // the current round, well before your own turn's payout lands.
      firstContributionDueDate: now.add(Duration(days: (frequency.interval.inDays / 2).round())),
      seats: seats,
    );
  }
}
