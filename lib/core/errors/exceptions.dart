/// Base class for typed exceptions thrown by the application layer.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause, super.stackTrace});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

class WebViewException extends AppException {
  const WebViewException(super.message, {super.cause, super.stackTrace});
}
