library;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/draw_wheel.dart';

/// Announces who won a month. With [reelCandidates] the winner is revealed
/// by the draw reel first; otherwise the result shows straight away.
Future<void> showResultDialog(
  BuildContext context,
  ChitGroup group,
  Round round, {
  List<String>? reelCandidates,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ResultDialog(group: group, round: round, candidates: reelCandidates),
  );
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.group, required this.round, this.candidates});

  final ChitGroup group;
  final Round round;
  final List<String>? candidates;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late bool _done = widget.candidates == null || widget.candidates!.length < 2;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final r = widget.round;
    final scheme = Theme.of(context).colorScheme;
    final chit = r.winnerChitId == null ? null : g.chitById(r.winnerChitId!);
    final label = chit == null ? 'Unknown chit' : g.chitLabel(chit);
    final payouts = chit == null ? const <String, int>{} : Rules.payoutFor(g, chit);
    final owners = payouts.entries.toList()
      ..sort((a, b) => g.memberName(a.key).compareTo(g.memberName(b.key)));
    final reel = widget.candidates;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Month ${r.number} winner',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                if (reel != null && reel.length >= 2)
                  Center(
                    child: DrawWheel(
                      candidates: reel,
                      winner: label,
                      onFinished: () {
                        if (mounted) setState(() => _done = true);
                      },
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withAlpha(46),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.tertiary, width: 2),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_done
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 16),
                            for (final e in owners)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(g.memberName(e.key),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    Text(rupees(e.value),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.success)),
                                  ],
                                ),
                              ),
                            if (r.resolution != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(r.resolution!,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant, height: 1.35)),
                            ],
                            if (r.relaxed) ...<Widget>[
                              const SizedBox(height: 8),
                              const Text(
                                'Every remaining chit involved someone who was paid last '
                                'month, so the "not two months in a row" rule was eased for '
                                'this draw.',
                                style: TextStyle(color: AppColors.warning, height: 1.35),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('result-done'),
                  onPressed: _done ? () => Navigator.of(context).pop() : null,
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          if (_done)
            const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
        ],
      ),
    );
  }
}
