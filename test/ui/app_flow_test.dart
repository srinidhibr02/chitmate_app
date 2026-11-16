import 'package:chit_mate/app.dart';
import 'package:chit_mate/data/repository.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/state/app_state.dart';
import 'package:chit_mate/theme/app_theme.dart';
import 'package:chit_mate/ui/sheets/chit_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<AppState> readyState({bool withGroup = true}) async {
  final s = AppState(
    repository: InMemoryRepository(),
    actions: testActions(),
    clock: () => kToday,
  );
  await s.init();
  if (withGroup) {
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday, name: 'Friends', chitValue: 10000);
    final id = s.groups.first.id;
    await s.run(id, (g) => s.actions.addMember(g, 'Ravi', actor: 'Asha'));
  }
  return s;
}

void main() {
  testWidgets('a returning organiser lands on the home screen', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Friends'), findsWidgets);
  });

  testWidgets('a new install is not sent straight to the home screen', (tester) async {
    final s = await readyState(withGroup: false);
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Friends'), findsNothing);
    expect(s.needsOnboarding, isTrue);
  });

  testWidgets('opening a group shows its five tabs', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Friends').first);
    await tester.pumpAndSettle();
    for (final label in <String>['Overview', 'Chits', 'Round', 'Payments', 'Updates']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Chits').last);
    await tester.pumpAndSettle();
    expect(find.text('Ravi'), findsWidgets);
    await tester.tap(find.text('Updates').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('announcement-field')), findsOneWidget);
    await tester.tap(find.text('Round').last);
    await tester.pumpAndSettle();
    expect(find.text('The cycle has not started'), findsOneWidget);
  });

  testWidgets('the chit editor only saves when shares add up', (tester) async {
    final s = await readyState();
    final id = s.groups.first.id;
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ChitEditorScreen(groupId: id)),
                  ),
                  child: const Text('open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.byKey(const Key('save-chit')));
    expect(saveButton().onPressed, isNull);

    // Tick Asha and let the app fill in the full amount.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fill the rest').first);
    await tester.pumpAndSettle();
    expect(find.text('₹10,000 of ₹10,000 assigned'), findsOneWidget);
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save-chit')));
    await tester.pumpAndSettle();
    final g = s.groupById(id)!;
    expect(g.chits.length, 1);
    expect(g.chits.first.shares.values.single, 10000);
    expect(find.text('open editor'), findsOneWidget);
  });

  testWidgets('a shared chit can be split between two people', (tester) async {
    final s = await readyState();
    final id = s.groups.first.id;
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ChitEditorScreen(groupId: id)),
                  ),
                  child: const Text('open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split equally'));
    await tester.pumpAndSettle();
    expect(find.text('₹10,000 of ₹10,000 assigned'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-chit')));
    await tester.pumpAndSettle();
    final chit = s.groups.first.chits.single;
    expect(chit.shares.length, 2);
    expect(chit.total, 10000);
    expect(chit.isFull, isFalse);
    expect(RoundMethod.values.length, 3);
  });

  testWidgets('a member who left can be added back from the Chits tab', (tester) async {
    final s = await readyState();
    final id = s.groups.first.id;
    await s.run(id, (g) {
      final ravi = g.members.firstWhere((m) => m.name == 'Ravi');
      s.actions.addChit(g, <String, int>{ravi.id: 10000}, actor: 'Asha');
      s.actions.removeMember(g, ravi.id, actor: 'Asha');
    });
    expect(s.groupById(id)!.formerMembers.single.name, 'Ravi');

    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Friends').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chits').last);
    await tester.pumpAndSettle();
    expect(find.text('Former members'), findsOneWidget);

    await tester.tap(find.text('Add back'));
    await tester.pumpAndSettle();
    expect(s.groupById(id)!.formerMembers, isEmpty);
    expect(find.text('Former members'), findsNothing);
  });
}
