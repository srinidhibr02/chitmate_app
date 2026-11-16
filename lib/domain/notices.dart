/// Ready-made texts for the updates feed. The admin can also copy them and
/// paste them into the group's WhatsApp chat.
library;

import '../core/format.dart';
import 'labels.dart';
import 'models.dart';
import 'rules.dart';

class Notices {
  Notices._();

  /// The rules of voting, as shown in notices and in the voting screen.
  static const List<String> votingRules = <String>[
    'You get one vote for every chit you own outright.',
    'If you only share chits (no chit of your own), you get one vote.',
    'Each of your votes must go to a different person.',
    'Only your first votes count and they cannot be changed.',
  ];

  /// Announcement posted when the admin opens a round.
  static String roundOpened(ChitGroup g, Round r) {
    final method = r.method;
    final b = StringBuffer()
      ..writeln('${g.name}: month ${r.number} of ${g.rounds.length}')
      ..writeln('Pool: ${rupees(g.poolAmount)}')
      ..writeln('Announcement: ${formatDateLong(r.announcementDate)}');
    if (method != null) {
      b
        ..writeln()
        ..writeln('How it is decided: ${methodLabel(method)}');
      switch (method) {
        case RoundMethod.vote:
          for (final line in votingRules) {
            b.writeln('- $line');
          }
          b.writeln(r.tieBreak == TieBreakMode.auto
              ? '- If votes tie, the app draws randomly between those who tied.'
              : '- If votes tie, the admin decides after talking with the group.');
        case RoundMethod.manual:
          b.writeln('The group agrees on one chit and the admin records it.');
        case RoundMethod.random:
          b.writeln('One eligible chit is drawn at random. The draw happens once and cannot be repeated.');
      }
    }
    final elig = Rules.eligibility(g, r.index);
    if (elig.blockedMemberIds.isNotEmpty) {
      final names = elig.blockedMemberIds.map(g.memberName).toList()..sort();
      b
        ..writeln()
        ..writeln('Not eligible this month (paid last month): ${names.join(', ')}.');
    }
    if (elig.relaxed) {
      b.writeln('Note: only chits linked to last month\'s winners remain, so the '
          'no-back-to-back rule is eased this month.');
    }
    return b.toString().trimRight();
  }

  /// Result posted when a round is decided.
  static String roundResult(ChitGroup g, Round r) {
    final chitId = r.winnerChitId;
    final chit = chitId == null ? null : g.chitById(chitId);
    if (chit == null) return 'Month ${r.number} has not been decided yet.';
    final b = StringBuffer()
      ..writeln('${g.name}: month ${r.number} result')
      ..writeln('${g.chitLabel(chit)} wins ${rupees(g.poolAmount)}.');
    if (r.resolution != null) b.writeln(r.resolution);
    final payouts = Rules.roundPayouts(g, r).entries.toList()
      ..sort((a, c) => c.value.compareTo(a.value));
    if (payouts.length > 1) {
      b.writeln('Payout:');
      for (final e in payouts) {
        b.writeln('- ${g.memberName(e.key)}: ${rupees(e.value)}');
      }
    } else if (payouts.length == 1) {
      b.writeln('Payout: ${g.memberName(payouts.first.key)} receives ${rupees(payouts.first.value)}.');
    }
    if (r.relaxed) {
      b.writeln('Note: the no-back-to-back rule was eased because only chits '
          'linked to last month\'s winners were left.');
    }
    b.write('Everyone keeps paying every month until the scheme ends.');
    return b.toString().trimRight();
  }

  /// A list of who still owes money for round [r].
  static String paymentReminder(ChitGroup g, Round r) {
    final b = StringBuffer()
      ..writeln('${g.name}: month ${r.number} contributions')
      ..writeln('Due by ${formatDateLong(r.announcementDate)}.');
    var any = false;
    for (final m in g.members) {
      final owed = Rules.monthlyDue(g, m.id) - Rules.paidBy(r, m.id);
      if (owed > 0) {
        any = true;
        b.writeln('- ${m.name}: ${rupees(owed)}');
      }
    }
    if (!any) return '${g.name}: month ${r.number}, everyone has paid. Thank you!';
    return b.toString().trimRight();
  }

  /// Who owns what, in the style of a group description.
  static String groupInfo(ChitGroup g) {
    final b = StringBuffer()..writeln(g.name);
    final v = g.chitValue;
    if (v == null) {
      b.writeln('Chit value not set yet');
    } else {
      b.writeln('Chit value ${rupees(v)} a month, ${plural(g.chits.length, 'chit')}, '
          'pool ${rupees(g.poolAmount)}');
    }
    final won = <String, int>{
      for (final r in g.rounds)
        if (r.winnerChitId != null) r.winnerChitId!: r.number,
    };
    for (final c in g.chits) {
      final owners = c.shares.entries
          .map((e) => '${g.memberName(e.key)} ${rupees(e.value)}')
          .join(', ');
      final w = won[c.id];
      b.writeln('Chit ${c.number}: $owners${w == null ? '' : ' (won in month $w)'}');
    }
    b.writeln();
    b.writeln('Monthly dues:');
    for (final m in g.members) {
      final due = Rules.monthlyDue(g, m.id);
      if (due > 0) b.writeln('- ${m.name}${m.left ? ' (left)' : ''}: ${rupees(due)}');
    }
    return b.toString().trimRight();
  }
}
