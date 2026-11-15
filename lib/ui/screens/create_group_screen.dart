library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../domain/actions.dart';
import '../../state/app_state.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import '../../theme/app_theme.dart';
import 'group_screen.dart';

/// Creates a group. Only the creation date is required; everything else can
/// be set (or changed) later from inside the group.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _members = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const List<int> _quickValues = <int>[1000, 5000, 10000, 25000];

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _members.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Group creation date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String? _validateValue(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n <= 0) return 'Enter an amount above ₹0';
    if (n > ChitActions.maxChitValue) {
      return 'Keep it under ${rupees(ChitActions.maxChitValue)}';
    }
    return null;
  }

  String? _validateMembers(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 2 || n > ChitActions.maxMembers) {
      return 'Enter a number from 2 to ${ChitActions.maxMembers}';
    }
    return null;
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final state = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    String? createdId;
    final err = await state.createGroup(
      createdAt: _date,
      name: _name.text,
      chitValue: int.tryParse(_value.text.trim()),
      plannedMembers: int.tryParse(_members.text.trim()),
      onCreated: (g) => createdId = g.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    final id = createdId;
    if (id == null) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(softRoute<void>(GroupScreen(groupId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = int.tryParse(_value.text.trim());
    return Scaffold(
      appBar: AppBar(title: const Text('New chit group')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              FadeSlide(
                child: Text(
                  'Only the date is required. You can change everything else later.',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlide(
                index: 1,
                child: AppCard(
                  onTap: _pickDate,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(28),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.event_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Creation date',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(formatDateLong(_date),
                                key: const Key('creation-date'),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const Pill(label: 'Required', color: AppColors.warning),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlide(
                index: 2,
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: ChitActions.maxNameLength,
                  decoration: appInput(context, label: 'Group name (optional)', hint: 'e.g. Office chit'),
                ),
              ),
              const SizedBox(height: 4),
              FadeSlide(
                index: 3,
                child: TextFormField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  validator: _validateValue,
                  onChanged: (_) => setState(() {}),
                  decoration: appInput(
                    context,
                    label: 'Investment per chit each month (optional)',
                    prefixText: '₹ ',
                    helper: 'Every chit in this group is this amount.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeSlide(
                index: 3,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final v in _quickValues)
                      ChoiceChip(
                        label: Text(rupees(v)),
                        selected: value == v,
                        onSelected: (_) => setState(() => _value.text = '$v'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FadeSlide(
                index: 4,
                child: TextFormField(
                  controller: _members,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  validator: _validateMembers,
                  decoration: appInput(
                    context,
                    label: 'Number of members (optional)',
                    helper: 'A target to track while you add people.',
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlide(
                index: 5,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _create,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Create group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
