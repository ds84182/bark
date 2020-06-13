/// Implementations of data types needed to represent optional, fallible, and
/// asynchronous states.
library bark.src.adt;

abstract class Opt<T> {
  const Opt();

  T get orNull;

  Opt<U> map<U>(U Function(T) f) => this == None ? None : Some(f(orNull));
}

class NoneOpt extends Opt<Null> {
  const NoneOpt();

  @override
  Null get orNull => null;

  @override
  String toString() => "None";
}

const None = NoneOpt();

class Some<T> extends Opt<T> {
  final T value;

  const Some(this.value);

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
  const Result();

  T get dataOrNull;
  E get errorOrNull;
}

class Ok<T> extends Result<T, Null> {
  final T data;

  const Ok(this.data);

  T get dataOrNull => data;
  Null get errorOrNull => null;

  @override
  bool operator ==(other) => other is Ok && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Ok($data)';
}

class Err<E> extends Result<Null, E> {
  final E error;

  const Err(this.error);

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
  const AsyncState();

  Opt<Result<T, E>> get asResult;

  T get loadedOrNull;
}

abstract class NotLoaded<E> extends AsyncState<Null, E> {
  const NotLoaded();
}

class LoadingState extends NotLoaded<Null> {
  const LoadingState();

  @override
  Opt<Result<Null, Null>> get asResult => None;

  @override
  Null get loadedOrNull => null;
}

const Loading = LoadingState();

class Loaded<T> extends AsyncState<T, Null> {
  final T data;

  const Loaded(this.data);

  @override
  Opt<Result<T, Null>> get asResult => Some(Ok(data));

  @override
  T get loadedOrNull => data;
}

class Failed<E> extends NotLoaded<E> {
  final E error;

  const Failed(this.error);

  @override
  Opt<Result<Null, E>> get asResult => Some(Err(error));

  @override
  Null get loadedOrNull => null;
}
