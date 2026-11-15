import 'dart:convert';

import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/domain/notices.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

ChitGroup roundTrip(ChitGroup g) {
  final text = jsonEncode(g.toJson());
  return ChitGroup.fromJson((jsonDecode(text) as Map).cast<String, dynamic>());
}

void main() {
  test('a fresh group survives a save and load', () {
    final a = testActions();
    final g = a.createGroup(createdAt: kToday, organiserName: 'Asha', chitValue: 5000, plannedMembers: 6);
    final back = roundTrip(g);
    expect(back.toJson(), equals(g.toJson()));
    expect(back.name, g.name);
    expect(back.chitValue, 5000);
    expect(back.plannedMembers, 6);
    expect(back.started, isFalse);
  });

  test('a group in the middle of a vote survives a save and load', () {
    final a = testActions();
    final b = example2(a, start: true);
    final g = b.group;
    a.openRound(g, 0, method: RoundMethod.vote, tieBreak: TieBreakMode.admin, actor: 'Admin');
    a.castVote(g, 0, voterId: b.id('A'), targetId: b.id('B'));
    a.castVote(g, 0, voterId: b.id('B'), targetId: b.id('A'));
    a.recordPayment(g, 0, memberId: b.id('A'), amount: 20000, actor: 'Admin');
    final back = roundTrip(g);
    expect(back.toJson(), equals(g.toJson()));
    expect(back.rounds[0].votes, hasLength(2));
    expect(back.rounds[0].tieBreak, TieBreakMode.admin);
    expect(back.rounds[0].method, RoundMethod.vote);
    expect(back.rounds[0].paid[b.id('A')], 20000);
    expect(back.chits[6].shares[b.id('C')], 7000);
  });

  test('a finished scheme survives a save and load', () {
    final a = testActions(seed: 5);
    final b = example1(a, start: true);
    final g = b.group;
    for (var i = 0; i < g.rounds.length; i++) {
      a.openRound(g, i, method: RoundMethod.random, actor: 'Admin');
      if (!g.rounds[i].isCompleted) a.randomDraw(g, i, actor: 'Admin');
    }
    a.setPayoutDone(g, 0, memberId: g.chitById(g.rounds[0].winnerChitId!)!.ownerIds.first, done: true, actor: 'Admin');
    final back = roundTrip(g);
    expect(back.toJson(), equals(g.toJson()));
    expect(back.completed, isTrue);
    expect(back.rounds[0].payoutsDone, g.rounds[0].payoutsDone);
    expect(back.rounds[3].relaxed, g.rounds[3].relaxed);
    expect(back.feed.length, g.feed.length);
  });

  test('missing or unknown values fall back to safe defaults', () {
    final j = <String, dynamic>{
      'id': 'g1',
      'name': 'Old data',
      'members': <Object?>[],
      'rounds': <Object?>[
        <String, dynamic>{
          'index': 0,
          'announcementDate': '2026-12-01T00:00:00.000',
          'status': 'someFutureStatus',
          'method': 'someFutureMethod',
        },
      ],
    };
    final g = ChitGroup.fromJson(j);
    expect(g.name, 'Old data');
    expect(g.chitValue, isNull);
    expect(g.remindersEnabled, isTrue);
    expect(g.rounds.single.status, RoundStatus.pending);
    expect(g.rounds.single.method, RoundMethod.random);
    expect(g.rounds.single.votes, isEmpty);
  });

  group('notices', () {
    test('group info lists every chit with its owners and shares', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin');
      final info = Notices.groupInfo(g);
      expect(info, contains('Chit value ₹10,000 a month, 4 chits, pool ₹40,000'));
      expect(info, contains('Chit 1: A ₹10,000'));
      expect(info, contains('Chit 3: B ₹3,000, C ₹7,000 (won in month 1)'));
      expect(info, contains('Chit 4: A ₹5,000, D ₹5,000'));
      expect(info, contains('- A: ₹15,000'));
      expect(info, contains('- B: ₹13,000'));
    });

    test('result notice shows the split payout', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin');
      final text = Notices.roundResult(g, g.rounds[0]);
      expect(text, contains('Chit 3 (B + C) wins ₹40,000.'));
      expect(text, contains('- C: ₹28,000'));
      expect(text, contains('- B: ₹12,000'));
      expect(text, contains('Everyone keeps paying'));
      expect(Notices.roundResult(g, g.rounds[1]), contains('not been decided'));
    });

    test('payment reminder lists only people who still owe', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 15000, actor: 'Admin');
      a.recordPayment(g, 0, memberId: b.id('B'), amount: 3000, actor: 'Admin');
      final text = Notices.paymentReminder(g, g.rounds[0]);
      expect(text, isNot(contains('- A:')));
      expect(text, contains('- B: ₹10,000'));
      expect(text, contains('- C: ₹7,000'));
      expect(text, contains('- D: ₹5,000'));
      for (final n in <String>['B', 'C', 'D']) {
        a.recordPayment(g, 0,
            memberId: b.id(n), amount: n == 'B' ? 13000 : (n == 'C' ? 7000 : 5000), actor: 'Admin');
      }
      expect(Notices.paymentReminder(g, g.rounds[0]), contains('everyone has paid'));
    });
  });
}
