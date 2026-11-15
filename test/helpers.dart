import 'dart:math';

import 'package:chit_mate/domain/actions.dart';
import 'package:chit_mate/domain/models.dart';

/// Fixed "today" for tests: 14 Nov 2026, 10:00.
final DateTime kToday = DateTime(2026, 11, 14, 10);

ChitActions testActions({int seed = 1, DateTime Function()? clock}) =>
    ChitActions(random: Random(seed), clock: clock ?? () => kToday);

/// A group built from readable names, plus a name -> member id lookup.
class Built {
  Built(this.group, this.ids, this.chitIds);

  final ChitGroup group;
  final Map<String, String> ids;

  /// Chit ids in the order they were given.
  final List<String> chitIds;

  String id(String name) => ids[name]!;
  Chit chit(int i) => group.chitById(chitIds[i])!;
}

/// Builds a group with [members] and one chit per entry of [chits] (each a
/// map of member name -> rupees). Starts the cycle when [start] is true.
Built buildGroup(
  ChitActions a, {
  int value = 10000,
  required List<String> members,
  required List<Map<String, int>> chits,
  DateTime? first,
  bool start = false,
  String name = 'Test group',
}) {
  final g = a.createGroup(
    createdAt: kToday,
    organiserName: '',
    name: name,
    chitValue: value,
  );
  final ids = <String, String>{};
  for (final m in members) {
    ids[m] = a.addMember(g, m, actor: 'Admin').id;
  }
  final chitIds = <String>[];
  for (final c in chits) {
    final shares = <String, int>{for (final e in c.entries) ids[e.key]!: e.value};
    chitIds.add(a.addChit(g, shares, actor: 'Admin').id);
  }
  a.setFirstAnnouncementDate(g, first ?? DateTime(2026, 12, 1), actor: 'Admin');
  if (start) a.startCycle(g, actor: 'Admin');
  return Built(g, ids, chitIds);
}

/// Example 1 from the conversation: A, B, BC (3000/7000), AD (5000/5000).
Built example1(ChitActions a, {bool start = false}) => buildGroup(
      a,
      members: <String>['A', 'B', 'C', 'D'],
      chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'B': 10000},
        <String, int>{'B': 3000, 'C': 7000},
        <String, int>{'A': 5000, 'D': 5000},
      ],
      start: start,
    );

/// Example 2: A has 3 full chits + AD; B has 2 full + BC + BE.
Built example2(ChitActions a, {bool start = false}) => buildGroup(
      a,
      members: <String>['A', 'B', 'C', 'D', 'E'],
      chits: <Map<String, int>>[
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
        <String, int>{'A': 10000},
        <String, int>{'A': 5000, 'D': 5000},
        <String, int>{'B': 10000},
        <String, int>{'B': 10000},
        <String, int>{'B': 3000, 'C': 7000},
        <String, int>{'B': 5000, 'E': 5000},
      ],
      start: start,
    );
