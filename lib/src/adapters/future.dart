import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bark/src/adt.dart';

/// A [ValueListenable] that completes with a [Future]'s value.
class FutureValueAdapter<T> extends ChangeNotifier
    implements ValueListenable<T> {
  T _value;

  T get value => _value;

  _FutureSubscription? _sub;

  FutureValueAdapter(this._value);

  void _updateValue(T value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }

  /// Waits for [futureOr]'s completion and updates the [value].
  ///
  /// If [futureOr] is a [Future] then the [value] will update on completion.
  ///
  /// Otherwise, if [futureOr] is a [T] then the [value] will update
  /// immediately.
  ///
  /// If a previous future is currently being waited on, its value will be
  /// ignored.
  void complete(FutureOr<T> futureOr) {
    _sub?._dispose();
    _sub = null;

    if (futureOr is Future<T>) {
      _sub = _FutureSubscription(futureOr).._adapter = this;
    } else {
      _updateValue(futureOr);
    }
  }
}

extension AsyncStateFutureValueAdapter<T, E>
    on FutureValueAdapter<AsyncState<T, E>> {
  /// Waits for [futureOr]'s completion and updates the [value], wrapping the
  /// results in [AsyncState].
  ///
  /// If [gapless] is false, the [value] will be updated to [Loading] until the
  /// asynchronous operation completes.
  void completeAsync(
    FutureOr<T> futureOr,
    E Function(Object) transformError, {
    bool gapless = false,
  }) {
    if (futureOr is Future<T>) {
      if (!gapless) complete(Loading);
      complete(futureOr.then((value) => Loaded(value),
          onError: (e) => Failed(transformError(e))));
    } else {
      complete(Loaded(futureOr as T));
    }
  }
}

class _FutureSubscription<T> {
  FutureValueAdapter<T>? _adapter;
  final Future<T> _future;

  _FutureSubscription(this._future) {
    _future.then((value) => _adapter?._updateValue(value));
  }

  void _dispose() {
    _adapter = null;
  }
}
