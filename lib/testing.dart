library bark.testing;

import 'package:bark/src/bloc.dart';

class TestComponent<T> implements BlocState {
  final Bloc<T> bloc;
  final List<BlocMessage> messages = [];

  T Function<T>(BlocMessage<T>) mockMessageHandler;

  BlocContext _context;
  T _latestValue;

  TestComponent(this.bloc) {
    _context = BlocContext(this);
  }

  T get latestValue => _latestValue ??= _fetchValue();

  T _fetchValue() {
    final value = bloc.viewModel(_context);
    _context.clearUntracked();
    return value;
  }

  @override
  T handleMessage<T>(BlocMessage<T> message) {
    messages.add(message);

    if (mockMessageHandler != null) {
      return mockMessageHandler(message);
    }

    return message.onDeliveryFailure();
  }

  @override
  void onTrackerUpdated(Tracker tracker) {
    _latestValue = null;
  }
}
