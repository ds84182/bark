import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A member of [SourceContext] that subscribes to data sources or manages a
/// piece of data.
abstract class Tracker {
  final Symbol name;

  const Tracker(this.name);

  void dispose();
  void postUpdate() {}

  void pause();
  void resume();
}

/// A [Tracker] that listens to a [Listenable] and updates when notified.
class ListenableTracker extends Tracker {
  final SourceState _state;
  Listenable _listenable;
  bool _paused = false;

  ListenableTracker(Symbol name, this._state) : super(name);

  Listenable get listenable => _listenable;

  set listenable(Listenable value) {
    if (identical(_listenable, value)) return;

    _listenable?.removeListener(_onNotify);
    _listenable = value;
    if (!_paused) _listenable?.addListener(_onNotify);
  }

  void _onNotify() => _state.onTrackerUpdated(this);

  @override
  void dispose() {
    listenable = null;
  }

  @override
  void pause() {
    _paused = true;
    _listenable?.removeListener(_onNotify);
  }

  @override
  void resume() {
    _paused = false;
    _listenable?.addListener(_onNotify);
  }
}

/// A tracker that manages an old and new value.
class OldValueTracker<T> extends Tracker {
  T _oldValue;
  T _newValue;
  bool _hasNewValue = true;

  OldValueTracker(Symbol name, this._oldValue)
      : _newValue = _oldValue,
        super(name);

  @override
  void dispose() {}

  @override
  void postUpdate() {
    if (_hasNewValue) {
      _oldValue = _newValue;
      _hasNewValue = false;
    }
  }

  @override
  void pause() {}

  @override
  void resume() {}
}

/// A tracker that manages a singleton that updates if any dependencies change.
class SingletonTracker<T> extends Tracker {
  T _value;
  List<Object> _keys;

  SingletonTracker(Symbol name, this._value, this._keys) : super(name);

  @override
  void dispose() {}

  @override
  void pause() {}

  @override
  void resume() {}
}

/// An object that maintains the [Source]'s state, and is notified on [Tracker]
/// changes.
abstract class SourceState {
  void onTrackerUpdated(Tracker tracker);
}

/// A context that manages [Tracker]s for a [SourceState].
abstract class SourceContext {
  const SourceContext();

  factory SourceContext.forState(SourceState state) = _SourceContext;

  void dispose();

  void pause();
  void resume();

  /// Tracks a [Listenable] named [name], updating the [Source] when it is
  /// notified.
  T trackListenable<T extends Listenable>(T listenable, Symbol name);

  /// Checks whether [value] is the first value being inserted into a
  /// [OldValueTracker].
  ///
  /// This also sets the new value.
  bool isFirstValue<T>(T value, Symbol name);

  /// Retrieves the last value from an [OldValueTracker], updating the new value
  /// to [currentValue].
  T lastValue<T>(T currentValue, Symbol name);

  /// Creates a singleton using [factory] that is recreated when any [keys]
  /// change.
  T singleton<T>(
    T Function() factory,
    Symbol name, {
    List<Object> keys: const [],
  });

  /// Removes all unused [Tracker]s.
  void clearUntracked();
}

extension SourceContextExt on SourceContext {
  /// Tracks a [ValueListenable] and returns its latest value.
  T trackValue<T>(ValueListenable<T> listenable, Symbol name) =>
      trackListenable(listenable, name).value;

  /// Tracks whether [value] has changed between invocations.
  ///
  /// This is always true on the first invocation.
  bool changed<T>(T value, Symbol name) =>
      isFirstValue(value, name) || lastValue(value, name) != value;
}

class _SourceContext<T extends SourceState> extends SourceContext
    implements SourceState {
  final T _state;

  final Map<Symbol, Tracker> _trackers = {};
  final Set<Symbol> _touchedTrackers = {};

  bool _disposed = false;
  bool _paused = false;

  _SourceContext(this._state);

  @override
  void dispose() {
    if (_disposed) return;

    _trackers.values.forEach((tracker) => tracker.dispose());
    _trackers.clear();
    _disposed = true;
  }

  @override
  void pause() {
    if (_paused) return;
    _paused = true;

    _trackers.values.forEach((tracker) => tracker.pause());
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;

    _trackers.values.forEach((tracker) => tracker.resume());
  }

  @override
  void onTrackerUpdated(Tracker tracker) {
    assert(!_disposed);
    if (_touchedTrackers.contains(tracker.name)) {
      throw StateError('Previously tracked item changed during update');
    }
    _state.onTrackerUpdated(tracker);
  }

  // TODO: Check if disposed before adding trackers

  T _tracker<T extends Tracker>(Symbol name) {
    _touchedTrackers.add(name);
    return _trackers[name] as T;
  }

  T _addTracker<T extends Tracker>(T tracker, Symbol name) {
    if (_paused) tracker.pause();
    return _trackers[name] = tracker;
  }

  @override
  T trackListenable<T extends Listenable>(T listenable, Symbol name) {
    final ListenableTracker tracker =
        _tracker(name) ?? _addTracker(ListenableTracker(name, _state), name);
    tracker.listenable = listenable;
    return listenable;
  }

  @override
  bool isFirstValue<T>(T value, Symbol name) {
    var tracker = _tracker<OldValueTracker<T>>(name);

    if (tracker == null) {
      tracker = _addTracker(OldValueTracker<T>(name, value), name);
      return true;
    }

    tracker._newValue = value;
    tracker._hasNewValue = true;

    return false;
  }

  @override
  T lastValue<T>(T currentValue, Symbol name) {
    var tracker = _tracker<OldValueTracker<T>>(name);

    if (tracker == null) {
      tracker = _addTracker(OldValueTracker<T>(name, currentValue), name);
      return null;
    }

    tracker._newValue = currentValue;
    tracker._hasNewValue = true;

    return tracker._oldValue;
  }

  @override
  T singleton<T>(
    T Function() factory,
    Symbol name, {
    List<Object> keys: const [],
  }) {
    final SingletonTracker<T> tracker = _tracker(name) ??
        _addTracker(SingletonTracker<T>(name, factory(), keys), name);

    if (!identical(tracker._keys, keys) && !listEquals(keys, tracker._keys)) {
      tracker._value = factory();
      tracker._keys = keys;
    }

    return tracker._value;
  }

  @override
  void clearUntracked() {
    _trackers.removeWhere((name, tracker) {
      if (!_touchedTrackers.contains(name)) {
        tracker.dispose();
        return true;
      }
      tracker.postUpdate();
      return false;
    });
    _touchedTrackers.clear();
  }
}

/// A [Source] is a [ValueListenable] that can produce a [value] by tracking
/// other [ValueListenable]s.
///
/// It provides an imperative-reactive framework for automatically managing
/// subscriptions to [ValueListenable]s, allowing values to be produced
/// instantly using simple syntax.
///
/// The mechanics mirror that of Flutter's build methods, where
/// [InheritedWidget]s are implicitly subscribed to, and updates to them cause
/// targeted rebuilds.
abstract class Source<T> extends ChangeNotifier
    implements ValueListenable<T>, SourceState {
  SourceContext _context;

  T _value;
  bool _shouldUpdateValue = true;

  Source(this._value) {
    _context = SourceContext.forState(this)..pause();
  }

  @override
  T get value {
    if (_shouldUpdateValue) {
      _shouldUpdateValue = false;
      return _value = produceValue(_context);
    }
    return _value;
  }

  @protected
  T produceValue(SourceContext context);

  @override
  void onTrackerUpdated(Tracker tracker) {
    _shouldUpdateValue = true;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;

    super.addListener(listener);

    if (!hadListeners && hasListeners) {
      _context.resume();
      _shouldUpdateValue = true;
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    final hadListeners = hasListeners;

    super.removeListener(listener);

    if (hadListeners && !hasListeners) {
      _context.pause();
    }
  }
}

/// A [Source] around a simple function.
class FunctionSource<T> extends Source<T> {
  final T Function(SourceContext) _produceValue;

  FunctionSource(T value, this._produceValue) : super(value);

  @override
  T produceValue(SourceContext context) => _produceValue(context);
}

/// A safe reference to a [BuildContext].
///
/// Asynchronous work using a [BuildContext] scoped to a [Component] may break
/// when the [Component] is moved or destroyed. When using [context] after an
/// asynchronous suspension (like await), check [mounted] to see if this is
/// still valid.
mixin SafeBuildContext {
  BuildContext get context;
  bool get mounted;
}

/// A [BlocMessage] is a piece of work dispatched from a [Bloc] through its
/// [BlocContext] to run a piece of [Widget]-level UI code.
///
/// This can be used to push and pop routes, show dialogs, etc.
@immutable
abstract class BlocMessage<T> {
  const BlocMessage();

  /// Executes the message using the given [context].
  ///
  /// Callers can assume that [context] points to a valid [BuildContext] until
  /// the first asynchronous suspension point.
  T call(SafeBuildContext context);

  /// Called when the message could not be executed, because it couldn't be
  /// delivered to the target.
  T onDeliveryFailure();
}

/// Mixin that provides an implementation of [onDeliveryFailure] that returns
/// null.
mixin NullOnFailure<T> on BlocMessage<T> {
  @override
  T onDeliveryFailure() => null;
}

/// Mixin that provides an implementation of [onDeliveryFailure] that
/// asynchronously returns null.
mixin AsyncNullOnFailure<T> on BlocMessage<Future<T>> {
  @override
  Future<T> onDeliveryFailure() => Future.value(null);
}

/// Mixin that provides an implementation of [onDeliveryFailure] that returns
/// false.
mixin FalseOnFailure on BlocMessage<bool> {
  @override
  bool onDeliveryFailure() => false;
}

/// A [SourceState] with Bloc-specific functionality.
abstract class BlocState extends SourceState {
  /// Called when a [message] should be handled.
  ///
  /// If the [BlocState] is invalid, it should call and return
  /// [BlocMessage.onDeliveryFailure] instead of an exception.
  T handleMessage<T>(BlocMessage<T> message);
}

abstract class BlocContext extends SourceContext {
  factory BlocContext(BlocState state) = _BlocContext;

  /// Dispatches the [message] to the [BlocState]/[Component] connected to this
  /// [BlocContext].
  T dispatch<T>(BlocMessage<T> message);
}

class _BlocContext extends _SourceContext<BlocState> implements BlocContext {
  _BlocContext(BlocState state) : super(state);

  @override
  T dispatch<T>(BlocMessage<T> message) {
    if (_disposed) {
      return message.onDeliveryFailure();
    }

    return _state.handleMessage(message);
  }
}

/// A piece of business logic that produces views/view models for display with a
/// [Component].
abstract class Bloc<T> {
  const Bloc();

  /// Tracks listenables with [context] and produces the latest value for
  /// display.
  T viewModel(BlocContext context);
}

/// The result of a parameter update.
enum ParameterResult { handled, unhandled }

/// A mixin to allow a bloc to handle parameter updates.
mixin UpdatableParameters<P> {
  set params(P params);

  /// Updates the parameters to [newParams].
  ///
  /// Blocs should override this if some parameter updates are unsupported.
  ///
  /// By default, this returns [ParameterResult.handled].
  ///
  /// If [ParameterResult.unhandled] is returned, the [Bloc] is disposed of and
  /// a new [Bloc] is created.
  ParameterResult didUpdateParameters(P newParams) {
    params = newParams;
    return ParameterResult.handled;
  }
}
