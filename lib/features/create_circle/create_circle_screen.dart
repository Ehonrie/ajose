import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../models/circle.dart';

/// Circle creation form. Building this against the same [Circle]/[Member]
/// shapes the rest of the app uses means once the Anchor program exists,
/// "Create" just needs to turn this form into an init-circle instruction
/// instead of a screen rewrite.
///
/// Not wired to the chain yet (no program to create an account against) —
/// this phase proves out the member-picking flow (device contacts) that a
/// real create-circle transaction will need input from.
class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '50');
  ContributionFrequency _frequency = ContributionFrequency.monthly;
  final List<Contact> _selectedMembers = [];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New circle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Circle name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Contribution per member (USDC)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse(v ?? '');
                if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ContributionFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(
                  value: ContributionFrequency.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: ContributionFrequency.biweekly,
                  child: Text('Every 2 weeks'),
                ),
                DropdownMenuItem(
                  value: ContributionFrequency.monthly,
                  child: Text('Monthly'),
                ),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? _frequency),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Members (${_selectedMembers.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _pickFromContacts,
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Add from contacts'),
                ),
              ],
            ),
            for (final contact in _selectedMembers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact.displayName ?? 'Unnamed'),
                subtitle: const Text('Wallet address needed — not linked yet'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedMembers.remove(contact)),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: const Text('Create circle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromContacts() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission was not granted.')),
        );
      }
      return;
    }

    final contacts = await FlutterContacts.getAll();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scrollController) => ListView.builder(
            controller: scrollController,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact.displayName ?? 'Unnamed'),
                onTap: () => Navigator.of(context).pop(contact),
              );
            },
          ),
        );
      },
    );

    if (picked != null && !_selectedMembers.any((c) => c.id == picked.id)) {
      setState(() => _selectedMembers.add(picked));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Not available yet'),
        content: const Text(
          'Creating a circle on-chain requires the Anchor program, which is '
          'not deployed in this build phase. This form (name, contribution '
          'amount, frequency, and member picking from contacts) is ready to '
          'submit an init-circle transaction once it exists.',
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
