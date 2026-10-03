import 'dart:convert';
import 'dart:typed_data';

import 'package:borsh_annotation/borsh_annotation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:solana/solana.dart';

import '../models/circle.dart' as model;

/// Decodes the `ajose` Anchor program's `Circle` account into the app's
/// [model.Circle]/[model.Member] shapes, mirroring the Rust layout in
/// `programs/ajose/src/state/mod.rs` exactly (there's no Anchor client
/// generator for Dart, so this is done by hand — same reasoning as
/// `AnchorService`'s manual instruction encoding).
class CircleAccountCodec {
  CircleAccountCodec._();

  static final List<int> _discriminator =
      crypto.sha256.convert(utf8.encode('account:Circle')).bytes.sublist(0, 8);

  /// True if [data] starts with the `Circle` account's 8-byte discriminator
  /// — used to skip any other account type a program-wide scan might return.
  static bool isCircleAccount(List<int> data) {
    if (data.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (data[i] != _discriminator[i]) return false;
    }
    return true;
  }

  /// Decodes raw account bytes (including the 8-byte discriminator) for the
  /// account at [address] into a [model.Circle].
  static model.Circle decode(List<int> data, {required String address}) {
    // Slice the discriminator off *before* wrapping, not via a nonzero
    // ByteData view offset: BinaryReader's readString()/readU64() read
    // through `buf.buffer.asUint8List()`, which returns the whole backing
    // buffer regardless of the view's own start offset — combined with a
    // view that starts partway in, that silently reads 8 bytes too early.
    final reader = BinaryReader(
      ByteData.sublistView(Uint8List.fromList(data.sublist(8))),
    );

    reader.readFixedArray(32, reader.readU8); // authority — recovered via seat 0 instead
    final name = reader.readString();
    reader.readFixedArray(32, reader.readU8); // usdc_mint — unused here
    final contributionAmountBaseUnits = reader.readU64().toInt();
    final frequencyIndex = reader.readU8();
    final memberCount = reader.readU32();
    final members = List.generate(memberCount, (i) => _readMemberSeat(reader, i));
    final currentRoundIndex = reader.readU16();
    final currentRoundDeadline = _readI64(reader);
    // vault_bump (u8) and created_at (i64) follow but aren't needed by the UI.

    final deadline = DateTime.fromMillisecondsSinceEpoch(currentRoundDeadline * 1000);

    return model.Circle(
      id: address,
      name: name,
      members: members,
      contributionAmountUsdc: contributionAmountBaseUnits / _usdcBaseUnitsPerToken,
      frequency: model.ContributionFrequency.values[frequencyIndex],
      nextRoundDate: deadline,
      currentRoundDeadline: deadline,
      currentRoundIndex: currentRoundIndex,
    );
  }

  /// Whether [ownerPubkey] (base58) occupies any seat in this circle,
  /// including as its creator/authority (always seat 0).
  static bool isMember(model.Circle circle, String ownerPubkey) {
    return circle.members.any((m) => m.pubkey == ownerPubkey);
  }

  static model.Member _readMemberSeat(BinaryReader reader, int index) {
    final hasWallet = reader.readU8() == 1;
    final wallet = hasWallet ? _readPubkey(reader) : null;
    final payoutPosition = reader.readU16();
    final statusIndex = reader.readU8();
    final hasPaidAt = reader.readU8() == 1;
    final paidAt = hasPaidAt ? _readI64(reader) : null;

    return model.Member(
      // An open (unclaimed) seat has no on-chain identity yet; represented
      // as an empty pubkey with a distinct display name rather than adding
      // an "unclaimed" concept to the shared Member model every screen reads.
      pubkey: wallet?.toBase58() ?? '',
      displayName: wallet != null ? '${wallet.toBase58().substring(0, 4)}…' : 'Open seat',
      payoutPosition: payoutPosition,
      status: model.MemberPaymentStatus.values[statusIndex],
      paidAt: paidAt != null ? DateTime.fromMillisecondsSinceEpoch(paidAt * 1000) : null,
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
