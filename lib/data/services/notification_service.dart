import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // IDs únicos para los canales
  static const String _vaccineChannelId = 'vetcare_vaccines';
  static const String _dewormingChannelId = 'vetcare_dewormings';

  // WorkManager task name
  static const String _backgroundTask = 'rescheduleNotifications';

  /// Inicializa el servicio de notificaciones
  Future<void> init() async {
    if (_isInitialized) return;

    // Inicializar timezones
    tz.initializeTimeZones();

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canales de notificación (Android)
    await _createChannels();

    // Solicitar permisos explícitos (Android 13+)
    await _requestPermissions();

    // Inicializar WorkManager para resincronizar notificaciones al reiniciar
    await Workmanager().initialize(_backgroundTaskRunner, isInDebugMode: false);

    // Registrar tarea periódica para verificar recordatorios (ej. cada 12 horas)
    await Workmanager().registerPeriodicTask(
      'notification-sync',
      _backgroundTask,
      frequency: const Duration(hours: 12),
    );

    _isInitialized = true;
  }

  /// Crea los canales de notificación para Android
  Future<void> _createChannels() async {
    const vaccineChannel = AndroidNotificationChannel(
      _vaccineChannelId,
      'Vacunas y Recordatorios',
      description: 'Notificaciones sobre vacunas pendientes',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const dewormingChannel = AndroidNotificationChannel(
      _dewormingChannelId,
      'Desparasitación',
      description: 'Notificaciones sobre desparasitación pendiente',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(vaccineChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dewormingChannel);
  }

  /// Solicita permisos necesarios
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ requiere permiso explícito de notificaciones
      await Permission.notification.request();

      // Para alarmas exactas (Android 12+)
      // Nota: SCHEDULE_EXACT_ALARM es un permiso especial que a veces requiere aprobación manual en Play Store
      // pero USE_EXACT_ALARM suele ser suficiente para apps de calendario/salud
    } else if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Maneja el toque en la notificación (opcional: navegar a una pantalla específica)
  void _onNotificationTapped(NotificationResponse response) {
    // Aquí podrías integrar con un sistema de navegación global si lo necesitas
    // Ejemplo: Navigator.pushNamed(..., arguments: response.payload);
    print('Notificación tocada: ${response.payload}');
  }

  /// Programa una notificación para una vacuna o desparasitación
  /// [id]: Identificador único de la notificación (puede ser el ID del registro + tipo)
  /// [title]: Título de la notificación (ej: "Vacuna pendiente")
  /// [body]: Cuerpo del mensaje (ej: "Firulais necesita su vacuna Rabia mañana")
  /// [scheduledDate]: Fecha y hora exacta para la notificación
  /// [channelId]: ID del canal ('vetcare_vaccines' o 'vetcare_dewormings')
  /// [payload]: Datos extra (ej: JSON con petId, recordId)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    // Cancelar cualquier notificación previa con el mismo ID para evitar duplicados
    await _notifications.cancel(id);

    // Asegurarse de que la fecha no sea en el pasado
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      // Si la fecha ya pasó, no programar (o programar para inmediatamente si se desea)
      print(
        'La fecha de la notificación ($scheduledDate) ya pasó. No se programa.',
      );
      return;
    }

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'vetcare_channel_general', // Fallback channel si el específico falla
      'General',
      channelDescription: 'Notificaciones generales',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('Notificación programada ID: $id para $tzDate');
  }

  /// Cancela una notificación específica por su ID
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    print('Notificación $id cancelada');
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('Todas las notificaciones canceladas');
  }

  /// Función auxiliar para generar un ID único basado en el tipo y el ID del registro
  static int generateNotificationId(String type, String recordId) {
    // Convertir el UUID a un int simple o usar un hash
    int hash = recordId.hashCode.abs() % 10000;

    if (type == 'vaccine') {
      return 10000 + hash;
    } else if (type == 'deworming') {
      return 20000 + hash;
    } else if (type == 'appointment') {
      return 30000 + hash;
    }

    return hash;
  }
}

/// Runner para WorkManager
@pragma('vm:entry-point')
void _backgroundTaskRunner(String task) {
  if (task == NotificationService._backgroundTask) {
    print('Ejecutando tarea de fondo: $task');
  }
}
