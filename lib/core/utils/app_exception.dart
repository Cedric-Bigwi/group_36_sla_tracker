import 'package:sqflite/sqflite.dart';

/// Typed error carrying a message that is safe to show to the user.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AppException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Runs a repository action and converts low-level [DatabaseException]s into
/// an [AppException] with a friendly message.
Future<T> guardDb<T>(Future<T> Function() action, {String? what}) async {
  try {
    return await action();
  } on AppException {
    rethrow;
  } on DatabaseException catch (e) {
    final raw = e.toString();
    if (raw.contains('UNIQUE')) {
      throw AppException('That value is already in use.', cause: e);
    }
    if (raw.contains('FOREIGN KEY')) {
      throw AppException(
        'This item is linked to other data and cannot be changed that way.',
        cause: e,
      );
    }
    throw AppException(
      'Could not ${what ?? 'complete the request'}. Please try again.',
      cause: e,
    );
  }
}
