import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

abstract class LiveValue<T> extends ChangeNotifier
    implements ValueListenable<T> {
  late T _cached = buildValue();
  var _dirty = false;
  LiveValueMember? _member;
  var _active = false;

  @override
  T get value {
    late var cached = _cached;
    if (_dirty) {
      _dirty = false;
      cached = buildValue();
    }
    return cached;
  }

  T buildValue();

  @override
  void addListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    super.addListener(listener);
    if (!hadListeners && hasListeners) {
      _active = true;
      _forEachMember(_activateMember);
    }
  }

  static void _activateMember(LiveValueMember m) => m.onActivate();

  @override
  void removeListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    super.removeListener(listener);
    if (hadListeners && !hasListeners) {
      _active = false;
      _forEachMember(_deactivateMember);
    }
  }

  static void _deactivateMember(LiveValueMember m) => m.onDeactivate();

  void _markDirty() {
    _dirty = true;
    notifyListeners();
  }

  void markDirtyForReassemble() => _dirty = true;

  T addMember<T extends LiveValueMember>(T member) {
    assert(member._next == null);
    member._next = _member;
    member._liveValue = this;
    member.initState();
    if (_active) member.onActivate();
    _member = member;
    return member;
  }

  void _forEachMember(void Function(LiveValueMember) fn) {
    var memberOrNull = _member;
    if (memberOrNull == null) return;
    var member = memberOrNull;
    _member = null;
    while (true) {
      final nextMember = member._next;
      fn(member);
      if (nextMember == null) break;
      member = nextMember;
    }
  }

  @override
  void dispose() {
    while (true) {
      var memberOrNull = _member;
      if (memberOrNull == null) break;
      var member = memberOrNull;
      _member = null;
      while (true) {
        final nextMember = member._next;
        if (_active) member.onDeactivate();
        member._liveValue = null;
        member.dispose();
        if (nextMember == null) break;
        member = nextMember;
      }
    }
    super.dispose();
  }
}

abstract class LiveValueMember {
  LiveValue<void>? _liveValue;
  LiveValueMember? _next;

  bool get attached => _liveValue != null;

  @protected
  @visibleForOverriding
  @mustCallSuper
  void initState() {}

  @protected
  @visibleForOverriding
  @mustCallSuper
  void onActivate() {}

  @protected
  @visibleForOverriding
  @mustCallSuper
  void onDeactivate() {}

  @protected
  void markDirty() {
    _liveValue?._markDirty();
  }

  @protected
  @visibleForOverriding
  @mustCallSuper
  void dispose() {}
}

class ValueListenableMember<T> extends LiveValueMember {
  ValueListenable<T>? _listenable;
  final T _defaultValue;

  T get value {
    if (_listenable == null) return _defaultValue;
    return _listenable!.value;
  }

  ValueListenableMember(this._listenable, this._defaultValue);

  ValueListenable<T>? get listenable => _listenable;
  set listenable(ValueListenable<T>? v) {
    if (identical(v, _listenable)) return;
    if (attached) _listenable?.removeListener(markDirty);
    _listenable = v;
    if (attached) v?.addListener(markDirty);
  }

  @override
  void onActivate() {
    super.onActivate();
    _listenable?.addListener(markDirty);
  }

  @override
  void onDeactivate() {
    _listenable?.removeListener(markDirty);
    super.onDeactivate();
  }
}

extension ValueListenableMemberExt on LiveValue {
  ValueListenableMember<T> valueListenable<T>(
      ValueListenable<T>? valueListenable, T defaultValue) =>
      addMember(ValueListenableMember(valueListenable, defaultValue));
}

class StateMember<T> extends LiveValueMember {
  T _value;

  StateMember(this._value);

  T get value => _value;
  set value(T value) {
    if (_value == value) return;
    _value = value;
    if (attached) markDirty();
  }
}

extension StateMemberExt on LiveValue {
  StateMember<T> state<T>(T initialValue) =>
      addMember(StateMember(initialValue));
}

class FutureMember<T> extends LiveValueMember {
  T _value;
  Future<T>? _future;

  FutureMember(this._value);

  void complete(FutureOr<T> future) {
    if (future is T) {
      if (_value == future) return;
      _value = future;
      markDirty();
    } else {
      _future = future;
      future.then((value) {
        if (!identical(_future, future)) return;
        if (_value == value) return;
        _value = value;
        _future = null;
        if (attached) markDirty();
      });
    }
  }

  void cancel() => _future = null;

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

extension FutureMemberExt on LiveValue {
  FutureMember<T> future<T>(T initialValue, [Future<T>? future]) {
    final m = addMember(FutureMember(initialValue));
    if (future != null) m.complete(future);
    return m;
  }
}

class StreamMember<T> extends LiveValueMember {
  static const _kSentinel = <Never>[];

  T _value;

  T get value => _value;

  List<StreamSubscription<T>> _streams = _kSentinel;
  bool _paused = true;

  StreamMember(this._value);

  void _updateValue(T value) {
    if (_value == value) return;
    _value = value;
    markDirty();
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

    if (identical(_streams, _kSentinel)) {
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
  void onActivate() {
    super.onActivate();
    _resumeStreams();
  }

  @override
  void onDeactivate() {
    _pauseStreams();
    super.onDeactivate();
  }

  @override
  void dispose() {
    clearStreams();
    super.dispose();
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

extension StreamMemberExt on LiveValue {
  StreamMember<T> stream<T>(T initialValue, [Stream<T>? stream]) {
    final m = addMember(StreamMember(initialValue));
    if (stream != null) m.addStream(stream);
    return m;
  }
}
