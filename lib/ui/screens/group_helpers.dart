/// Helpers used by the group screens and sheets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/actions.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Runs a change on a group through the rules engine and returns the reason
/// when a rule stops it (the group is then left untouched), or null on
/// success. Use this inside sheets, which show the reason themselves.
Future<String?> tryAction(
  BuildContext context,
  String groupId,
  void Function(ChitGroup g, ChitActions a, String actor) change,
) {
  final state = AppScope.of(context);
  final actor = state.adminName;
  final actions = state.actions;
  return state.run(groupId, (g) => change(g, actions, actor));
}

/// Like [tryAction], but shows the reason in a snackbar when a rule stops the
/// change. Returns whether it worked.
Future<bool> runAction(
  BuildContext context,
  String groupId,
  void Function(ChitGroup g, ChitActions a, String actor) change, {
  String? success,
}) async {
  final error = await tryAction(context, groupId, change);
  if (!context.mounted) return error == null;
  if (error != null) {
    showSnack(context, error, error: true);
    return false;
  }
  if (success != null) showSnack(context, success);
  return true;
}

/// Copies [text] to the clipboard (to paste into WhatsApp) and says so.
Future<void> copyText(BuildContext context, String text, {String what = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showSnack(context, '$what. Paste it into your group chat.');
}
