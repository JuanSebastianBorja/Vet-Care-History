import 'package:drift/drift.dart';

import 'db_connection_native.dart'
    if (dart.library.js_interop) 'db_connection_web.dart';

LazyDatabase? _sharedConnection;

/// Una sola conexión compartida para evitar bloqueos por múltiples aperturas.
LazyDatabase openConnection() => _sharedConnection ??= createConnection();
