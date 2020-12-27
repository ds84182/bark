/// Implementations of data types needed to represent optional, fallible, and
/// asynchronous states.
library bark.src.adt;

abstract class Opt<T> {
  const Opt._();

  T? get orNull;

  Opt<U> map<U>(U Function(T) f) =>
      identical(this, None) ? None as Opt<U> : Some<U>(f(orNull!));
}

class NoneOpt extends Opt<Never> {
  const NoneOpt._() : super._();

  @override
  Null get orNull => null;

  @override
  String toString() => "None";
}

const None = NoneOpt._();

class Some<T> extends Opt<T> {
  final T value;

  const Some(this.value) : super._();

  @override
  T get orNull => value;

  @override
  bool operator ==(other) => other is Some && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Some<$T>($value)';
}

abstract class Result<T, E> {
  const Result._();

  T? get dataOrNull;
  E? get errorOrNull;
}

class Ok<T> extends Result<T, Never> {
  final T data;

  const Ok(this.data) : super._();

  T get dataOrNull => data;
  Null get errorOrNull => null;

  @override
  bool operator ==(other) => other is Ok && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Ok($data)';
}

class Err<E> extends Result<Never, E> {
  final E error;

  const Err(this.error) : super._();

  Null get dataOrNull => null;
  E get errorOrNull => error;

  @override
  bool operator ==(other) => other is Err && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Err($error)';
}

abstract class AsyncState<T, E> {
  const AsyncState._();

  Opt<Result<T, E>> get asResult;

  T? get loadedOrNull;
}

abstract class NotLoaded<E> extends AsyncState<Never, E> {
  const NotLoaded._() : super._();
}

class LoadingState extends NotLoaded<Never> {
  const LoadingState._() : super._();

  @override
  Opt<Result<Never, Never>> get asResult => None;

  @override
  Null get loadedOrNull => null;

  @override
  String toString() => 'Loading';
}

const Loading = LoadingState._();

class Loaded<T> extends AsyncState<T, Never> {
  final T data;

  const Loaded(this.data) : super._();

  @override
  Opt<Result<T, Never>> get asResult => Some(Ok(data));

  @override
  T get loadedOrNull => data;

  @override
  String toString() => 'Loaded($data)';

  @override
  bool operator ==(other) => other is Loaded && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

class Failed<E> extends NotLoaded<E> {
  final E error;

  const Failed(this.error) : super._();

  @override
  Opt<Result<Never, E>> get asResult => Some(Err(error));

  @override
  Null get loadedOrNull => null;

  @override
  String toString() => 'Failed($error)';

  @override
  bool operator ==(other) => other is Failed && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
