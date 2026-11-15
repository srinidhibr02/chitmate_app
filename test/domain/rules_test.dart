import 'package:chit_mate/domain/actions.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('money (example 1: A, B, BC, AD)', () {
    test('monthly dues, pool and voting power', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      expect(g.chitCount, 4);
      expect(g.poolAmount, 40000);
      expect(Rules.monthlyDue(g, b.id('A')), 15000);
      expect(Rules.monthlyDue(g, b.id('B')), 13000);
      expect(Rules.monthlyDue(g, b.id('C')), 7000);
      expect(Rules.monthlyDue(g, b.id('D')), 5000);
      final total = <String>['A', 'B', 'C', 'D']
          .fold<int>(0, (s, n) => s + Rules.monthlyDue(g, b.id(n)));
      expect(total, g.poolAmount);
      for (final n in <String>['A', 'B', 'C', 'D']) {
        expect(Rules.votingPower(g, b.id(n)), 1, reason: n);
      }
    });

    test('payouts follow the shares exactly', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      final bc = Rules.payoutFor(g, b.chit(2));
      expect(bc[b.id('B')], 12000);
      expect(bc[b.id('C')], 28000);
      final ad = Rules.payoutFor(g, b.chit(3));
      expect(ad[b.id('A')], 20000);
      expect(ad[b.id('D')], 20000);
      expect(Rules.payoutFor(g, b.chit(0)), <String, int>{b.id('A'): 40000});
      for (var i = 0; i < 4; i++) {
        expect(Rules.payoutFor(g, b.chit(i)).values.fold<int>(0, (x, y) => x + y), 40000);
      }
    });
  });

  group('voting power (example 2)', () {
    test('one vote per full chit; shares-only holders get one', () {
      final a = testActions();
      final b = example2(a);
      final g = b.group;
      expect(g.chitCount, 8);
      expect(g.poolAmount, 80000);
      expect(Rules.votingPower(g, b.id('A')), 3);
      expect(Rules.votingPower(g, b.id('B')), 2);
      expect(Rules.votingPower(g, b.id('C')), 1);
      expect(Rules.votingPower(g, b.id('D')), 1);
      expect(Rules.votingPower(g, b.id('E')), 1);
      expect(Rules.totalVotes(g), 8);
      expect(Rules.monthlyDue(g, b.id('A')), 35000);
      expect(Rules.monthlyDue(g, b.id('B')), 28000);
      expect(Rules.monthlyDue(g, b.id('C')), 7000);
      expect(Rules.monthlyDue(g, b.id('D')), 5000);
      expect(Rules.monthlyDue(g, b.id('E')), 5000);
    });

    test('a member with no chit has no vote', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A', 'B', 'Z'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'B': 10000},
      ]);
      expect(Rules.votingPower(b.group, b.id('Z')), 0);
      expect(Rules.votingPowerMap(b.group).containsKey(b.id('Z')), isFalse);
    });

    test('shares in shared chits never add votes on top of full chits', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A', 'B'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'A': 4000, 'B': 6000},
        <String, int>{'A': 5000, 'B': 5000},
      ]);
      expect(Rules.votingPower(b.group, b.id('A')), 1);
      expect(Rules.votingPower(b.group, b.id('B')), 1);
    });

    test('concentration warning appears above 40% only', () {
      final a = testActions();
      final fine = example2(a).group; // A: 3 of 8 = 37.5%
      expect(Rules.concentrationWarnings(fine), isEmpty);

      final heavy = buildGroup(a, members: <String>['A', 'B', 'C'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
        <String, int>{'B': 10000},
        <String, int>{'C': 10000},
      ]);
      final w = Rules.concentrationWarnings(heavy.group);
      expect(w, hasLength(1));
      expect(w.first.memberId, heavy.id('A'));
      expect(w.first.votes, 3);
      expect(w.first.total, 5);
      expect(w.first.share, closeTo(0.6, 1e-9));
    });
  });

  group('eligibility and the no-back-to-back rule', () {
    test('everything is eligible in the first month', () {
      final a = testActions();
      final b = example1(a, start: true);
      final e = Rules.eligibility(b.group, 0);
      expect(e.chits, hasLength(4));
      expect(e.relaxed, isFalse);
      expect(e.blockedMemberIds, isEmpty);
    });

    test('co-owners of last month\'s winner are blocked, and so are their chits', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin'); // BC wins
      final e = Rules.eligibility(g, 1);
      expect(e.relaxed, isFalse);
      expect(e.blockedMemberIds, <String>{b.id('B'), b.id('C')});
      // B's own chit and BC are out; A and AD stay in.
      expect(e.chits.map((c) => c.id).toList(), <String>[b.chit(0).id, b.chit(3).id]);
      final targets = Rules.eligibleTargets(g, 1).map((m) => m.id).toList();
      expect(targets, <String>[b.id('A'), b.id('D')]);
    });

    test('a chit that has won never comes back', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(0).id, actor: 'Admin');
      for (var round = 1; round < 4; round++) {
        expect(Rules.eligibility(g, round).chitIds.contains(b.chit(0).id), isFalse);
      }
    });

    test('rule is eased only when every remaining chit touches the winners', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
      ], start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
      a.randomDraw(g, 0, actor: 'Admin');
      final e = Rules.eligibility(g, 1);
      expect(e.relaxed, isTrue);
      expect(e.chits, hasLength(1));
    });

    test('when eased, only the least-overlapping chits stay eligible', () {
      final a = testActions();
      // c1 {A,D} wins first. Then c2 {A} overlaps once, c3 {A,D} overlaps twice.
      final b = buildGroup(a, members: <String>['A', 'D'], chits: <Map<String, int>>[
        <String, int>{'A': 5000, 'D': 5000},
        <String, int>{'A': 10000},
        <String, int>{'A': 4000, 'D': 6000},
      ], start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(0).id, actor: 'Admin');
      final e = Rules.eligibility(g, 1);
      expect(e.relaxed, isTrue);
      expect(e.chits.map((c) => c.id).toList(), <String>[b.chit(1).id]);
    });

    test('nothing is eligible once every chit has won', () {
      final a = testActions();
      final b = buildGroup(a, members: <String>['A', 'B'], chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'B': 10000},
      ], start: true);
      final g = b.group;
      for (var i = 0; i < 2; i++) {
        a.openRound(g, i, method: RoundMethod.random, actor: 'Admin');
        if (!g.rounds[i].isCompleted) a.randomDraw(g, i, actor: 'Admin');
      }
      expect(Rules.eligibility(g, 2).chits, isEmpty);
      expect(Rules.unwonChits(g), isEmpty);
    });
  });

  group('vote validation', () {
    Built openVote({TieBreakMode tie = TieBreakMode.auto}) {
      final a = testActions();
      final b = example2(a, start: true);
      a.openRound(b.group, 0, method: RoundMethod.vote, tieBreak: tie, actor: 'Admin');
      return b;
    }

    test('accepts a normal vote, including a vote for yourself once', () {
      final b = openVote();
      final r = b.group.rounds[0];
      expect(Rules.voteError(b.group, r, b.id('A'), b.id('A')), isNull);
      expect(Rules.voteError(b.group, r, b.id('A'), b.id('B')), isNull);
    });

    test('refuses more votes than the voter has', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
      a.castVote(g, 0, voterId: b.id('C'), targetId: b.id('A'));
      expect(Rules.votesLeft(g, g.rounds[0], b.id('C')), 0);
      final err = Rules.voteError(g, g.rounds[0], b.id('C'), b.id('B'));
      expect(err, contains('already used'));
      expect(() => a.castVote(g, 0, voterId: b.id('C'), targetId: b.id('B')),
          throwsA(isA<RuleViolation>()));
      expect(g.rounds[0].votes, hasLength(1));
    });

    test('refuses two votes from one voter to the same person', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
      a.castVote(g, 0, voterId: b.id('A'), targetId: b.id('B'));
      expect(Rules.voteError(g, g.rounds[0], b.id('A'), b.id('B')),
          contains('different person'));
      // ...but a different person is fine, and A still has votes left.
      expect(Rules.votesLeft(g, g.rounds[0], b.id('A')), 2);
      a.castVote(g, 0, voterId: b.id('A'), targetId: b.id('C'));
      a.castVote(g, 0, voterId: b.id('A'), targetId: b.id('A'));
      expect(Rules.votesLeft(g, g.rounds[0], b.id('A')), 0);
      expect(g.rounds[0].votes, hasLength(3));
    });

    test('a member without a chit cannot vote', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      a.addMember(g, 'Visitor', actor: 'Admin');
      a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
      final visitor = g.members.last.id;
      expect(Rules.voteError(g, g.rounds[0], visitor, b.id('A')), contains('no chit'));
    });

    test('cannot vote when the round is not a vote or not open', () {
      final a = testActions();
      final b = example2(a, start: true);
      final g = b.group;
      expect(Rules.voteError(g, g.rounds[0], b.id('A'), b.id('B')), isNotNull);
      a.openRound(g, 0, method: RoundMethod.random, actor: 'Admin');
      expect(Rules.voteError(g, g.rounds[0], b.id('A'), b.id('B')), contains('not decided by a vote'));
    });

    test('cannot vote for someone who is not eligible this month', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.openRound(g, 0, method: RoundMethod.manual, actor: 'Admin');
      a.manualPick(g, 0, chitId: b.chit(2).id, actor: 'Admin'); // BC wins
      a.openRound(g, 1, method: RoundMethod.vote, actor: 'Admin');
      final r = g.rounds[1];
      expect(Rules.voteError(g, r, b.id('A'), b.id('B')), contains('cannot receive votes'));
      expect(Rules.voteError(g, r, b.id('A'), b.id('C')), contains('cannot receive votes'));
      expect(Rules.voteError(g, r, b.id('B'), b.id('A')), isNull);
      expect(Rules.voteError(g, r, b.id('B'), b.id('D')), isNull);
    });

    test('tally finds the leaders and reports ties in a stable order', () {
      final b = openVote();
      final g = b.group;
      final r = g.rounds[0];
      expect(Rules.tally(r).hasVotes, isFalse);
      r.votes
        ..add(Vote(voterId: b.id('A'), targetId: b.id('B'), at: kToday))
        ..add(Vote(voterId: b.id('B'), targetId: b.id('A'), at: kToday))
        ..add(Vote(voterId: b.id('C'), targetId: b.id('B'), at: kToday));
      final t = Rules.tally(r);
      expect(t.leaders, <String>[b.id('B')]);
      expect(t.topVotes, 2);
      expect(t.isTie, isFalse);
      r.votes.add(Vote(voterId: b.id('D'), targetId: b.id('A'), at: kToday));
      final t2 = Rules.tally(r);
      expect(t2.isTie, isTrue);
      expect(t2.leaders, <String>[b.id('A'), b.id('B')]..sort());
    });
  });

  group('payments', () {
    test('status moves from pending to partial to paid', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      final r = g.rounds[0];
      final early = DateTime(2026, 11, 20);
      expect(Rules.paymentStatus(g, r, b.id('A'), early), PaymentStatus.pending);
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 5000, actor: 'Admin');
      expect(Rules.paymentStatus(g, r, b.id('A'), early), PaymentStatus.partial);
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 15000, actor: 'Admin');
      expect(Rules.paymentStatus(g, r, b.id('A'), early), PaymentStatus.paid);
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 0, actor: 'Admin');
      expect(Rules.paymentStatus(g, r, b.id('A'), early), PaymentStatus.pending);
    });

    test('unpaid dues become overdue after the announcement date', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      final r = g.rounds[0]; // announcement 1 Dec 2026
      expect(Rules.paymentStatus(g, r, b.id('A'), DateTime(2026, 12, 1)), PaymentStatus.pending);
      expect(Rules.paymentStatus(g, r, b.id('A'), DateTime(2026, 12, 2)), PaymentStatus.overdue);
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 15000, actor: 'Admin');
      expect(Rules.paymentStatus(g, r, b.id('A'), DateTime(2026, 12, 2)), PaymentStatus.paid);
    });

    test('payments are limited to what is due', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      expect(() => a.recordPayment(g, 0, memberId: b.id('A'), amount: 15001, actor: 'Admin'),
          throwsA(isA<RuleViolation>()));
      expect(() => a.recordPayment(g, 0, memberId: b.id('A'), amount: -1, actor: 'Admin'),
          throwsA(isA<RuleViolation>()));
      expect(() => a.recordPayment(g, 9, memberId: b.id('A'), amount: 1, actor: 'Admin'),
          throwsA(isA<RuleViolation>()));
      expect(g.rounds[0].paid, isEmpty);
    });

    test('outstanding adds up unpaid dues of rounds whose date has passed', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      final afterFirst = DateTime(2026, 12, 2);
      expect(Rules.outstanding(g, b.id('A'), afterFirst), 15000);
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 10000, actor: 'Admin');
      expect(Rules.outstanding(g, b.id('A'), afterFirst), 5000);
      expect(Rules.outstanding(g, b.id('A'), DateTime(2026, 11, 20)), 0);
      // Second month's date (1 Jan) has also passed.
      expect(Rules.outstanding(g, b.id('A'), DateTime(2027, 1, 2)), 5000 + 15000);
    });

    test('collected sums what has been paid in', () {
      final a = testActions();
      final b = example1(a, start: true);
      final g = b.group;
      a.recordPayment(g, 0, memberId: b.id('A'), amount: 15000, actor: 'Admin');
      a.recordPayment(g, 0, memberId: b.id('D'), amount: 2000, actor: 'Admin');
      expect(Rules.collected(g.rounds[0]), 17000);
    });
  });

  group('setupProgress', () {
    test('moves from 0 to 1 as the checklist is completed', () {
      final a = testActions();
      final g = a.createGroup(createdAt: kToday, organiserName: 'Me');
      expect(Rules.setupProgress(g), 0);
      a.setChitValue(g, 10000, actor: 'Me');
      expect(Rules.setupProgress(g), 0.25);
      final other = a.addMember(g, 'Ravi', actor: 'Me');
      final me = g.members.first;
      a.addChit(g, <String, int>{me.id: 10000}, actor: 'Me');
      expect(Rules.setupProgress(g), 0.5); // value + valid chits, but only 1 chit
      a.addChit(g, <String, int>{other.id: 10000}, actor: 'Me');
      expect(Rules.setupProgress(g), 0.75);
      a.setFirstAnnouncementDate(g, DateTime(2026, 12, 1), actor: 'Me');
      expect(Rules.setupProgress(g), 1);
    });
  });

  group('equalSplit', () {
    test('adds up exactly and spreads the remainder', () {
      expect(Rules.equalSplit(10000, 2), <int>[5000, 5000]);
      expect(Rules.equalSplit(10000, 3), <int>[3334, 3333, 3333]);
      expect(Rules.equalSplit(10000, 4), <int>[2500, 2500, 2500, 2500]);
      expect(Rules.equalSplit(10, 3), <int>[4, 3, 3]);
      expect(Rules.equalSplit(7, 1), <int>[7]);
      expect(Rules.equalSplit(5, 0), isEmpty);
      for (var parts = 1; parts <= 12; parts++) {
        expect(Rules.equalSplit(10001, parts).fold<int>(0, (a, b) => a + b), 10001);
      }
    });
  });

  group('readiness', () {
    test('a brand new group lists what is missing', () {
      final a = testActions();
      final g = a.createGroup(createdAt: kToday, organiserName: 'Me');
      final issues = Rules.readiness(g);
      final blocking = issues.where((i) => i.blocking).map((i) => i.message).toList();
      expect(blocking.any((m) => m.contains('chit value')), isTrue);
      expect(blocking.any((m) => m.contains('at least 2 chits')), isTrue);
      expect(blocking.any((m) => m.contains('first announcement date')), isTrue);
      expect(issues.any((i) => !i.blocking && i.message.contains('Me has no chit')), isTrue);
      expect(Rules.isReady(g), isFalse);
      expect(() => a.startCycle(g, actor: 'Me'), throwsA(isA<RuleViolation>()));
    });

    test('shows when planned members differ from actual', () {
      final a = testActions();
      final g = a.createGroup(
          createdAt: kToday, organiserName: 'Me', chitValue: 5000, plannedMembers: 5);
      final msgs = Rules.readiness(g).map((i) => i.message).toList();
      expect(msgs.any((m) => m.contains('planned 5 members and have 1')), isTrue);
    });

    test('a complete group is ready and has no blocking issues', () {
      final a = testActions();
      final b = example1(a);
      expect(Rules.isReady(b.group), isTrue);
      expect(Rules.readiness(b.group).where((i) => i.blocking), isEmpty);
    });

    test('shares that do not add up block the start', () {
      final a = testActions();
      final b = example1(a);
      a.setChitValue(b.group, 20000, actor: 'Admin');
      // Solo chits followed the new value; the shared chits did not.
      expect(b.chit(0).shares.values.single, 20000);
      expect(b.chit(2).total, 10000);
      final msgs = Rules.readiness(b.group).where((i) => i.blocking).map((i) => i.message);
      expect(msgs.any((m) => m.contains('Chit 3') && m.contains('₹10,000 more')), isTrue);
      expect(Rules.isReady(b.group), isFalse);
    });

    test('sharesError explains each way a chit can be wrong', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      expect(Rules.sharesError(g, <String, int>{}), contains('at least one owner'));
      expect(Rules.sharesError(g, <String, int>{b.id('A'): 0, b.id('B'): 10000}),
          contains('more than ₹0'));
      expect(Rules.sharesError(g, <String, int>{b.id('A'): 4000}), contains('₹6,000 more'));
      expect(Rules.sharesError(g, <String, int>{b.id('A'): 12000}), contains('₹2,000 over'));
      expect(Rules.sharesError(g, <String, int>{'nobody': 10000}), contains('Unknown member'));
      expect(Rules.sharesError(g, <String, int>{b.id('A'): 10000}), isNull);
    });
  });
}
