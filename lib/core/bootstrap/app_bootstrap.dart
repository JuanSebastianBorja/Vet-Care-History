import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../../data/services/app_sync_service.dart';
import '../../data/services/notification_service.dart';

/// Coordina las tareas diferidas de arranque de la aplicación para evitar bloquear [runApp].
///
/// Esto permite que la interfaz de usuario de Flutter se renderice inmediatamente mientras
/// se inicializan de forma asíncrona servicios pesados como Supabase, servicios de
/// notificaciones locales y la sincronización periódica en segundo plano.
class AppBootstrap {
  // Constructor privado para implementar el patrón Singleton.
  AppBootstrap._();

  /// Instancia única y compartida de [AppBootstrap].
  static final AppBootstrap instance = AppBootstrap._();

  // Completer utilizado para señalar cuándo Supabase ha terminado su inicialización básica.
  final Completer<void> _ready = Completer<void>();

  /// Futuro que se resuelve cuando la inicialización crítica (como Supabase) está completa.
  Future<void> get ready => _ready.future;

  /// Indica si el proceso de inicialización crítica ha finalizado.
  bool get isReady => _ready.isCompleted;

  /// Inicializa Supabase de forma asíncrona.
  ///
  /// Si ocurre un error, completa con error el [_ready] completer. Una vez inicializado
  /// Supabase con éxito, desencadena el arranque diferido de los servicios de segundo plano.
  Future<void> initialize() async {
    if (_ready.isCompleted) return;

    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (e, st) {
      debugPrint('Supabase init failed: $e\n$st');
      if (!_ready.isCompleted) {
        _ready.completeError(e, st);
      }
      return;
    }

    if (!_ready.isCompleted) {
      _ready.complete();
    }

    // Inicializa servicios secundarios en segundo plano sin interrumpir el hilo principal.
    unawaited(_initBackgroundServices());
  }

  /// Inicializa los servicios secundarios en segundo plano.
  ///
  /// Configura el canal de notificaciones locales, los recordatorios automáticos
  /// en background y arranca el servicio de sincronización offline [AppSyncService].
  Future<void> _initBackgroundServices() async {
    try {
      await NotificationService().init();
      await NotificationService().initializeBackgroundTasks();
    } catch (e, st) {
      debugPrint('Notification init failed: $e\n$st');
    }

    try {
      await AppSyncService().start();
    } catch (e, st) {
      debugPrint('AppSync start failed: $e\n$st');
    }
  }
}
