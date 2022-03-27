import 'package:flutter/services.dart';

class UnknownError implements Exception {
  String? message;
  UnknownError(this.message);

  factory UnknownError.fromException(PlatformException e) {
    if (e.message != null) {
      if (e.message!.contains('TypeError')) {
        return TypeError();
      } else if (e.message!.contains('NotFoundError')) {
        return NotFoundError();
      } else if (e.message!.contains('SecurityError')) {
        return SecurityError();
      } else if (e.message!.contains('NetworkError')) {
        return NetworkError(message: e.message);
      } else if (e.message!.contains('NotSupportedError')) {
        return NotSupportedError(message: e.message);
      } else if (e.message!.contains('InvalidStateError')) {
        return InvalidStateError(message: e.message);
      }
    }
    return UnknownError(e.message);
  }

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

class NotSupportedError extends UnknownError {
  NotSupportedError({String? message = 'The operation is not supported.'})
      : super(message);
}

class InvalidStateError extends UnknownError {
  InvalidStateError({String? message = 'The operation is not supported.'})
      : super(message);
}
