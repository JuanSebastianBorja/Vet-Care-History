import 'package:drift/drift.dart';
import 'package:drift/web.dart';

LazyDatabase createConnection() {
  return LazyDatabase(() async => WebDatabase('vetcare_offline'));
}
