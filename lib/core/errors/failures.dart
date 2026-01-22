import 'package:equatable/equatable.dart';

/// Base Failure class
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server Failure
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network Failure (No internet connection)
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

/// Authentication Failure
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Cache Failure
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// Validation Failure
class ValidationFailure extends Failure {
  final Map<String, String>? errors;

  const ValidationFailure({required super.message, this.errors, super.code});

  @override
  List<Object?> get props => [message, code, errors];
}

/// Unknown Failure
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code,
  });
}
