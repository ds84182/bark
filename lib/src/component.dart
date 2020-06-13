library bark.src.component;

import 'package:flutter/widgets.dart';

import 'package:bark/src/bloc.dart';

/// A marker type the annotates a [Widget] as a [View].
///
/// This is used to restrict the types of widgets that can come out of a [Bloc].
mixin View on Widget {}

/// A [Component] is a [Widget] that connects a [Bloc] to the [Widget] tree.
///
/// When the [Bloc] is updated, the component will rebuild.
///
/// To create a component, extend this class or any of its subclasses.
abstract class Component<P, T> extends StatefulWidget {
  /// The input parameters to the [Bloc].
  ///
  /// This is used to detect updates to parameters, updating or recreating the
  /// [Bloc] if necessary.
  ///
  /// If your [Bloc] doesn't have any parameters, change type parameter [P] to
  /// [Null] and return null here.
  P get params;

  /// Creates a [Bloc] using the given [BuildContext] (if needed).
  ///
  /// This is called when initializing the [Component] and when the [params]
  /// change.
  Bloc<T> createBloc(BuildContext context);

  /// Builds a widget using the given [BuildContext] and view model from the
  /// [Bloc].
  ///
  /// This creates the actual UI from your business logic.
  Widget build(BuildContext context, T viewModel);

  const Component({Key key}) : super(key: key);

  @override
  _ComponentState<P, T> createState() => _ComponentState();
}

/// A [Component] for a [Bloc] that returns a [View] directly.
///
/// Subclasses are not required to implement [build], because the [Bloc] output
/// is used as the [Widget].
abstract class SimpleViewComponent<P, T extends View> extends Component<P, T> {
  @override
  Widget build(BuildContext context, T viewModel) => viewModel;

  const SimpleViewComponent({Key key}) : super(key: key);
}

class _ComponentState<P, T> extends State<Component<P, T>>
    with SafeBuildContext
    implements BlocState {
  Bloc<T> bloc;
  BlocContext blocContext;
  bool shouldUpdateViewModel = true;
  T viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (bloc == null) {
      bloc = widget.createBloc(context);
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(Component<P, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.params != oldWidget.params) {
      final oldBloc = this.bloc;

      var result = ParameterResult.unhandled;

      if (oldBloc is UpdatableParameters<P>) {
        result = (oldBloc as UpdatableParameters<P>)
            .didUpdateParameters(widget.params);
      }

      if (result == ParameterResult.unhandled) {
        _unsubscribe();
        bloc = widget.createBloc(context);
        _subscribe();
      }
    }
  }

  @override
  void onTrackerUpdated(Tracker tracker) {
    setState(() {
      shouldUpdateViewModel = true;
    });
  }

  @override
  T handleMessage<T>(BlocMessage<T> message) {
    if (mounted) {
      return message(this);
    } else {
      return message.onDeliveryFailure();
    }
  }

  void _subscribe() {
    blocContext = BlocContext(this);
    shouldUpdateViewModel = true;
  }

  void _unsubscribe() {
    blocContext?.dispose();
    blocContext = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (shouldUpdateViewModel) {
      shouldUpdateViewModel = false;
      viewModel = bloc.viewModel(blocContext);
      blocContext.clearUntracked();
    }
    return widget.build(context, viewModel);
  }
}
