import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'counter.dart';

void main() {
  Widget counterHarness() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CounterComponent(),
        ),
      ),
      routes: {
        'congrats': (context) {
          return Scaffold(
            body: Center(
              child: Text('Congrats!'),
            ),
          );
        },
      },
    );
  }

  testWidgets('counter initializes to zero', (tester) async {
    await tester.pumpWidget(counterHarness());

    expect(find.byType(RaisedButton), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('counter increments when tapped', (tester) async {
    await tester.pumpWidget(counterHarness());

    await tester.tap(find.byType(RaisedButton));
    await tester.pump();

    expect(find.byType(RaisedButton), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('counter displays congrats page at 100', (tester) async {
    await tester.pumpWidget(counterHarness());

    for (int i=0; i<99; i++) {
      await tester.tap(find.byType(RaisedButton));
      await tester.pump();
    }

    expect(find.byType(RaisedButton), findsOneWidget);
    expect(find.text('99'), findsOneWidget);

    await tester.tap(find.byType(RaisedButton));
    await tester.pumpAndSettle();

    expect(find.byType(RaisedButton), findsNothing);
    expect(find.text('Congrats!'), findsOneWidget);

    final navigator = tester.allStates.whereType<NavigatorState>().single;

    navigator.pop();

    await tester.pumpAndSettle();

    expect(find.byType(RaisedButton), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
}
