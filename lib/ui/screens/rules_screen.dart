library;

import 'package:flutter/material.dart';

import '../../domain/notices.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';

/// Plain-language explanation of how a ChitMate group works.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const List<(IconData, String, String)> _sections = <(IconData, String, String)>[
    (
      Icons.savings_rounded,
      'The scheme',
      'Everyone puts the same amount into the pool every month. Each month one chit '
          'receives the whole pool. With N chits the cycle lasts N months and every '
          'chit wins exactly once. There is no profit or interest, and people keep '
          'paying every month even after they have received their chit.',
    ),
    (
      Icons.pie_chart_rounded,
      'Chits and shares',
      'Every chit is worth the same amount. A chit can belong to one person or be shared '
          'by several, and the shares can be uneven but must add up to the chit value. '
          'When a shared chit wins, each owner receives their share multiplied by the '
          'number of chits.',
    ),
    (
      Icons.how_to_vote_rounded,
      'Voting',
      'The admin picks the method each month: a vote, a chit the group agrees on, or '
          'a random draw. In a vote, the person with the most votes wins and one of '
          'their eligible chits is drawn at random.',
    ),
    (
      Icons.casino_rounded,
      'Random draws',
      'Every eligible chit has the same chance. Anyone who received last month is '
          'skipped so nobody wins two months in a row. If that would leave no chit, '
          'the rule is eased to the chits with the least overlap, and the app says so. '
          'A result is saved once and cannot be re-drawn.',
    ),
    (
      Icons.balance_rounded,
      'Ties and silence',
      'If votes tie, the group setting decides: the app draws among the tied people, '
          'or the admin decides after talking with the group (and the reason is '
          'logged). If nobody has chosen a method by the announcement date, a random '
          'draw is used.',
    ),
    (
      Icons.lock_rounded,
      'Locks and changes',
      'After the first month starts, the chit value and the number of chits are '
          'locked, and chits that have won cannot change. Other changes need the '
          'co-owners to agree and are written to the updates feed with who made them '
          'and when.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('How it works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          for (var i = 0; i < _sections.length; i++)
            FadeSlide(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(_sections[i].$1, color: AppColors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_sections[i].$2,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(_sections[i].$3,
                                style: TextStyle(color: scheme.onSurface, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SectionHeader('Votes, in short'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final line in Notices.votingRules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
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
}
