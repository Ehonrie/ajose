import 'package:flutter_test/flutter_test.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:ajose/services/rpc_service.dart';

void main() {
  test('RpcService builds a valid transfer wire transaction', () async {
    final rpcService = RpcService();
    final from = Ed25519HDPublicKey.fromBase58(
      'FzsFMB2TW3bRCyh1YkFb3Pagggo2aouzVA8ZeXkJDH2X',
    );
    final to = Ed25519HDPublicKey.fromBase58(
      'GBZqhLZXAjBtfeVkVWMYWFN8DGmxskwKna3UEXGvfh8P',
    );
    const fakeBlockhash = '6fTXmtjzPi6KZqjwFxdwezBKPDXEy2ejzNCfZFzivseJ';

    final txBytes = rpcService.buildTransferTransaction(
      from: from,
      to: to,
      lamports: 1000000,
      recentBlockhash: fakeBlockhash,
    );

    expect(txBytes, isNotEmpty);

    // Verify it deserializes back into a SignedTx
    final signedTx = SignedTx.fromBytes(txBytes);
    expect(signedTx.signatures.length, equals(1));
    expect(signedTx.signatures.first.bytes.length, equals(64));
    expect(signedTx.blockhash, equals(fakeBlockhash));
  });
}
