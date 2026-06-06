import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

/// Serializa escrituras SQLite y reintenta cuando el archivo está bloqueado.
class DatabaseWriteQueue {
  DatabaseWriteQueue._();

  static final DatabaseWriteQueue instance = DatabaseWriteQueue._();

  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _tail = _tail.then((_) async {
      try {
        completer.complete(await runWithRetry(action));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  static Future<T> runWithRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 6,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (!_isDatabaseLocked(e) || attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 50 * (attempt + 1)),
        );
      }
    }

    throw StateError('runWithRetry exhausted attempts');
  }

  static bool _isDatabaseLocked(Object error) {
    if (error is SqliteException) {
      return error.resultCode == 5;
    }

    final message = error.toString().toLowerCase();
    return message.contains('database is locked') ||
        message.contains('code 5');
  }
}
