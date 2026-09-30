import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/solana.dart';

import '../../core/mwa_session_manager.dart';
import '../../core/providers.dart';
import '../../services/wallet_service.dart';

/// Bottom sheet allowing the user to transfer SOL directly from their connected
/// wallet using the Mobile Wallet Adapter (MWA 2.0).
class SendSolSheet extends ConsumerStatefulWidget {
  const SendSolSheet({
    super.key,
    required this.session,
    this.initialRecipient,
  });

  final WalletSession session;
  final String? initialRecipient;

  static Future<void> show(
    BuildContext context,
    WalletSession session, {
    String? initialRecipient,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SendSolSheet(
          session: session,
          initialRecipient: initialRecipient,
        ),
      ),
    );
  }

  @override
  ConsumerState<SendSolSheet> createState() => _SendSolSheetState();
}

class _SendSolSheetState extends ConsumerState<SendSolSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipientController;
  final _amountController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  static const _deployerAddress = 'FzsFMB2TW3bRCyh1YkFb3Pagggo2aouzVA8ZeXkJDH2X';

  @override
  void initState() {
    super.initState();
    _recipientController = TextEditingController(
      text: widget.initialRecipient ?? '',
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pasteRecipient() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      _recipientController.text = data!.text!.trim();
      setState(() => _errorMessage = null);
    }
  }

  void _setMaxAmount(double availableSol) {
    // Leave at least 0.005 SOL for network fees and rent
    final maxSendable = (availableSol - 0.005).clamp(0.0, double.infinity);
    _amountController.text = maxSendable > 0 ? maxSendable.toStringAsFixed(4) : '0';
    setState(() => _errorMessage = null);
  }

  Future<void> _submitTransfer(double availableSol) async {
    if (!_formKey.currentState!.validate()) return;

    final recipientStr = _recipientController.text.trim();
    final amountSol = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amountSol <= 0) {
      setState(() => _errorMessage = 'Please enter an amount greater than 0');
      return;
    }

    if (amountSol > availableSol) {
      setState(() => _errorMessage = 'Insufficient SOL balance');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final recipientPubkey = Ed25519HDPublicKey.fromBase58(recipientStr);
      final rpc = ref.read(rpcServiceProvider);
      final walletService = ref.read(walletServiceProvider);

      // 1. Fetch recent blockhash from RPC
      final blockhash = await rpc.getLatestBlockhash();

      // 2. Build the transfer transaction with zero-signature placeholder
      final lamports = (amountSol * lamportsPerSol).round();
      final txBytes = rpc.buildTransferTransaction(
        from: widget.session.publicKey,
        to: recipientPubkey,
        lamports: lamports,
        recentBlockhash: blockhash,
      );

      // 3. Request signature and broadcast via Mobile Wallet Adapter
      final signature = await walletService.signAndSendTransaction(
        widget.session,
        txBytes,
      );

      // 4. Refresh balances
      ref.invalidate(walletBalancesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessDialog(context, signature, amountSol, recipientStr);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is WalletException ? e.message : 'Transfer failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog(
    BuildContext context,
    String signature,
    double amount,
    String recipient,
  ) {
    final truncatedSig = signature.length > 16
        ? '${signature.substring(0, 8)}…${signature.substring(signature.length - 8)}'
        : signature;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Transfer Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent ${amount.toStringAsFixed(4)} SOL successfully on Devnet.'),
            const SizedBox(height: 12),
            Text(
              'To: ${recipient.substring(0, 4)}…${recipient.substring(recipient.length - 4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: signature));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signature copied to clipboard')),
                );
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tx: $truncatedSig',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  const Icon(Icons.copy, size: 16, color: Colors.blueAccent),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(walletBalancesProvider);
    final availableSol = balancesAsync.value?.sol ?? 0.0;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.send_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Send SOL (Devnet)', style: textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Available: ${availableSol.toStringAsFixed(4)} SOL',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _recipientController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  hintText: 'Solana Devnet Base58 Address',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.paste, size: 20),
                        tooltip: 'Paste',
                        onPressed: _isSubmitting ? null : _pasteRecipient,
                      ),
                    ],
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a recipient address';
                  }
                  final trimmed = val.trim();
                  try {
                    Ed25519HDPublicKey.fromBase58(trimmed);
                  } catch (_) {
                    return 'Invalid Solana address';
                  }
                  if (trimmed == widget.session.address) {
                    return 'Cannot send to your own address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.flash_on, size: 16),
                    label: const Text('CLI Deployer'),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            _recipientController.text = _deployerAddress;
                            setState(() => _errorMessage = null);
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                enabled: !_isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (SOL)',
                  hintText: '0.0',
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: _isSubmitting ? null : () => _setMaxAmount(availableSol),
                    child: const Text('MAX'),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  if (parsed > availableSol) {
                    return 'Amount exceeds available balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.5, 1.0, 2.0].map((amt) {
                  return ActionChip(
                    label: Text('$amt SOL'),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            _amountController.text = amt.toString();
                            setState(() => _errorMessage = null);
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitTransfer(availableSol),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting
                        ? 'Awaiting Wallet Approval…'
                        : 'Send via Wallet',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
