import 'package:bark/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'counter.dart';

void main() {
  CounterBloc bloc;
  TestComponent<CounterView> component;

  setUp(() {
    bloc = CounterBloc();

    component = TestComponent(bloc);
  });

  test('initial value is zero', () {
    expect(component.latestValue.count, '0');
  });

  test('increment causes value to increase', () {
    expect(component.latestValue.count, '0');
    component.latestValue.onIncrement();
    expect(component.latestValue.count, '1');
  });

  test('increment to 100 dispatches congrats message', () {
    for (int i=0; i<100; i++) {
      component.latestValue.onIncrement();
    }

    expect(component.messages, [
      const ShowCongratsScreen(),
    ]);
  });
}
