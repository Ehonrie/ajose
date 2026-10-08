import 'dart:convert';
import 'dart:typed_data';

import 'package:borsh_annotation/borsh_annotation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:solana/solana.dart';

import '../models/savings_target.dart' as model;

/// Decodes the `ajose` Anchor program's `SavingsTarget` account into the
/// app's [model.SavingsTarget], mirroring the Rust layout in
/// `programs/ajose/src/state/mod.rs` exactly — same hand-rolled approach as
/// `CircleAccountCodec`, since there's no Anchor client generator for Dart.
class SavingsAccountCodec {
  SavingsAccountCodec._();

  static final List<int> _discriminator =
      crypto.sha256.convert(utf8.encode('account:SavingsTarget')).bytes.sublist(0, 8);

  static bool isSavingsAccount(List<int> data) {
    if (data.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (data[i] != _discriminator[i]) return false;
    }
    return true;
  }

  /// Decodes raw account bytes (including the 8-byte discriminator) for the
  /// account at [address]. [balanceUsdc] is read separately from the
  /// target's vault (a live token balance, not part of this account's own
  /// data) and passed in rather than fetched here, so one network round
  /// trip can be shared across a whole list read.
  static model.SavingsTarget decode(
    List<int> data, {
    required String address,
    required double balanceUsdc,
  }) {
    final reader = BinaryReader(
      ByteData.sublistView(Uint8List.fromList(data.sublist(8))),
    );

    final owner = _readPubkey(reader);
    final label = reader.readString();
    reader.readFixedArray(32, reader.readU8); // usdc_mint — unused here
    final targetAmountBaseUnits = reader.readU64().toInt();
    final unlockAt = _readI64(reader);
    reader.readU8(); // vault_bump — unused here
    final createdAt = _readI64(reader);

    return model.SavingsTarget(
      id: address,
      owner: owner.toBase58(),
      label: label,
      targetAmountUsdc: targetAmountBaseUnits / _usdcBaseUnitsPerToken,
      unlockAt: DateTime.fromMillisecondsSinceEpoch(unlockAt * 1000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      balanceUsdc: balanceUsdc,
    );
  }

  static Ed25519HDPublicKey _readPubkey(BinaryReader reader) {
    return Ed25519HDPublicKey(reader.readFixedArray(32, reader.readU8));
  }

  // BinaryReader has no signed-64-bit reader; its `buf`/`offset` fields are
  // public, so read the bytes directly rather than reimplementing a cursor.
  static int _readI64(BinaryReader reader) {
    final value = reader.buf.getInt64(reader.offset, Endian.little);
    reader.offset += 8;
    return value;
  }

  static const int _usdcBaseUnitsPerToken = 1000000;
}
