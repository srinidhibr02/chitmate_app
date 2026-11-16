import 'dart:math';

import 'package:chit_mate/domain/actions.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Expects a [RuleViolation], optionally with [text] somewhere in its message.
Matcher violation([String? text]) => throwsA(
      isA<RuleViolation>().having(
        (e) => e.message,
        'message',
        text == null ? isNotEmpty : contains(text),
      ),
    );

void main() {
  group('creating and editing a group', () {
    test('only the creation date is needed', () {
      final a = testActions();
      final g = a.createGroup(createdAt: DateTime(2026, 11, 14, 18), organiserName: 'Asha');
      expect(g.name, 'Chit group');
      expect(g.createdAt, DateTime(2026, 11, 14));
      expect(g.chitValue, isNull);
      expect(g.plannedMembers, isNull);
      expect(g.started, isFalse);
      expect(g.members.single.name, 'Asha');
      expect(g.feed, hasLength(1));
    });

    test('optional fields are validated', () {
      final a = testActions();
      expect(() => a.createGroup(createdAt: kToday, organiserName: 'A', chitValue: 0), violation());
      expect(() => a.createGroup(createdAt: kToday, organiserName: 'A', chitValue: -5), violation());
      expect(() => a.createGroup(createdAt: kToday, organiserName: 'A', plannedMembers: 1), violation());
      expect(() => a.createGroup(createdAt: kToday, organiserName: 'A', name: 'x' * 41), violation());
      final ok = a.createGroup(
          createdAt: kToday, organiserName: 'A', chitValue: 5000, plannedMembers: 10, name: '  Friends  ');
      expect(ok.name, 'Friends');
      expect(ok.chitValue, 5000);
      expect(ok.plannedMembers, 10);
    });

    test('settings can be changed before the cycle starts, and are logged', () {
      final a = testActions();
      final g = a.createGroup(createdAt: kToday, organiserName: 'Asha');
      a.renameGroup(g, 'Office chit', actor: 'Asha');
      a.setChitValue(g, 10000, actor: 'Asha');
      a.setChitValue(g, 20000, actor: 'Asha');
      a.setPlannedMembers(g, 8, actor: 'Asha');
      a.setFirstAnnouncementDate(g, DateTime(2026, 12, 5, 14), actor: 'Asha');
      expect(g.name, 'Office chit');
      expect(g.chitValue, 20000);
      expect(g.plannedMembers, 8);
      expect(g.firstAnnouncementDate, DateTime(2026, 12, 5));
      final text = g.feed.map((f) => f.text).join('\n');
      expect(text, contains('renamed'));
      expect(text, contains('₹10,000 to ₹20,000'));
      expect(text, contains('First announcement date set'));
      expect(g.feed.every((f) => f.author.isNotEmpty), isTrue);
    });

    test('invalid settings are refused', () {
      final a = testActions();
      final g = a.createGroup(createdAt: kToday, organiserName: 'Asha');
      expect(() => a.renameGroup(g, '   ', actor: 'x'), violation());
      expect(() => a.setChitValue(g, 0, actor: 'x'), violation());
      expect(() => a.setPlannedMembers(g, 1, actor: 'x'), violation());
    });

    test('members: add, rename, duplicate names and removal rules', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      final extra = a.addMember(g, '  Meena  ', phone: ' 98765 43210 ', actor: 'Admin');
      expect(extra.name, 'Meena');
      expect(extra.phone, '+919876543210');
      expect(() => a.addMember(g, 'meena', actor: 'Admin'), violation('already in this group'));
      expect(() => a.addMember(g, '', actor: 'Admin'), violation());
      a.renameMember(g, extra.id, 'Meenakshi', actor: 'Admin');
      expect(g.memberById(extra.id)!.name, 'Meenakshi');
      expect(() => a.renameMember(g, extra.id, 'A', actor: 'Admin'), violation('already in this group'));
      // Meenakshi owns nothing and has no history, so she is simply deleted.
      a.removeMember(g, extra.id, actor: 'Admin');
      expect(g.memberById(extra.id), isNull);
    });

    test('chits: add, edit and remove before starting', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      expect(() => a.addChit(g, <String, int>{b.id('A'): 5000}, actor: 'Admin'), violation('more'));
      final added = a.addChit(g, <String, int>{b.id('C'): 6000, b.id('D'): 4000}, actor: 'Admin');
      expect(added.number, 5);
      expect(g.chitCount, 5);
      a.updateChitShares(g, added.id, <String, int>{b.id('C'): 5000, b.id('D'): 5000}, actor: 'Admin');
      expect(g.chitById(added.id)!.shares[b.id('C')], 5000);
      a.removeChit(g, added.id, actor: 'Admin');
      expect(g.chitCount, 4);
      // A new chit takes the next number after the highest one still in use.
      final again = a.addChit(g, <String, int>{b.id('C'): 10000}, actor: 'Admin');
      expect(again.number, 5);
    });

    test('shares that do not add up are refused', () {
      final a = testActions();
      final b = example1(a);
      expect(() => a.updateChitShares(b.group, b.chit(2).id, <String, int>{b.id('B'): 3000}, actor: 'Admin'),
          violation('more'));
      expect(b.chit(2).shares[b.id('B')], 3000);
    });
  });

  group('starting the cycle', () {
    test('creates one round per chit with monthly dates and locks the structure', () {
      final a = testActions();
      final b = buildGroup(
        a,
        members: <String>['A', 'B', 'C'],
        chits: <Map<String, int>>[
          <String, int>{'A': 10000},
          <String, int>{'B': 10000},
          <String, int>{'C': 10000},
        ],
        first: DateTime(2026, 11, 30),
      );
      final g = b.group;
      a.startCycle(g, actor: 'Admin');
      expect(g.started, isTrue);
      expect(g.rounds.map((r) => r.announcementDate).toList(), <DateTime>[
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 30),
        DateTime(2027, 1, 30),
      ]);
      expect(g.rounds.every((r) => r.status == RoundStatus.pending), isTrue);
      expect(g.currentRound!.index, 0);
      expect(g.feed.last.kind, FeedKind.announcement);
      expect(() => a.startCycle(g, actor: 'Admin'), violation('already started'));
    });

    test('month-end dates are clamped, not chained', () {
      final a = testActions();
      final b = buildGroup(
        a,
        members: <String>['A', 'B', 'C', 'D'],
        chits: <Map<String, int>>[
          <String, int>{'A': 10000},
          <String, int>{'B': 10000},
          <String, int>{'C': 10000},
          <String, int>{'D': 10000},
        ],
        first: DateTime(2027, 1, 31),
        start: true,
      );
      expect(b.group.rounds.map((r) => r.announcementDate).toList(), <DateTime>[
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('locked things stay locked after the start', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      expect(() => a.setChitValue(g, 5000, actor: 'x'), violation('locked'));
      expect(() => a.addChit(g, <String, int>{b.id('A'): 10000}, actor: 'x'), violation('locked'));
      expect(() => a.removeChit(g, b.chit(0).id, actor: 'x'), violation('locked'));
      expect(() => a.setFirstAnnouncementDate(g, DateTime(2027, 1, 1), actor: 'x'), violation());
      expect(g.chitValue, 10000);
      expect(g.chitCount, 4);
    });

    test('editing shares after the start needs consent, an unwon chit and a quiet moment', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      final newShares = <String, int>{b.id('B'): 4000, b.id('C'): 6000};
      expect(() => a.updateChitShares(g, b.chit(2).id, newShares, actor: 'Admin'), violation('agreed'));
      a.updateChitShares(g, b.chit(2).id, newShares, actor: 'Admin', coOwnersAgreed: true);
      expect(Rules.payoutFor(g, b.chit(2))[b.id('B')], 16000);
      expect(g.feed.last.text, contains('changed from'));

      // Win chit A in month 1; its shares are now locked.
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      expect(() => a.updateChitShares(g, b.chit(3).id, <String, int>{b.id('A'): 5000, b.id('D'): 5000},
              actor: 'Admin', coOwnersAgreed: true),
          violation('Finish the month in progress'));
      a.manualPick(g, 0, chitId: b.chit(0).id, actor: 'Admin');
      expect(() => a.updateChitShares(g, b.chit(0).id, <String, int>{b.id('A'): 10000},
              actor: 'Admin', coOwnersAgreed: true),
          violation('already won'));
    });

    test('members with history are marked as left, not deleted', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.recordPayment(g, 0, memberId: b.id('D'), amount: 1000, actor: 'Admin');
      a.removeMember(g, b.id('D'), actor: 'Admin');
      expect(g.memberById(b.id('D')), isNotNull);
      expect(g.memberById(b.id('D'))!.left, isTrue);
      expect(Rules.paidBy(g.rounds[0], b.id('D')), 1000);
    });
  });

  group('rounds: order and methods', () {
    test('rounds must be played in order, one at a time', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      expect(() => a.openRound(g, 1, method: RoundMethod.random, actor: 'x'), violation('Finish month 1'));
      a.openRound(g, 0, method: RoundMethod.random, actor: 'x');
      expect(() => a.openRound(g, 0, method: RoundMethod.random, actor: 'x'), violation('already open'));
      a.randomDraw(g, 0, actor: 'x');
      expect(() => a.randomDraw(g, 0, actor: 'x'), violation('already decided'));
      expect(() => a.openRound(g, 99, method: RoundMethod.random, actor: 'x'), violation('Unknown'));
    });

    test('random draw picks an eligible chit and records how', () {
      for (var seed = 1; seed <= 20; seed++) {
        final a = testActions(seed: seed);
        final b = example1(a, start: true);
        final g = b.group;
        a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
        a.randomDraw(g, 0, actor: 'Admin');
        final r = g.rounds[0];
        expect(r.status, RoundStatus.completed);
        expect(r.winnerChitId, isNotNull);
        expect(r.eligibleChitIds, hasLength(4));
        expect(r.eligibleChitIds.contains(r.winnerChitId), isTrue);
        expect(r.resolution, contains('at random'));
        expect(r.completedAt, isNotNull);
        expect(g.feed.last.kind, FeedKind.system);
        expect(g.feed.last.text, contains('wins ₹40,000'));
      }
    });

    test('random draws are fair: every chit comes up, roughly equally', () {
      final counts = <int, int>{};
      for (var seed = 0; seed < 800; seed++) {
        final a = testActions(seed: seed);
        final b = example1(a, start: true);
        final g = b.group;
        a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
        a.randomDraw(g, 0, actor: 'Admin');
        final idx = b.chitIds.indexOf(g.rounds[0].winnerChitId!);
        counts[idx] = (counts[idx] ?? 0) + 1;
      }
      expect(counts.keys.toSet(), <int>{0, 1, 2, 3});
      for (final c in counts.values) {
        expect(c, inInclusiveRange(140, 260)); // expected 200 each
      }
    });

    test('manual pick only accepts eligible chits', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      expect(() => a.randomDraw(g, 0, actor: 'Admin'), violation('not set to a random draw'));
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin', note: 'Needed for a wedding');
      expect(g.rounds[0].winnerChitId, b.chit(2).id);
      expect(g.rounds[0].resolution, contains('wedding'));

      a.openRound(g, 1, method: RoundMethod.manual, actor: 'Admin');
      // B's chit and the BC chit are blocked this month.
      expect(() => a.manualPick(g, 1, chitId: b.chit(1).id, actor: 'Admin'), violation('cannot be picked'));
      expect(() => a.manualPick(g, 1, chitId: b.chit(2).id, actor: 'Admin'), violation('cannot be picked'));
      a.manualPick(g, 1, chitId: b.chit(3).id, actor: 'Admin');
      expect(g.rounds[1].winnerChitId, b.chit(3).id);
    });

    test('the last remaining chit is awarded automatically', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A', 'B'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'B': 10000},
      ], start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
      a.randomDraw(g, 0, actor: 'Admin');
      a.openRound(g, 1, method: RoundMethod.vote, actor: 'Admin');
      final last = g.rounds[1];
      expect(last.status, RoundStatus.completed);
      expect(last.resolution, contains('Only one chit was left'));
      expect(last.relaxed, isFalse);
      expect(g.completed, isTrue);
      expect(g.currentRound, isNull);
      expect(g.feed.last.text, contains('scheme is complete'));
    });

    test('the final chit may have to go to last month\'s winner, and the app says so', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
      ], start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
      a.randomDraw(g, 0, actor: 'Admin');
      a.openRound(g, 1, method: RoundMethod.random, actor: 'Admin');
      expect(g.rounds[1].relaxed, isTrue);
      final resultText = g.feed.firstWhere((f) => f.text.contains('month 2 result')).text;
      expect(resultText, contains('eased'));
    });

    test('fallback draw works only after the announcement date has passed', () {
      var today = DateTime(2026, 11, 14);
      final a = testActions(clock: () => today);
      final b = example1(a, start: true); // first announcement 1 Dec 2026
      final g = b.group;
      expect(() => a.fallbackRandom(g, 0, actor: 'App'), violation('not passed'));
      today = DateTime(2026, 12, 1); // the day itself is still "on time"
      expect(() => a.fallbackRandom(g, 0, actor: 'App'), violation('not passed'));
      today = DateTime(2026, 12, 2);
      a.fallbackRandom(g, 0, actor: 'App');
      final r = g.rounds[0];
      expect(r.status, RoundStatus.completed);
      expect(r.method, RoundMethod.random);
      expect(r.resolution, contains('fallback'));
      expect(() => a.fallbackRandom(g, 0, actor: 'App'), violation());
    });

    test('rescheduling moves the open and later months only', () {
      final a = testActions();
      final b = example1(a, start: true); // 1 Dec, 1 Jan, 1 Feb, 1 Mar
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(0).id, actor: 'Admin');
      a.reschedule(g, DateTime(2027, 1, 10), actor: 'Admin');
      expect(g.rounds.map((r) => r.announcementDate).toList(), <DateTime>[
        DateTime(2026, 12, 1),
        DateTime(2027, 1, 10),
        DateTime(2027, 2, 10),
        DateTime(2027, 3, 10),
      ]);
      expect(() => a.reschedule(buildGroup(a, members: <String>['A', 'B'], chits: <Map<String, int>>[
            <String, int>{'A': 10000},
            <String, int>{'B': 10000},
          ]).group, DateTime(2027, 1, 1), actor: 'x'),
          violation('Start the cycle'));
    });
  });

  group('rounds: voting', () {
    test('the person with the most votes wins and gets one of their chits', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
      void vote(String from, String to) =>
          a.castVote(g, 0, voterId: b.id(from), targetId: b.id(to));
      vote('A', 'A'); // A votes for themselves once
      vote('A', 'B');
      vote('A', 'C');
      vote('B', 'A');
      vote('B', 'C');
      vote('C', 'C');
      vote('D', 'A');
      vote('E', 'C');
      // C: A,B,C,E = 4 votes, A: A,B,D = 3, B: 1
      a.closeVoting(g, 0, actor: 'Admin');
      final r = g.rounds[0];
      expect(r.status, RoundStatus.completed);
      expect(r.winnerMemberId, b.id('C'));
      expect(r.winnerChitId, b.chit(6).id); // C's only chit is the shared BC
      expect(r.resolution, contains('won the vote with 4 votes'));
      final payouts = Rules.roundPayouts(g, r);
      expect(payouts[b.id('B')], 3000 * 8);
      expect(payouts[b.id('C')], 7000 * 8);
    });

    test('a winner with several chits gets one drawn at random from them', () {
      final seen = <String>{};
      for (var seed = 0; seed < 60; seed++) {
        final a = testActions(seed: seed);
        final b = example2(a, start: true);
        final g = b.group;
        a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
        a.castVote(g, 0, voterId: b.id('C'), targetId: b.id('A'));
        a.closeVoting(g, 0, actor: 'Admin');
        final r = g.rounds[0];
        expect(r.winnerMemberId, b.id('A'));
        expect(g.chitById(r.winnerChitId!)!.ownedBy(b.id('A')), isTrue);
        seen.add(r.winnerChitId!);
      }
      // A's four chits (A1, A2, A3, AD) should all turn up over 60 tries.
      expect(seen, hasLength(4));
    });

    test('a tie is settled by a random draw when the group chose that', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, tieBreak: TieBreakMode.auto, actor: 'Admin');
      a.castVote(g, 0, voterId: b.id('C'), targetId: b.id('A'));
      a.castVote(g, 0, voterId: b.id('D'), targetId: b.id('B'));
      a.closeVoting(g, 0, actor: 'Admin');
      final r = g.rounds[0];
      expect(r.status, RoundStatus.completed);
      expect(<String>[b.id('A'), b.id('B')].contains(r.winnerMemberId), isTrue);
      expect(r.resolution, contains('tied on 1 vote'));
    });

    test('a tie waits for the admin when the group chose that', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, tieBreak: TieBreakMode.admin, actor: 'Admin');
      a.castVote(g, 0, voterId: b.id('C'), targetId: b.id('A'));
      a.castVote(g, 0, voterId: b.id('D'), targetId: b.id('B'));
      a.closeVoting(g, 0, actor: 'Admin');
      final r = g.rounds[0];
      expect(r.status, RoundStatus.awaitingTieBreak);
      expect(r.tiedMemberIds.toSet(), <String>{b.id('A'), b.id('B')});
      expect(g.currentRound!.index, 0);
      // No more votes, and only a tied member can be chosen.
      expect(() => a.castVote(g, 0, voterId: b.id('E'), targetId: b.id('A')), violation());
      expect(() => a.adminResolveTie(g, 0, memberId: b.id('C'), actor: 'Admin'), violation('one of the members'));
      a.adminResolveTie(g, 0, memberId: b.id('B'), actor: 'Admin', note: 'B needs it most');
      expect(r.status, RoundStatus.completed);
      expect(r.winnerMemberId, b.id('B'));
      expect(r.resolution, contains('B needs it most'));
      expect(g.chitById(r.winnerChitId!)!.ownedBy(b.id('B')), isTrue);
    });

    test('with no votes at all the app falls back to a random draw', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
      a.closeVoting(g, 0, actor: 'Admin');
      final r = g.rounds[0];
      expect(r.status, RoundStatus.completed);
      expect(r.winnerMemberId, isNull);
      expect(r.resolution, contains('Nobody voted'));
      expect(r.eligibleChitIds, hasLength(8));
    });

    test('closing is refused when nothing is open or the method differs', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      expect(() => a.closeVoting(g, 0, actor: 'Admin'), violation('not open'));
      a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
      expect(() => a.closeVoting(g, 0, actor: 'Admin'), violation('not open'));
    });

    test('voting cannot choose a chit that is blocked, even by a big holder', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(3).id, actor: 'Admin'); // AD wins
      a.openRound(g, 1, method: RoundMethod.vote, actor: 'Admin');
      // A and D are blocked: only B and C (via B, BC) can win.
      a.castVote(g, 1, voterId: b.id('A'), targetId: b.id('C'));
      a.castVote(g, 1, voterId: b.id('B'), targetId: b.id('C'));
      a.closeVoting(g, 1, actor: 'Admin');
      expect(g.rounds[1].winnerChitId, b.chit(2).id);
    });
  });

  group('payouts and the feed', () {
    test('payout hand-over can be marked and undone, for real recipients only', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      expect(() => a.setPayoutDone(g, 0, memberId: b.id('B'), done: true, actor: 'Admin'),
          violation('no winner yet'));
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin'); // BC
      expect(() => a.setPayoutDone(g, 0, memberId: b.id('A'), done: true, actor: 'Admin'),
          violation('not a recipient'));
      a.setPayoutDone(g, 0, memberId: b.id('B'), done: true, actor: 'Admin');
      expect(g.rounds[0].payoutsDone, <String>{b.id('B')});
      expect(g.feed.last.text, contains('received ₹12,000'));
      a.setPayoutDone(g, 0, memberId: b.id('B'), done: false, actor: 'Admin');
      expect(g.rounds[0].payoutsDone, isEmpty);
    });

    test('announcements are trimmed and limited', () {
      final a = testActions();
      final g = a.createGroup(createdAt: kToday, organiserName: 'Asha');
      a.postAnnouncement(g, '  Please pay by Friday  ', actor: 'Asha');
      expect(g.feed.last.text, 'Please pay by Friday');
      expect(g.feed.last.kind, FeedKind.announcement);
      expect(g.feed.last.author, 'Asha');
      expect(() => a.postAnnouncement(g, '   ', actor: 'Asha'), violation());
      expect(() => a.postAnnouncement(g, 'x' * 1001, actor: 'Asha'), violation('under 1000'));
    });

    test('opening a vote posts the rules, and blocked people are named', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin');
      a.openRound(g, 1, method: RoundMethod.vote, tieBreak: TieBreakMode.admin, actor: 'Admin');
      final post = g.feed.last;
      expect(post.kind, FeedKind.announcement);
      expect(post.text, contains('one vote for every chit'));
      expect(post.text, contains('Only your first votes count'));
      expect(post.text, contains('admin decides'));
      expect(post.text, contains('Not eligible this month'));
      expect(post.text, contains('B, C'));
    });
  });

  group('a whole scheme from start to finish', () {
    test('every chit wins exactly once, money balances, rule holds (many seeds)', () {
      for (var seed = 0; seed < 60; seed++) {
        final rng = Random(seed);
        final a = testActions(seed: seed);
        final b = example2(a, start: true);
        final g = b.group;
        final pool = g.poolAmount;
        var lastOwners = <String>{};

        for (var i = 0; i < g.rounds.length; i++) {
          final method = RoundMethod.values[rng.nextInt(3)];
          final tie = TieBreakMode.values[rng.nextInt(2)];
          a.openRound(g, i, method: method, tieBreak: tie, actor: 'Admin');
          final r = g.rounds[i];
          if (!r.isCompleted) {
            switch (r.method!) {
              case RoundMethod.random:
                a.randomDraw(g, i, actor: 'Admin');
              case RoundMethod.manual:
                final elig = Rules.eligibility(g, i).chits;
                a.manualPick(g, i, chitId: elig[rng.nextInt(elig.length)].id, actor: 'Admin');
              case RoundMethod.vote:
                final targets = Rules.eligibleTargets(g, i).map((m) => m.id).toList();
                for (final voter in Rules.votingPowerMap(g).keys) {
                  final shuffled = List<String>.of(targets)..shuffle(rng);
                  final n = rng.nextInt(Rules.votingPower(g, voter) + 1);
                  for (final t in shuffled.take(n)) {
                    a.castVote(g, i, voterId: voter, targetId: t);
                  }
                }
                a.closeVoting(g, i, actor: 'Admin');
                if (r.status == RoundStatus.awaitingTieBreak) {
                  a.adminResolveTie(g, i,
                      memberId: r.tiedMemberIds[rng.nextInt(r.tiedMemberIds.length)], actor: 'Admin');
                }
            }
          }
          expect(r.status, RoundStatus.completed, reason: 'seed $seed month $i');
          final chit = g.chitById(r.winnerChitId!)!;
          expect(r.eligibleChitIds.contains(chit.id), isTrue);
          final payouts = Rules.roundPayouts(g, r);
          expect(payouts.values.fold<int>(0, (x, y) => x + y), pool);
          if (chit.ownerIds.any(lastOwners.contains)) {
            expect(r.relaxed, isTrue, reason: 'seed $seed month $i');
          }
          lastOwners = chit.ownerIds.toSet();
        }

        expect(g.completed, isTrue);
        final winners = g.rounds.map((r) => r.winnerChitId).toList();
        expect(winners.toSet(), hasLength(g.chitCount), reason: 'seed $seed');
        expect(winners.toSet(), g.chits.map((c) => c.id).toSet());
        // Each person ends up receiving exactly what their shares entitle them to
        // over the whole scheme: sum of share x chits = dues x months / chits... checked
        // via totals: everyone receives as much as they pay in over the full cycle.
        final received = <String, int>{};
        for (final r in g.rounds) {
          Rules.roundPayouts(g, r).forEach((m, v) => received[m] = (received[m] ?? 0) + v);
        }
        for (final m in g.members) {
          final paidIn = Rules.monthlyDue(g, m.id) * g.rounds.length;
          expect(received[m.id] ?? 0, paidIn, reason: 'seed $seed ${m.name}');
        }
      }
    });
  });
}
