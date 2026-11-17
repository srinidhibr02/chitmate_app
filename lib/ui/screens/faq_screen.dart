library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// Common questions, each opening to its answer.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<(String, String)> items = <(String, String)>[
    (
      'Does ChitMate handle my money?',
      'No. ChitMate only keeps records: members, chits, votes, results and who has paid. '
          'Money moves between the people in your group, outside the app.',
    ),
    (
      'What is a chit and what does "shared" mean?',
      'A chit is one share of the monthly pool. Its value is the same for every chit. A chit '
          'can belong to one person, or be split between several people whose shares add up '
          'to the chit value. The winner receives their share multiplied by the number of chits.',
    ),
    (
      'How is the winner of a month decided?',
      'The organiser picks a method for the month: a vote, a manual pick the group has agreed '
          'on, or a random draw. Everyone who already won can not win again until the cycle '
          'is complete, and nobody wins two months in a row unless nothing else is possible.',
    ),
    (
      'How does voting work?',
      'Each full chit gets one vote. A person who only holds shared chits gets one vote. '
          'You vote for someone else, never yourself, and only your first vote counts. '
          'If there is a tie, the group chooses how to break it.',
    ),
    (
      'How do I add or remove members?',
      'Open your group, go to Group info and tap Add. To remove someone, open them and choose '
          '"Remove from group". If they hold chit shares they are kept as a former member, and '
          'adding the same mobile number again brings their shares back.',
    ),
    (
      'Why can I not change the chits any more?',
      'Once the first month has started, the number of chits is locked so that nobody can '
          'change what others pay or receive. Shares of chits that have not won can still be '
          'changed if everybody involved agrees.',
    ),
    (
      'When do I get reminders?',
      'Three days before a payment is due, at 9 AM. Allow notifications for ChitMate in your '
          'phone settings if you do not receive them.',
    ),
    (
      'Why does the app warn that someone holds many votes?',
      'When one person holds more than 40% of all votes, they can steer most decisions. The '
          'warning suggests using a random draw or agreed picks to keep things fair.',
    ),
    (
      'I did not get my sign-in code.',
      'Check the number, wait up to a minute, then tap "Send again". Make sure you have '
          'network coverage. If it still does not arrive, contact support from Settings.',
    ),
    (
      'How do I delete my account and data?',
      'Go to Settings, then Delete account. You will confirm with a new code sent to your '
          'phone. This deletes every group you organise. Groups run by someone else stay with '
          'their organiser, who can remove you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            for (final (q, a) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      iconColor: AppColors.teal,
                      title: Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
                      children: <Widget>[
                        Text(a, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
