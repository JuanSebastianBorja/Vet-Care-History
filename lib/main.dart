import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const VetCareApp());

  unawaited(AppBootstrap.instance.initialize());
}
