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

  Future<Circle?> getCircleById(String id);
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

      final circle = CircleAccountCodec.decode(data.data, address: account.pubkey);
      if (CircleAccountCodec.isMember(circle, ownerPubkey)) {
        circles.add(circle);
      }
    }

    return circles;
  }

  @override
  Future<Circle?> getCircleById(String id) async {
    final data = await _rpc.getAccountDataRaw(id);
    if (data == null || !CircleAccountCodec.isCircleAccount(data)) return null;
    return CircleAccountCodec.decode(data, address: id);
  }
}
