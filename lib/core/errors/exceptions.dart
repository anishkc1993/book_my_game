class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server error occurred']);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  /// Optional machine-readable code (e.g. Firebase Auth's `user-not-found`)
  /// — lets callers branch on the failure reason without parsing messages.
  final String? code;
  const AuthException([this.message = 'Authentication failed', this.code]);

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network connection failed']);

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache error occurred']);

  @override
  String toString() => message;
}
