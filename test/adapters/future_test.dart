import 'dart:async';

import 'package:bark/bark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int notifyCount = 0;

  void onValueChanged() {
    notifyCount++;
  }

  FutureValueAdapter<T> setUpTest<T>(T initial) {
    notifyCount = 0;
    final adapter = FutureValueAdapter(initial);
    adapter.addListener(onValueChanged);
    addTearDown(() => adapter.removeListener(onValueChanged));
    return adapter;
  }

  test('starts with initial value', () {
    final adapter = setUpTest(123);
    expect(adapter.value, 123);
    expect(notifyCount, 0);
  });

  test('value can be updated synchronously', () {
    final adapter = setUpTest(123);
    expect(adapter.value, 123);
    expect(notifyCount, 0);
    adapter.complete(456);
    expect(adapter.value, 456);
    expect(notifyCount, 1);
  });

  test('value can be updated asynchronously', () async {
    final adapter = setUpTest(123);
    adapter.complete(Future.value(456));

    expect(adapter.value, 123);
    expect(notifyCount, 0);
    await pumpEventQueue();
    expect(adapter.value, 456);
    expect(notifyCount, 1);
  });

  test('latest future value is used', () async {
    final adapter = setUpTest(123);
    final completer = Completer<int>();

    adapter.complete(completer.future);
    adapter.complete(Future.value(456));

    expect(adapter.value, 123);
    expect(notifyCount, 0);
    await pumpEventQueue();
    expect(adapter.value, 456);
    expect(notifyCount, 1);

    completer.complete(123);
    await pumpEventQueue();
    // Shouldn't change, the previous Future is ignored.
    expect(adapter.value, 456);
    expect(notifyCount, 1);
  });

  test('completeAsync wraps values correctly', () async {
    final adapter = setUpTest<AsyncState<int, int>>(Loading);
    expect(adapter.value, Loading);
    expect(notifyCount, 0);

    adapter.completeAsync(123, (_) => 0);
    expect(adapter.value, Loaded(123));
    expect(notifyCount, 1);

    adapter.completeAsync(Future.value(456), (_) => 0);
    expect(adapter.value, Loading);
    expect(notifyCount, 2);
    await pumpEventQueue();
    expect(adapter.value, Loaded(456));
    expect(notifyCount, 3);

    adapter.completeAsync(Future.value(789), (_) => 0, gapless: true);
    expect(adapter.value, Loaded(456));
    expect(notifyCount, 3);
    await pumpEventQueue();
    expect(adapter.value, Loaded(789));
    expect(notifyCount, 4);

    adapter.completeAsync(Future.error('Bad'), (_) => 0);
    expect(adapter.value, Loading);
    expect(notifyCount, 5);
    await pumpEventQueue();
    expect(adapter.value, Failed(0));
    expect(notifyCount, 6);
  });
}
