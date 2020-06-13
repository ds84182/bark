import 'dart:async';

import 'package:flutter/foundation.dart';

/// A [ValueListenable] that subscribes to any amount of [Stream]s, updating the
/// [value] on each event received.
///
/// The streams are automatically paused and resumed when there are no
/// listeners.
class StreamValueAdapter<T> extends ChangeNotifier
    implements ValueListenable<T> {
  T _value;

  T get value => _value;

  List<StreamSubscription<T>> _streams = const [];
  bool _paused = true;

  StreamValueAdapter(this._value);

  void _updateValue(T value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }

  /// Updates the value instantly and notifies listeners.
  void add(T value) {
    _updateValue(value);
  }

  /// Subscribes to [stream] and adds it to the list of listened streams.
  void addStream(Stream<T> stream) {
    final subscription = stream.listen(_updateValue);

    if (_paused) {
      subscription.pause();
    }

    if (_streams.isEmpty) {
      _streams = List.filled(1, subscription, growable: true);
    } else {
      _streams.add(subscription);
    }
  }

  /// Unsubscribes from all current streams.
  void clearStreams() {
    _streams.forEach((sub) => sub.cancel());
    _streams = const [];
  }

  /// Unsubscribes from all current streams and subscribes to [stream].
  void replaceStream(Stream<T> stream) {
    clearStreams();
    addStream(stream);
  }

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;

    super.addListener(listener);

    if (!hadListeners && hasListeners) {
      _resumeStreams();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    final hadListeners = hasListeners;

    super.removeListener(listener);

    if (hadListeners && !hasListeners) {
      _pauseStreams();
    }
  }

  void _pauseStreams() {
    if (_paused) return;

    _streams.forEach((sub) => sub.pause());
    _paused = true;
  }

  void _resumeStreams() {
    if (!_paused) return;

    _streams.forEach((sub) => sub.resume());
    _paused = false;
  }
}
