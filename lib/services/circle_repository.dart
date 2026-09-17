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
      Circle(
        id: 'mock-circle-1',
        name: 'Lagos Devs Ajo',
        contributionAmountUsdc: 50,
        frequency: ContributionFrequency.monthly,
        nextRoundDate: now.add(const Duration(days: 6)),
        currentRoundIndex: 1,
        members: const [
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55111111111111111',
            displayName: 'You',
            payoutPosition: 0,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55222222222222222',
            displayName: 'Amaka O.',
            payoutPosition: 1,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55333333333333333',
            displayName: 'Chidi N.',
            payoutPosition: 2,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55444444444444444',
            displayName: 'Femi A.',
            payoutPosition: 3,
          ),
        ],
      ),
      Circle(
        id: 'mock-circle-2',
        name: 'Solana Builders Circle',
        contributionAmountUsdc: 100,
        frequency: ContributionFrequency.biweekly,
        nextRoundDate: now.add(const Duration(days: 2)),
        currentRoundIndex: 0,
        members: const [
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55555555555555555',
            displayName: 'You',
            payoutPosition: 2,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55666666666666666',
            displayName: 'Priya S.',
            payoutPosition: 0,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55777777777777777',
            displayName: 'Marco D.',
            payoutPosition: 1,
          ),
        ],
      ),
      Circle(
        id: 'mock-circle-3',
        name: 'Family Contribution',
        contributionAmountUsdc: 25,
        frequency: ContributionFrequency.weekly,
        nextRoundDate: now.add(const Duration(days: 1)),
        currentRoundIndex: 3,
        members: const [
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55888888888888888',
            displayName: 'Mum',
            payoutPosition: 0,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55999999999999999',
            displayName: 'Dad',
            payoutPosition: 1,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55aaaaaaaaaaaaaaa',
            displayName: 'You',
            payoutPosition: 2,
            hasPaidCurrentRound: true,
          ),
          Member(
            pubkey: 'ExAmp1eBase58WaLLetAddre55bbbbbbbbbbbbbbb',
            displayName: 'Sis',
            payoutPosition: 3,
          ),
        ],
      ),
    ];
  }
}
