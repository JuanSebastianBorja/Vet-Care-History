import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../../data/services/app_sync_service.dart';
import '../../data/services/notification_service.dart';

/// Coordinates deferred startup work so [runApp] is not blocked.
class AppBootstrap {
  AppBootstrap._();

  static final AppBootstrap instance = AppBootstrap._();

  final Completer<void> _ready = Completer<void>();

  Future<void> get ready => _ready.future;

  bool get isReady => _ready.isCompleted;

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

    unawaited(_initBackgroundServices());
  }

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
