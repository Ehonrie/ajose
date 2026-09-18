import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/initials_avatar.dart';
import '../../core/theme.dart';
import '../../models/circle.dart';

const List<double> _kContributionPresets = [50, 100, 250, 500];
const double _kMinContribution = 25;
const double _kMaxContribution = 1000;
const double _kContributionStep = 25;
const int _kMinMembers = 3;
const int _kMaxMembers = 20;

/// Circle creation form. Building this against the same [Circle]/[Member]
/// shapes the rest of the app uses means once the Anchor program exists,
/// "Launch" just needs to turn this form into an init-circle instruction
/// instead of a screen rewrite.
///
/// Not wired to the chain yet (no program to create an account against) —
/// this phase proves out the full input flow (rules, presets, member
/// picking from device contacts) that a real create-circle transaction
/// will need.
class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  ContributionFrequency _frequency = ContributionFrequency.weekly;
  double _contribution = 100;
  int _memberCount = 8;

  bool _loadingContacts = false;
  // Whether we've already run the permission+fetch flow at least once —
  // distinguishes "haven't tried yet" from "tried, found nothing" in the UI.
  bool _hasCheckedContacts = false;
  List<Contact> _allContacts = [];
  final Set<String> _confirmedContactIds = {};
  String _search = '';

  double get _totalPot => _contribution * _memberCount;

  List<Contact> get _confirmedContacts =>
      _allContacts.where((c) => _confirmedContactIds.contains(c.id)).toList();

  List<Contact> get _suggestedContacts {
    final query = _search.trim().toLowerCase();
    final matches = query.isEmpty
        ? _allContacts
        : _allContacts.where((c) {
            final name = (c.displayName ?? '').toLowerCase();
            final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
            return name.contains(query) || phone.contains(query);
          });
    return matches.take(30).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Circle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepperHeader(scheme: scheme, textTheme: textTheme),
            const SizedBox(height: 20),
            _RulesCard(
              scheme: scheme,
              textTheme: textTheme,
              nameController: _nameController,
              frequency: _frequency,
              onFrequencyChanged: (f) => setState(() => _frequency = f),
              contribution: _contribution,
              onContributionChanged: (v) => setState(() => _contribution = v),
              memberCount: _memberCount,
              onMemberCountChanged: (v) => setState(() => _memberCount = v),
              totalPot: _totalPot,
            ),
            const SizedBox(height: 16),
            _InviteCard(
              scheme: scheme,
              textTheme: textTheme,
              searchController: _searchController,
              onSearchChanged: (v) {
                setState(() => _search = v);
                _ensureContactsLoaded();
              },
              onBrowseContacts: _ensureContactsLoaded,
              loadingContacts: _loadingContacts,
              memberCount: _memberCount,
              confirmedContacts: _confirmedContacts,
              confirmedContactIds: _confirmedContactIds,
              suggestedContacts: _suggestedContacts,
              contactsLoaded: _hasCheckedContacts && !_loadingContacts,
              onRemoveConfirmed: (contact) => setState(() => _confirmedContactIds.remove(contact.id)),
              onToggleAdd: (contact) => setState(() => _confirmedContactIds.add(contact.id ?? '')),
            ),
            const SizedBox(height: 16),
            _TrustNotice(scheme: scheme, textTheme: textTheme, memberCount: _memberCount),
            const SizedBox(height: 20),
            _LaunchButton(scheme: scheme, textTheme: textTheme, onLaunch: _launch),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureContactsLoaded() async {
    if (_hasCheckedContacts || _loadingContacts) return;
    setState(() => _loadingContacts = true);
    _hasCheckedContacts = true;

    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    if (!granted) {
      if (mounted) {
        setState(() => _loadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission was not granted.')),
        );
      }
      return;
    }

    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
    contacts.sort(
      (a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()),
    );
    if (!mounted) return;
    setState(() {
      _allContacts = contacts;
      _loadingContacts = false;
    });
  }

  void _launch() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the circle a name first.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Not available yet'),
        content: const Text(
          'Launching a circle on-chain requires the Anchor program, which is '
          'not deployed in this build phase. This form (name, contribution '
          'amount, frequency, member count, and inviting from contacts) is '
          'ready to submit an init-circle transaction once it exists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _StepperHeader extends StatelessWidget {
  const _StepperHeader({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StepBadge(number: '1', background: scheme.primary, foreground: scheme.onPrimary),
            const SizedBox(width: 8),
            Text('Rules & Setup', style: textTheme.titleMedium),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.66,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepBadge(
              number: '2',
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Text('Invite Kin', style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Build a rotating savings pool rooted in trust and complete transparency.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number, required this.background, required this.foreground});

  final String number;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        number,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: foreground),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.scheme,
    required this.textTheme,
    required this.nameController,
    required this.frequency,
    required this.onFrequencyChanged,
    required this.contribution,
    required this.onContributionChanged,
    required this.memberCount,
    required this.onMemberCountChanged,
    required this.totalPot,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final TextEditingController nameController;
  final ContributionFrequency frequency;
  final ValueChanged<ContributionFrequency> onFrequencyChanged;
  final double contribution;
  final ValueChanged<double> onContributionChanged;
  final int memberCount;
  final ValueChanged<int> onMemberCountChanged;
  final double totalPot;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Step 1: Circle Rules', style: textTheme.titleLarge)),
              _Pill(
                label: 'Required',
                background: scheme.primary.withValues(alpha: 0.1),
                foreground: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Circle Name', style: textTheme.labelLarge),
              Text(
                'Distinct & memorable',
                style: textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'e.g. Abuja Founders Circle',
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: nameController,
                builder: (context, value, _) => value.text.trim().isEmpty
                    ? const SizedBox.shrink()
                    : Icon(Icons.check_circle, color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Settlement Asset', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    r'$',
                    style: textTheme.titleMedium?.copyWith(color: scheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('USDC', style: textTheme.titleMedium),
                          const SizedBox(width: 8),
                          _Pill(
                            label: 'Instant settlement',
                            background: scheme.secondaryFixed,
                            foreground: scheme.onSecondaryFixedVariant,
                          ),
                        ],
                      ),
                      Text(
                        'Zero conversion volatility',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: scheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Contribution per Round', style: textTheme.labelLarge),
              Text(
                '\$${contribution.toStringAsFixed(2)}',
                style: textTheme.titleLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final preset in _kContributionPresets) ...[
                Expanded(
                  child: _AmountPresetButton(
                    amount: preset,
                    active: contribution == preset,
                    scheme: scheme,
                    textTheme: textTheme,
                    onTap: () => onContributionChanged(preset),
                  ),
                ),
                if (preset != _kContributionPresets.last) const SizedBox(width: 8),
              ],
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: scheme.primary,
              thumbColor: scheme.primary,
              inactiveTrackColor: scheme.surfaceContainer,
              overlayColor: scheme.primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: contribution.clamp(_kMinContribution, _kMaxContribution),
              min: _kMinContribution,
              max: _kMaxContribution,
              divisions: ((_kMaxContribution - _kMinContribution) / _kContributionStep).round(),
              onChanged: onContributionChanged,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Frequency', style: textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _FrequencySegmented(
                      scheme: scheme,
                      textTheme: textTheme,
                      value: frequency,
                      onChanged: onFrequencyChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Members', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      scheme: scheme,
                      onTap: memberCount > _kMinMembers
                          ? () => onMemberCountChanged(memberCount - 1)
                          : null,
                    ),
                    Text('$memberCount Members', style: textTheme.titleMedium),
                    _StepperButton(
                      icon: Icons.add,
                      scheme: scheme,
                      onTap: memberCount < _kMaxMembers
                          ? () => onMemberCountChanged(memberCount + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.savings, color: scheme.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POT YIELD FORECAST',
                        style: textTheme.labelSmall?.copyWith(color: scheme.secondary),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: textTheme.titleMedium,
                          children: [
                            const TextSpan(text: 'Total pot each round: '),
                            TextSpan(
                              text: '\$${totalPot.toStringAsFixed(2)} USDC',
                              style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Full circle duration: $memberCount '
                        '${_frequencyUnitLabel(frequency)} ($memberCount rounds)',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _frequencyUnitLabel(ContributionFrequency f) => switch (f) {
        ContributionFrequency.weekly => 'weeks',
        ContributionFrequency.biweekly => 'fortnights',
        ContributionFrequency.monthly => 'months',
      };
}

class _AmountPresetButton extends StatelessWidget {
  const _AmountPresetButton({
    required this.amount,
    required this.active,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final double amount;
  final bool active;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? scheme.primary : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '\$${amount.toStringAsFixed(0)}',
              style: textTheme.labelLarge?.copyWith(
                color: active ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrequencySegmented extends StatelessWidget {
  const _FrequencySegmented({
    required this.scheme,
    required this.textTheme,
    required this.value,
    required this.onChanged,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final ContributionFrequency value;
  final ValueChanged<ContributionFrequency> onChanged;

  static const _labels = {
    ContributionFrequency.weekly: 'Weekly',
    ContributionFrequency.biweekly: 'Bi-Wk',
    ContributionFrequency.monthly: 'Month',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in _labels.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == entry.key ? AppTheme.surfaceCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: value == entry.key
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge?.copyWith(
                      color: value == entry.key ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.scheme, required this.onTap});

  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? scheme.outline : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.scheme,
    required this.textTheme,
    required this.searchController,
    required this.onSearchChanged,
    required this.onBrowseContacts,
    required this.loadingContacts,
    required this.memberCount,
    required this.confirmedContacts,
    required this.confirmedContactIds,
    required this.suggestedContacts,
    required this.contactsLoaded,
    required this.onRemoveConfirmed,
    required this.onToggleAdd,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBrowseContacts;
  final bool loadingContacts;
  final int memberCount;
  final List<Contact> confirmedContacts;
  final Set<String> confirmedContactIds;
  final List<Contact> suggestedContacts;
  final bool contactsLoaded;
  final ValueChanged<Contact> onRemoveConfirmed;
  final ValueChanged<Contact> onToggleAdd;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add, size: 20, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text('Step 2: Invite Members', style: textTheme.titleLarge)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${confirmedContacts.length} of $memberCount filled',
                  style: textTheme.labelSmall?.copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search contacts or phone…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onBrowseContacts,
                style: OutlinedButton.styleFrom(
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  foregroundColor: scheme.primary,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                icon: const Icon(Icons.contacts_outlined, size: 18),
                label: const Text('Contacts'),
              ),
            ],
          ),
          if (confirmedContacts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'CONFIRMED INVITATIONS (${confirmedContacts.length})',
              style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final contact in confirmedContacts)
                  _ConfirmedChip(
                    contact: contact,
                    scheme: scheme,
                    textTheme: textTheme,
                    onRemove: () => onRemoveConfirmed(contact),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'SUGGESTED FROM DEVICE',
            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (loadingContacts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!contactsLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tap "Contacts" to pick members from your phone.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else if (suggestedContacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No matching contacts.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < suggestedContacts.length; i++) ...[
                  _SuggestedContactRow(
                    contact: suggestedContacts[i],
                    index: i,
                    scheme: scheme,
                    textTheme: textTheme,
                    added: confirmedContactIds.contains(suggestedContacts[i].id),
                    onAdd: () => onToggleAdd(suggestedContacts[i]),
                  ),
                  if (i != suggestedContacts.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: foreground),
      ),
    );
  }
}

class _ConfirmedChip extends StatelessWidget {
  const _ConfirmedChip({
    required this.contact,
    required this.scheme,
    required this.textTheme,
    required this.onRemove,
  });

  final Contact contact;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(name: contact.displayName ?? '?', size: 24),
          const SizedBox(width: 6),
          Text(
            contact.displayName ?? 'Unnamed',
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (phone != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${_truncatePhone(phone)})',
              style: textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  static String _truncatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return digits;
    return '${digits.substring(0, 4)}…';
  }
}

class _SuggestedContactRow extends StatelessWidget {
  const _SuggestedContactRow({
    required this.contact,
    required this.index,
    required this.scheme,
    required this.textTheme,
    required this.added,
    required this.onAdd,
  });

  final Contact contact;
  final int index;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: contact.displayName ?? '?',
            paletteIndex: index,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.displayName ?? 'Unnamed', style: textTheme.titleMedium),
                Text(phone, style: textTheme.bodySmall?.copyWith(color: scheme.outline)),
              ],
            ),
          ),
          added
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.done, size: 16, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Added',
                        style: textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                )
              : FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
        ],
      ),
    );
  }
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice({required this.scheme, required this.textTheme, required this.memberCount});

  final ColorScheme scheme;
  final TextTheme textTheme;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, size: 22, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No funds are deducted until all $memberCount members accept and '
              'activate Round 1. Every participant\'s balance is securely held '
              'in on-chain non-custodial smart escrows.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryFixedVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.scheme, required this.textTheme, required this.onLaunch});

  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: onLaunch,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Launch Circle & Send Invites'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 16, color: scheme.outline),
            const SizedBox(width: 6),
            Text(
              'Audited multi-party settlement contracts',
              style: textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ],
    );
  }
}
