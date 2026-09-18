import '../models/circle.dart';

/// Everything the UI needs from "wherever circle data lives". Today that's
/// [MockCircleRepository]; once the Anchor program exists, an
/// `OnChainCircleRepository` implements this same interface by fetching and
/// deserializing program accounts via [RpcService] instead — a drop-in
/// swap behind whatever provider constructs a [CircleRepository], with no
/// changes needed in the screens that consume it.
abstract class CircleRepository {
  /// Circles [ownerPubkey] is a member of.
  Future<List<Circle>> getMyCircles(String ownerPubkey);

  Future<Circle?> getCircleById(String id);
}

/// Fake data standing in for on-chain circle accounts during this build
/// phase. Shapes match [Circle]/[Member] exactly so screens built against
/// this today keep working unchanged once a real repository lands.
class MockCircleRepository implements CircleRepository {
  MockCircleRepository() : _circles = _buildMockCircles();

  final List<Circle> _circles;

  @override
  Future<List<Circle>> getMyCircles(String ownerPubkey) async {
    // In this mock phase every circle "belongs" to whichever wallet is
    // connected, so the Home screen always has something to show.
    return List.unmodifiable(_circles);
  }

  @override
  Future<Circle?> getCircleById(String id) async {
    for (final circle in _circles) {
      if (circle.id == id) return circle;
    }
    return null;
  }

  static List<Circle> _buildMockCircles() {
    final now = DateTime.now();

    return [
      // Matches the Home screen design mockup's "Lagos Techies Seed Club"
      // card exactly: round 2 of 6, $250/2wk, fully funded (all 6 paid),
      // recipient Tunde B.
      Circle(
        id: 'mock-circle-1',
        name: 'Lagos Techies Seed Club',
        contributionAmountUsdc: 250,
        frequency: ContributionFrequency.biweekly,
        nextRoundDate: now.add(const Duration(days: 5)),
        currentRoundDeadline: now.add(const Duration(days: 5)),
        currentRoundIndex: 1,
        members: [
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55111111111111111',
            displayName: 'Zara K.',
            payoutPosition: 0,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 4)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55222222222222222',
            displayName: 'Tunde B.',
            payoutPosition: 1,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 3)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55333333333333333',
            displayName: 'Chioma A.',
            payoutPosition: 2,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 3)),
            isCurrentUser: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55444444444444444',
            displayName: 'Kayode M.',
            payoutPosition: 3,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 2)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55444444444444445',
            displayName: 'Ada N.',
            payoutPosition: 4,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 2)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55444444444444446',
            displayName: 'Biyi O.',
            payoutPosition: 5,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
      // Matches the "Circle Details" design mockup exactly: round 5 of 8,
      // $100/week, one recipient this round, one pending (the connected
      // user), one overdue.
      Circle(
        id: 'mock-circle-3',
        name: 'Family & Cousins Pot',
        contributionAmountUsdc: 100,
        frequency: ContributionFrequency.weekly,
        nextRoundDate: now.add(const Duration(days: 3, hours: 14)),
        currentRoundDeadline: now.add(const Duration(days: 3, hours: 14)),
        currentRoundIndex: 4,
        members: [
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55888888888888888',
            displayName: 'Folake Martins',
            payoutPosition: 0,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 3)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55999999999999999',
            displayName: 'Babatunde Cole',
            payoutPosition: 1,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 2)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55aaaaaaaaaaaaaaa',
            displayName: 'Kemi Adebayo',
            payoutPosition: 2,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 2)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55bbbbbbbbbbbbbbb',
            displayName: 'Chidi Okafor',
            payoutPosition: 3,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 1)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55ccccccccccccccc',
            displayName: 'Dapo Williams',
            payoutPosition: 4,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(days: 1)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55ddddddddddddddd',
            displayName: 'Amina Bello',
            payoutPosition: 5,
            isCurrentUser: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55eeeeeeeeeeeeeee',
            displayName: 'Zainab Musa',
            payoutPosition: 6,
            status: MemberPaymentStatus.paid,
            paidAt: now.subtract(const Duration(hours: 20)),
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55fffffffffffffff',
            displayName: 'Segun Arinze',
            payoutPosition: 7,
            status: MemberPaymentStatus.overdue,
          ),
        ],
      ),
    ];
  }
}
