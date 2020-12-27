import 'package:flutter/material.dart';
import 'package:bark/bark.dart';

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

class ShowCongratsScreen extends BlocMessage<void> with NoOpOnFailure {
  const ShowCongratsScreen();

  void call(SafeBuildContext context) {
    Navigator.of(context.context).pushNamed('congrats');
  }
}

// ⭐ Decoupled, testable UIs:
class CounterView extends StatelessWidget with View {
  final String count;
  final VoidCallback onIncrement;

  const CounterView({
    Key? key,
    required this.count,
    required this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Text(count),
      onPressed: onIncrement,
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
