## [0.1.0] - 12/27/2020

* Null-safety migration
* **NEW!** Heavily simplified state tracking using late variables
    * Code written before this version is not directly compatible
    * `Source` -> `LiveValue`
    * LiveValue still implements ValueListenable

### Migration:

Before:
```dart
class CounterBloc extends Bloc<CounterView> {
  final _count = ValueNotifier<int>(0);

  @override
  CounterView viewModel(BlocContext context) {
    // ⭐ Easy value tracking:
    final count = context.trackValue(_count, #count);

    return CounterView(
      count: '$count',
      onIncrement: () {
        _count.value++;
        if (_count.value == 100) {
          // ⭐ Decoupled and testable access to BuildContext:
          context.dispatch(const ShowCongratsScreen());
        }
      },
    );
  }
}
```

After:
```dart
class CounterBloc extends Bloc<CounterView> {
  // ⭐ Easy value tracking:
  late final StateMember<int> _count = state(0);

  @override
  CounterView buildValue() {
    final count = _count.value;

    return CounterView(
      count: '$count',
      onIncrement: () {
        _count.value++;
        if (_count.value == 100) {
          // ⭐ Decoupled and testable access to BuildContext:
          dispatch(const ShowCongratsScreen());
        }
      },
    );
  }
}
```

* `trackValue` + `ValueNotifier` pattern now has first class support, `StateMember` & `state` ext fun
* For other `trackValue` usages, use `ValueListenableMember` & `valueListenable` ext fun
* `isFirstValue`, `lastValue`, `singleton` are no longer supported
  * For `isFirstValue` and `lastValue`, use a normal field
  * `singleton` may come back in the future
* Future and Stream adapters still exist, but  they now have first class support
* `BlocContext` has been removed and `viewModel` has been renamed to `buildValue`.
* Blocs and their value-only counterparts (then `Source`, now `LiveValue`) now have a unified type hierarchy
* `dispatch` has graduated from the now-removed `BlocContext`

## [0.0.1] - 06/13/2020

* Initial release! No examples, no tests, just code.
