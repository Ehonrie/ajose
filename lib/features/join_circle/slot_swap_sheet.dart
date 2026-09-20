import 'package:flutter/material.dart';

import '../../core/date_formatting.dart';
import '../../core/initials_avatar.dart';
import '../../core/text_formatting.dart';
import '../../core/theme.dart';
import '../../models/invite.dart';
import 'slot_swap_sent_screen.dart';

const _kReasonChips = {
  'Need payout earlier': 'I need my payout earlier than scheduled.',
  'School tuition deadline': 'I have a school tuition deadline coming up.',
  'Travel schedule': 'My travel schedule conflicts with my current turn.',
};

/// Lets the invite's viewer propose swapping their reserved seat for the
/// still-open one (no approval needed) or for another member's seat
/// (needs that member to accept). Not wired to a backend — there's
/// nowhere real to send a swap request yet, so submitting shows a preview
/// confirmation and nothing is persisted.
Future<void> showSlotSwapSheet(BuildContext context, CircleInvite invite) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SlotSwapSheet(invite: invite),
  );
}

class _SlotSwapSheet extends StatefulWidget {
  const _SlotSwapSheet({required this.invite});

  final CircleInvite invite;

  @override
  State<_SlotSwapSheet> createState() => _SlotSwapSheetState();
}

class _SlotSwapSheetState extends State<_SlotSwapSheet> {
  late int _selectedTurn;
  late final TextEditingController _noteController;
  String? _selectedChip = 'Need payout earlier';
  bool _sending = false;
  bool _sent = false;

  CircleInvite get invite => widget.invite;
  InviteSeat get _yourSeat => invite.yourSeat;
  int get _currentTurnNumber => invite.currentTurnSeat!.turnNumber;

  List<InviteSeat> get _otherSeats =>
      invite.seats.where((s) => s.status != SeatStatus.reservedForYou).toList();

  InviteSeat get _openSeat => _otherSeats.firstWhere((s) => s.status == SeatStatus.open);

  List<InviteSeat> get _memberSeats => _otherSeats.where((s) => s.status != SeatStatus.open).toList()
    ..sort((a, b) => a.turnNumber.compareTo(b.turnNumber));

  bool _isEligible(InviteSeat s) => s.turnNumber >= _currentTurnNumber;

  InviteSeat get _selectedSeat => invite.seats.firstWhere((s) => s.turnNumber == _selectedTurn);

  @override
  void initState() {
    super.initState();
    final eligibleMembers = _memberSeats.where(_isEligible).toList();
    _selectedTurn = eligibleMembers.isNotEmpty ? eligibleMembers.first.turnNumber : _openSeat.turnNumber;
    _noteController = TextEditingController(text: _noteFor(_selectedSeat, _selectedChip!));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _noteFor(InviteSeat seat, String chipLabel) {
    final reason = _kReasonChips[chipLabel]!;
    if (seat.status == SeatStatus.open) return reason;
    return 'Hey ${firstName(seat.memberName!)}, would you mind swapping turns? $reason';
  }

  void _selectTurn(int turn) {
    setState(() {
      _selectedTurn = turn;
      if (_selectedChip != null) {
        final seat = invite.seats.firstWhere((s) => s.turnNumber == turn);
        _noteController.text = _noteFor(seat, _selectedChip!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = _selectedSeat;
    final isInstant = selected.status == SeatStatus.open;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        color: scheme.surfaceCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(999)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz, size: 16, color: scheme.secondary),
                            const SizedBox(width: 4),
                            Text('SLOT FLEXIBILITY', style: textTheme.labelSmall?.copyWith(color: scheme.secondary)),
                          ],
                        ),
                        Text('Request Slot Swap', style: textTheme.headlineMedium),
                        Text(
                          'Can\'t do Turn ${_yourSeat.turnNumber} (${formatShortDate(_yourSeat.turnDate!)})? '
                          'Propose a swap with a member or claim an open seat.',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.surfaceContainer),
            Expanded(
              child: RadioGroup<int>(
                groupValue: _selectedTurn,
                onChanged: (v) => _selectTurn(v!),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _yourCurrentSlotCard(scheme, textTheme),
                      const SizedBox(height: 20),
                      _instantOptionSection(scheme, textTheme),
                      const SizedBox(height: 20),
                      _memberSwapSection(scheme, textTheme),
                      const SizedBox(height: 20),
                      _noteSection(scheme, textTheme),
                      const SizedBox(height: 16),
                      _securityNote(scheme, textTheme, selected, isInstant),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.surfaceContainer),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: _sending || _sent ? null : () => _send(selected, isInstant),
                      icon: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                            )
                          : Icon(_sent ? Icons.check_circle : Icons.send),
                      label: Text(
                        _sent
                            ? 'Request Sent'
                            : isInstant
                                ? 'Claim Open Seat'
                                : 'Send Swap Request to ${firstName(selected.memberName!)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Keep Turn ${_yourSeat.turnNumber} & Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yourCurrentSlotCard(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryFixed.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.secondaryFixed),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.secondary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.event_available, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR CURRENT SLOT', style: textTheme.labelSmall?.copyWith(color: scheme.secondary)),
                Text(
                  'Turn ${_yourSeat.turnNumber} · ${formatWeekdayDate(_yourSeat.turnDate!)}',
                  style: textTheme.titleMedium,
                ),
                Text(
                  'Full \$${invite.lumpSumPayoutUsdc.toStringAsFixed(2)} pot delivered direct to you',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: scheme.secondary, borderRadius: BorderRadius.circular(999)),
            child: Text('Assigned', style: textTheme.labelSmall?.copyWith(color: scheme.onSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _instantOptionSection(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Instant Option: Available Open Seat', style: textTheme.labelLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('No approval needed', style: textTheme.labelSmall?.copyWith(color: scheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _seatOptionTile(scheme, textTheme, seat: _openSeat, instant: true),
      ],
    );
  }

  Widget _memberSwapSection(ColorScheme scheme, TextTheme textTheme) {
    final seats = _memberSeats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Swap With a Member', style: textTheme.labelLarge),
            Text('Requires mutual agreement', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        for (final seat in seats) ...[
          _seatOptionTile(scheme, textTheme, seat: seat, instant: false),
          if (seat != seats.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _seatOptionTile(ColorScheme scheme, TextTheme textTheme, {required InviteSeat seat, required bool instant}) {
    final eligible = instant || _isEligible(seat);
    final selected = _selectedTurn == seat.turnNumber;

    if (!eligible) {
      return Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.surfaceContainer),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: seat.memberName!, size: 32, paletteIndex: seat.turnNumber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${seat.memberName} · Turn ${seat.turnNumber}', style: textTheme.labelLarge),
                    Text(
                      'Completed • Already received payout',
                      style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                'Unavailable',
                style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _selectTurn(seat.turnNumber),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.05) : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.surfaceContainer, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            if (instant)
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.event_seat, color: scheme.onSurfaceVariant),
              )
            else
              InitialsAvatar(name: seat.memberName!, size: 40, paletteIndex: seat.turnNumber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          instant
                              ? 'Turn ${seat.turnNumber} · ${formatWeekdayDate(seat.turnDate!)}'
                              : '${seat.memberName} · Turn ${seat.turnNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (instant) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'Instant',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    instant
                        ? 'Open seat • You will receive \$${invite.lumpSumPayoutUsdc.toStringAsFixed(2)} '
                            'on ${formatShortDate(seat.turnDate!)}'
                        : seat.status == SeatStatus.current
                            ? 'Next Payout: ${formatWeekdayDate(seat.turnDate!)} (Earlier)'
                            : 'Scheduled Payout: ${formatWeekdayDate(seat.turnDate!)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: seat.status == SeatStatus.current ? scheme.secondary : scheme.onSurfaceVariant,
                      fontWeight: seat.status == SeatStatus.current ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Radio<int>(value: seat.turnNumber),
          ],
        ),
      ),
    );
  }

  Widget _noteSection(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reason / Note to Member', style: textTheme.labelLarge),
            Text('Optional', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final label in _kReasonChips.keys) _reasonChip(scheme, textTheme, label)],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'Add a polite note…',
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reasonChip(ColorScheme scheme, TextTheme textTheme, String label) {
    final selected = _selectedChip == label;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.1) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() {
          _selectedChip = label;
          _noteController.text = _noteFor(_selectedSeat, label);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected ? Border.all(color: scheme.primary.withValues(alpha: 0.3)) : null,
          ),
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _securityNote(ColorScheme scheme, TextTheme textTheme, InviteSeat selected, bool isInstant) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.surfaceContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isInstant ? Icons.bolt : Icons.security, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                children: [
                  TextSpan(
                    text: isInstant ? 'Instant claim: ' : 'Zero-risk swap: ',
                    style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                  if (isInstant)
                    const TextSpan(
                      text: 'this seat has no other owner, so claiming it takes effect immediately — '
                          'no approval needed.',
                    )
                  else ...[
                    TextSpan(
                      text: '${firstName(selected.memberName!)} will receive a notification to accept or '
                          'decline. If declined or unanswered within 48h, your original ',
                    ),
                    TextSpan(
                      text: 'Turn ${_yourSeat.turnNumber}',
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' stays 100% secured.'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(InviteSeat selected, bool isInstant) async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (isInstant) {
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Seat claimed — this is a preview; swaps aren\'t wired to a backend yet.'),
        ),
      );
    } else {
      // A member swap has something to wait on (their acceptance), unlike
      // an instant claim — worth its own screen rather than a snackbar.
      navigator.pop();
      navigator.push(
        MaterialPageRoute(builder: (_) => SlotSwapSentScreen(invite: invite, targetSeat: selected)),
      );
    }
  }
}
