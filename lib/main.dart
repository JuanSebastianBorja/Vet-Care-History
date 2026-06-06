import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';

/// Punto de entrada principal de la aplicación VetCare.
///
/// Configura la inicialización inicial requerida por Flutter, arranca la
/// interfaz gráfica principal y de forma paralela y diferida inicia los
/// servicios en segundo plano y conexión remota a través de [AppBootstrap].
void main() {
  // Asegura que los bindings del motor de Flutter estén listos antes de cualquier init.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicia la ejecución de la interfaz de usuario.
  runApp(const VetCareApp());

  // Arranca de manera asíncrona la inicialización de Supabase, base de datos local,
  // cola de sincronización y notificaciones sin bloquear el renderizado inicial de la UI.
  unawaited(AppBootstrap.instance.initialize());
}
