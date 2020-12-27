library bark.testing;

import 'package:bark/src/bloc.dart';

class TestComponent<T> implements ComponentGlue {
  final Bloc<T> bloc;
  final List<BlocMessage> messages = [];

  T Function<T>(BlocMessage<T>)? mockMessageHandler;

  TestComponent(this.bloc) {
    bloc.attachComponent(this);
  }

  T get latestValue => bloc.value;

  @override
  T handleMessage<T>(BlocMessage<T> message) {
    messages.add(message);

    if (mockMessageHandler != null) {
      return mockMessageHandler!(message);
    }

    return message.onDeliveryFailure();
  }
}
