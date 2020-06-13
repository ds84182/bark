# bark

A minimal-dependency library for business logic and state management in Flutter.

Very much pre-alpha. Use at your own risk!

## Example: Counter

```dart
import 'package:flutter/material.dart';
import 'package:bark/bark.dart';

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

class ShowCongratsScreen extends BlocMessage<void> with NullOnFailure {
  const ShowCongratsScreen();

  void call(SafeBuildContext context) {
    Navigator.of(context).pushNamed('congrats');
  }
}

// ⭐ Decoupled, testable UIs:
class CounterView extends StatelessWidget with View {
  final String count;
  final VoidCallback onIncrement;

  const CounterView({
    Key key,
    @required this.count,
    @required this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Text(count),
      onTap: onIncrement,
    );
  }
}

// ⭐ Simple glue between business and UI worlds:
class CounterComponent extends SimpleViewComponent<Null, CounterView> {
  const CounterComponent();

  Null get params => null;

  @override
  Bloc<CounterView> createBloc(BuildContext context) => CounterBloc();
}

void main() {
  runApp(MaterialApp(home: Scaffold(body: Center(child: CounterComponent()))));
}
```
