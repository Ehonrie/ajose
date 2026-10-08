import 'dart:convert';

import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import '../core/constants.dart';
import '../models/savings_target.dart';
import 'savings_account_codec.dart';
import 'rpc_service.dart';

/// Reads real `SavingsTarget` accounts from the deployed `ajose` Anchor
/// program. Same shape and same "scan every account the program owns"
/// approach as `OnChainCircleRepository` — fine at this app's scale, first
/// thing to replace with an indexed query if it ever grows large.
class SavingsRepository {
  SavingsRepository(this._rpc);

  final RpcService _rpc;

  static final Ed25519HDPublicKey _programId =
      Ed25519HDPublicKey.fromBase58(AppConfig.ajoseProgramId);

  /// Savings targets owned by [ownerPubkey].
  Future<List<SavingsTarget>> getMySavingsTargets(String ownerPubkey) async {
    final accounts = await _rpc.getProgramAccountsRaw(AppConfig.ajoseProgramId);
    final targets = <SavingsTarget>[];

    for (final account in accounts) {
      final data = account.account.data;
      if (data is! BinaryAccountData) continue;
      if (!SavingsAccountCodec.isSavingsAccount(data.data)) continue;

      try {
        final savingsTargetPubkey = Ed25519HDPublicKey.fromBase58(account.pubkey);
        final balance = await _vaultBalance(savingsTargetPubkey);
        final target = SavingsAccountCodec.decode(
          data.data,
          address: account.pubkey,
          balanceUsdc: balance,
        );
        if (target.owner == ownerPubkey) {
          targets.add(target);
        }
      } catch (_) {
        // Same reasoning as OnChainCircleRepository: skip anything this
        // decoder can't read rather than failing the whole list.
        continue;
      }
    }

    targets.sort((a, b) => a.unlockAt.compareTo(b.unlockAt));
    return targets;
  }

  Future<SavingsTarget?> getSavingsTargetById(String id) async {
    final data = await _rpc.getAccountDataRaw(id);
    if (data == null || !SavingsAccountCodec.isSavingsAccount(data)) return null;
    try {
      final balance = await _vaultBalance(Ed25519HDPublicKey.fromBase58(id));
      return SavingsAccountCodec.decode(data, address: id, balanceUsdc: balance);
    } catch (_) {
      return null;
    }
  }

  /// The vault's live USDC balance — not stored on the `SavingsTarget`
  /// account itself, read from its vault PDA's associated token account.
  /// Zero (not an error) if nothing's been deposited yet, same convention
  /// as `RpcService.getUsdcBalance`.
  Future<double> _vaultBalance(Ed25519HDPublicKey savingsTargetPubkey) async {
    final vaultAuthority = await Ed25519HDPublicKey.findProgramAddress(
      seeds: [utf8.encode('savings_vault'), savingsTargetPubkey.bytes],
      programId: _programId,
    );
    return await _rpc.getUsdcBalance(vaultAuthority) ?? 0;
  }
}
