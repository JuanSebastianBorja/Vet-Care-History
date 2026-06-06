import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

/// Cola de tareas asíncronas para serializar y reintentar escrituras en la base de datos local SQLite.
///
/// Dado que SQLite puede lanzar excepciones de base de datos bloqueada (`SQLITE_BUSY` o código 5)
/// cuando múltiples hilos o procesos intentan realizar escrituras concurrentemente (por ejemplo,
/// la interacción del usuario en primer plano vs. la sincronización asíncrona en segundo plano),
/// esta clase asegura que las operaciones de modificación se ejecuten una detrás de la otra (en cola FIFO)
/// y que reintente automáticamente de manera incremental si detecta un bloqueo temporal.
class DatabaseWriteQueue {
  // Constructor privado para implementar el patrón Singleton.
  DatabaseWriteQueue._();

  /// Instancia compartida del despachador de escrituras.
  static final DatabaseWriteQueue instance = DatabaseWriteQueue._();

  // Encadena las operaciones pendientes para garantizar un orden de ejecución estrictamente secuencial.
  Future<void> _tail = Future<void>.value();

  /// Encola una operación de escritura para ejecución secuencial.
  ///
  /// Retorna un [Future] que se completará con el resultado de la operación o con un error.
  /// La acción se procesará en orden de llegada y se ejecutará usando un mecanismo de reintento automático.
  Future<T> enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    // Encadena la ejecución al final de la cola actual de promesas.
    _tail = _tail.then((_) async {
      try {
        completer.complete(await runWithRetry(action));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  /// Ejecuta una acción y reintenta de forma automática con retraso exponencial progresivo si la base de datos está bloqueada.
  ///
  /// El parámetro [maxAttempts] define cuántas veces se intentará la operación antes de relanzar el error.
  static Future<T> runWithRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 6,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        // Si el error no es por bloqueo de base de datos o ya es el último intento, relanza la excepción inmediatamente.
        if (!_isDatabaseLocked(e) || attempt == maxAttempts - 1) rethrow;
        
        // Espera un periodo de tiempo progresivo antes del siguiente reintento (50ms, 100ms, 150ms...).
        await Future<void>.delayed(
          Duration(milliseconds: 50 * (attempt + 1)),
        );
      }
    }

    throw StateError('runWithRetry exhausted attempts');
  }

  // Comprueba si la excepción capturada se debe a que SQLite está ocupado o bloqueado.
  static bool _isDatabaseLocked(Object error) {
    // Código de resultado 5 en sqlite3 corresponde a SQLITE_BUSY.
    if (error is SqliteException) {
      return error.resultCode == 5;
    }

    final message = error.toString().toLowerCase();
    return message.contains('database is locked') ||
        message.contains('code 5');
  }
}
