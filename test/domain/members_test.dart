import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'actions_test.dart';

const String phoneD = '+919876500004';

Built started() {
  final a = testActions();
  final b = example1(a, start: true);
  a.renameMember(b.group, b.id('D'), 'D', phone: '9876500004', actor: 'Admin');
  return b;
}

void main() {
  group('leaving and coming back', () {
    test(
      'a member with shares is marked as left and keeps their shares and dues',
      () {
        final a = testActions();
        final b = started();
        final g = b.group;
        final dueBefore = Rules.monthlyDue(g, b.id('D'));
        expect(dueBefore, 5000);

        a.removeMember(g, b.id('D'), actor: 'Admin');
        final d = g.memberById(b.id('D'))!;
        expect(d.left, isTrue);
        expect(d.leftAt, isNotNull);
        expect(g.activeMembers.map((m) => m.name), isNot(contains('D')));
        expect(g.formerMembers.single.name, 'D');
        // The money still adds up.
        expect(Rules.monthlyDue(g, b.id('D')), dueBefore);
        expect(g.chits[3].shares[b.id('D')], 5000);
        expect(g.feed.last.text, contains('left the group'));
      },
    );

    test(
      'a member who left no longer votes, but their chit stays in the draw',
      () {
        final a = testActions();
        final b = started();
        final g = b.group;
        expect(Rules.votingPower(g, b.id('D')), 1);
        final totalBefore = Rules.totalVotes(g);
        a.removeMember(g, b.id('D'), actor: 'Admin');
        expect(Rules.votingPower(g, b.id('D')), 0);
        expect(Rules.totalVotes(g), totalBefore - 1);
        expect(Rules.eligibility(g, 0).chits.length, 4);

        a.openRound(g, 0, method: RoundMethod.vote, actor: 'Admin');
        expect(
          () => a.castVote(g, 0, voterId: b.id('D'), targetId: b.id('A')),
          violation(),
        );
      },
    );

    test(
      'adding the same phone number again restores the member and their shares',
      () {
        final a = testActions();
        final b = started();
        final g = b.group;
        final originalId = b.id('D');
        a.removeMember(g, originalId, actor: 'Admin');

        final back = a.addMember(
          g,
          'Dinesh',
          phone: '+91 98765 00004',
          actor: 'Admin',
        );
        expect(back.id, originalId);
        expect(back.left, isFalse);
        expect(back.leftAt, isNull);
        expect(g.members.length, 4); // no duplicate person
        expect(g.chits[3].shares[originalId], 5000);
        expect(Rules.votingPower(g, originalId), 1);
        expect(g.feed.last.text, contains('rejoined'));
        expect(g.feed.last.text, contains('Chit 4'));
      },
    );

    test('"add back" restores by member without needing the number', () {
      final a = testActions();
      final b = started();
      final g = b.group;
      a.removeMember(g, b.id('C'), actor: 'Admin');
      expect(g.memberById(b.id('C'))!.left, isTrue);
      a.restoreMember(g, b.id('C'), actor: 'Admin');
      expect(g.memberById(b.id('C'))!.left, isFalse);
      expect(
        () => a.restoreMember(g, b.id('C'), actor: 'Admin'),
        violation('already in the group'),
      );
    });

    test('a number that is already active cannot be added twice', () {
      final a = testActions();
      final b = started();
      expect(
        () => a.addMember(
          b.group,
          'Someone',
          phone: '9876500004',
          actor: 'Admin',
        ),
        violation('already in this group'),
      );
    });

    test(
      'a name used by a former member cannot be reused for a different person',
      () {
        final a = testActions();
        final b = started();
        final g = b.group;
        a.removeMember(g, b.id('D'), actor: 'Admin');
        expect(
          () => a.addMember(g, 'd', phone: '9123456789', actor: 'Admin'),
          violation('former members'),
        );
      },
    );

    test('phone numbers are checked and kept unique', () {
      final a = testActions();
      final b = started();
      final g = b.group;
      expect(
        () => a.addMember(g, 'New', phone: '12345', actor: 'Admin'),
        violation('10-digit'),
      );
      expect(
        () => a.renameMember(
          g,
          b.id('A'),
          'A',
          phone: '9876500004',
          actor: 'Admin',
        ),
        violation('already belongs to D'),
      );
      a.renameMember(g, b.id('A'), 'A', phone: '9876500001', actor: 'Admin');
      expect(g.memberById(b.id('A'))!.phone, '+919876500001');
    });

    test('removing twice, or the last member, is refused', () {
      final a = testActions();
      final b = started();
      final g = b.group;
      a.removeMember(g, b.id('D'), actor: 'Admin');
      expect(
        () => a.removeMember(g, b.id('D'), actor: 'Admin'),
        violation('already left'),
      );
      a.removeMember(g, b.id('C'), actor: 'Admin');
      a.removeMember(g, b.id('B'), actor: 'Admin');
      expect(
        () => a.removeMember(g, b.id('A'), actor: 'Admin'),
        violation('at least one member'),
      );
    });

    test('someone with no shares and no history is simply deleted', () {
      final a = testActions();
      final b = example1(a);
      final extra = a.addMember(b.group, 'Meena', actor: 'Admin');
      a.removeMember(b.group, extra.id, actor: 'Admin');
      expect(b.group.memberById(extra.id), isNull);
    });
  });

  group('shares and people who left', () {
    test('a member who left cannot be given a new share', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      a.removeMember(g, b.id('D'), actor: 'Admin');
      expect(
        () => a.addChit(g, <String, int>{b.id('D'): 10000}, actor: 'Admin'),
        violation('has left the group'),
      );
      expect(
        () => a.updateChitShares(g, g.chits[0].id, <String, int>{
          b.id('A'): 5000,
          b.id('D'): 5000,
        }, actor: 'Admin'),
        violation('has left the group'),
      );
    });

    test('shares of someone who left can be handed to another member', () {
      final a = testActions();
      final b = started();
      final g = b.group;
      a.removeMember(g, b.id('D'), actor: 'Admin');
      // Chit 4 was A 5000 + D 5000; hand D's share to B (everyone agreed).
      a.updateChitShares(
        g,
        g.chits[3].id,
        <String, int>{b.id('A'): 5000, b.id('B'): 5000},
        actor: 'Admin',
        coOwnersAgreed: true,
      );
      expect(g.chits[3].ownedBy(b.id('D')), isFalse);
      expect(Rules.monthlyDue(g, b.id('D')), 0);
      expect(
        Rules.monthlyDue(g, b.id('B')),
        18000,
      ); // 10,000 + 3,000 + the 5,000 handed over
    });

    test('a member who left may keep the share they already had', () {
      final a = testActions();
      final b = started();
      final g = b.group;
      a.removeMember(g, b.id('D'), actor: 'Admin');
      a.updateChitShares(
        g,
        g.chits[3].id,
        <String, int>{b.id('A'): 6000, b.id('D'): 4000},
        actor: 'Admin',
        coOwnersAgreed: true,
      );
      expect(g.chits[3].shares[b.id('D')], 4000);
    });
  });

  group('readiness and saving', () {
    test('planned members are compared with people who are still in', () {
      final a = testActions();
      final b = example1(a);
      final g = b.group;
      a.setPlannedMembers(g, 4, actor: 'Admin');
      expect(
        Rules.readiness(g).any((i) => i.message.contains('You planned')),
        isFalse,
      );
      a.removeMember(g, b.id('D'), actor: 'Admin');
      expect(
        Rules.readiness(
          g,
        ).any((i) => i.message.contains('You planned 4 members and have 3')),
        isTrue,
      );
    });

    test(
      'left status survives saving; old data without it loads as active',
      () {
        final a = testActions();
        final b = started();
        final g = b.group;
        a.removeMember(g, b.id('D'), actor: 'Admin');
        final copy = ChitGroup.fromJson(g.toJson());
        expect(copy.memberById(b.id('D'))!.left, isTrue);
        expect(copy.memberById(b.id('D'))!.leftAt, isNotNull);
        expect(copy.memberById(b.id('D'))!.phone, phoneD);

        final old = Member.fromJson(<String, dynamic>{
          'id': 'x',
          'name': 'Old',
          'phone': null,
        });
        expect(old.left, isFalse);
        expect(old.leftAt, isNull);
      },
    );
  });
}
