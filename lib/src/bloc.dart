import 'dart:async';

import 'package:bark/src/live_value.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
mixin NullOnFailure<T> on BlocMessage<T?> {
  @override
  T? onDeliveryFailure() => null;
}

mixin NoOpOnFailure on BlocMessage<void> {
  @override
  void onDeliveryFailure() {}
}

/// Mixin that provides an implementation of [onDeliveryFailure] that
/// asynchronously returns null.
mixin AsyncNullOnFailure<T> on BlocMessage<Future<T?>> {
  @override
  Future<T?> onDeliveryFailure() => Future<T?>.value(null);
}

/// Mixin that provides an implementation of [onDeliveryFailure] that returns
/// false.
mixin FalseOnFailure on BlocMessage<bool> {
  @override
  bool onDeliveryFailure() => false;
}

/// Glue between a [Bloc] and the associated UI [Component].
abstract class ComponentGlue {
  /// Called when a [message] should be handled.
  ///
  /// If the [BlocState] is invalid, it should call and return
  /// [BlocMessage.onDeliveryFailure] instead of an exception.
  T handleMessage<T>(BlocMessage<T> message);
}

/// A piece of business logic that produces views/view models for display with a
/// [Component].
abstract class Bloc<T> extends LiveValue<T> {
  ComponentGlue? _glue;
}

@visibleForTesting
extension ComponentAdhesive<T> on Bloc<T> {
  void attachComponent(ComponentGlue glue) {
    assert(_glue == null);
    _glue ??= glue;
  }

  void detachComponent(ComponentGlue glue) {
    if (identical(glue, _glue)) _glue = null;
  }
}

extension Dispatch<T> on Bloc<T> {
  T dispatch<T>(BlocMessage<T> message) {
    final glue = _glue;
    if (glue == null) return message.onDeliveryFailure();
    return glue.handleMessage(message);
  }
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
