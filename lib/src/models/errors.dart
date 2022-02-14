class UnknownError implements Exception {
  String? message;
  UnknownError(this.message);

  @override
  String toString() {
    return '${runtimeType.toString()}: message=$message';
  }
}

class TypeError extends UnknownError {
  TypeError({String? message = 'The provided options do not make sense.'})
      : super(message);
}

class NotFoundError extends UnknownError {
  NotFoundError(
      {String? message =
          'There is no Bluetooth device that matches the specified options.'})
      : super(message);
}

class SecurityError extends UnknownError {
  SecurityError(
      {String? message =
          'This operation is not permitted in this context due to security concerns.'})
      : super(message);
}

class NetworkError extends UnknownError {
  NetworkError({String? message = 'Unsupported device.'}) : super(message);
}
