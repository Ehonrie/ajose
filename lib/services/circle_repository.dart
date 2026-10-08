import 'package:solana/dto.dart';

import '../core/constants.dart';
import '../models/circle.dart';
import 'circle_account_codec.dart';
import 'rpc_service.dart';

/// Everything the UI needs from "wherever circle data lives". Implemented by
/// [OnChainCircleRepository], which fetches and deserializes `ajose`
/// program accounts via [RpcService].
abstract class CircleRepository {
  /// Circles [ownerPubkey] is a member of (including as creator — always
  /// seat 0).
  Future<List<Circle>> getMyCircles(String ownerPubkey);

  /// [viewerPubkey], if given, flags the matching member seat as
  /// [Member.isCurrentUser] — pass the connected wallet's address so
  /// "(You)" labels and paid-state gating keyed off [Circle.currentUserMember]
  /// work for a circle read by its address rather than via [getMyCircles].
  Future<Circle?> getCircleById(String id, {String? viewerPubkey});
}

/// Reads real `Circle` accounts from the deployed `ajose` Anchor program.
///
/// There's no account-indexing service, so [getMyCircles] scans every
/// account the program owns and decodes each one client-side — fine at this
/// app's current scale, but the first thing to replace with an indexed
/// query (e.g. by `authority`) if the number of circles ever grows large.
class OnChainCircleRepository implements CircleRepository {
  OnChainCircleRepository(this._rpc);

  final RpcService _rpc;

  @override
  Future<List<Circle>> getMyCircles(String ownerPubkey) async {
    final accounts = await _rpc.getProgramAccountsRaw(AppConfig.ajoseProgramId);
    final circles = <Circle>[];

    for (final account in accounts) {
      final data = account.account.data;
      if (data is! BinaryAccountData) continue;
      if (!CircleAccountCodec.isCircleAccount(data.data)) continue;

      try {
        final circle = CircleAccountCodec.decode(data.data, address: account.pubkey, viewerPubkey: ownerPubkey);
        if (CircleAccountCodec.isMember(circle, ownerPubkey)) {
          circles.add(circle);
        }
      } catch (_) {
        // A circle created under an older on-chain layout (e.g. before a
        // field was added to the account struct) won't match this
        // decoder's byte offsets. Rather than fail the whole list over one
        // now-unreadable account, skip it — on devnet that's just a
        // throwaway circle from before the last program upgrade.
        continue;
      }
    }

    return circles;
  }

  @override
  Future<Circle?> getCircleById(String id, {String? viewerPubkey}) async {
    final data = await _rpc.getAccountDataRaw(id);
    if (data == null || !CircleAccountCodec.isCircleAccount(data)) return null;
    try {
      return CircleAccountCodec.decode(data, address: id, viewerPubkey: viewerPubkey);
    } catch (_) {
      // Same older-layout case as getMyCircles — surface it as "not found"
      // rather than crashing the screen that requested it.
      return null;
    }
  }
}
