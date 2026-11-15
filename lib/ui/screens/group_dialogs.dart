/// Small prompts used from several screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../domain/actions.dart';
import '../../domain/models.dart';
import '../../theme/app_theme.dart';
import 'group_helpers.dart';

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.numeric,
    required this.validator,
    required this.confirmLabel,
    this.prefixText,
    this.helper,
    this.maxLength,
  });

  final String title;
  final String label;
  final String initial;
  final bool numeric;
  final String? Function(String text) validator;
  final String confirmLabel;
  final String? prefixText;
  final String? helper;
  final int? maxLength;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final err = widget.validator(text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
        textCapitalization: widget.numeric ? TextCapitalization.none : TextCapitalization.words,
        inputFormatters: widget.numeric
            ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
            : null,
        maxLength: widget.maxLength,
        onSubmitted: (_) => _submit(),
        decoration: appInput(
          context,
          label: widget.label,
          prefixText: widget.prefixText,
          helper: widget.helper,
        ).copyWith(errorText: _error),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Asks for a whole number between [min] and [max]. Null when cancelled.
Future<int?> promptInt(
  BuildContext context, {
  required String title,
  required String label,
  int? initial,
  required int min,
  required int max,
  String? prefixText,
  String? helper,
  String confirmLabel = 'Save',
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial == null ? '' : '$initial',
      numeric: true,
      prefixText: prefixText,
      helper: helper,
      confirmLabel: confirmLabel,
      validator: (t) {
        final n = int.tryParse(t);
        if (n == null) return 'Enter a number';
        if (n < min || n > max) return 'Enter a number from $min to $max';
        return null;
      },
    ),
  );
  return text == null ? null : int.tryParse(text);
}

/// Asks for a short piece of text. Null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = 'Save',
  int maxLength = ChitActions.maxNameLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      numeric: false,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      validator: (t) => t.trim().isEmpty ? 'This cannot be empty' : null,
    ),
  );
}

/// Opens the date picker for the group's first announcement and saves it.
Future<void> pickFirstAnnouncement(BuildContext context, ChitGroup g) async {
  final initial = g.firstAnnouncementDate ?? DateTime.now().add(const Duration(days: 7));
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: 'First announcement date',
  );
  if (picked == null || !context.mounted) return;
  await runAction(
    context,
    g.id,
    (group, a, actor) => a.setFirstAnnouncementDate(group, dateOnly(picked), actor: actor),
  );
}

/// Asks for the chit value and saves it.
Future<void> editChitValue(BuildContext context, ChitGroup g) async {
  final value = await promptInt(
    context,
    title: 'Chit value',
    label: 'Amount per chit each month',
    initial: g.chitValue,
    min: 1,
    max: ChitActions.maxChitValue,
    prefixText: '₹ ',
    helper: 'Every chit in this group is worth this much.',
  );
  if (value == null || !context.mounted) return;
  await runAction(context, g.id, (group, a, actor) => a.setChitValue(group, value, actor: actor));
}
