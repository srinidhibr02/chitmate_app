import 'package:chit_mate/ui/widgets/draw_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('the wheel spins, then stops on the winner and reports it', (tester) async {
    var finished = 0;
    await tester.pumpWidget(host(DrawWheel(
      candidates: const <String>['Chit 1', 'Chit 2', 'Chit 3', 'Chit 4', 'Chit 5'],
      winner: 'Chit 4',
      onFinished: () => finished++,
    )));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(finished, 0);
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(tester.widget<Text>(find.byKey(const Key('wheel-label'))).data, 'Chit 4');
  });

  testWidgets('a winner missing from the list is added as a slice', (tester) async {
    await tester.pumpWidget(host(DrawWheel(
      candidates: const <String>['A', 'B'],
      winner: 'C',
      onFinished: () {},
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('wheel-label'))).data, 'C');
  });
}
