class AppointmentModel {
  final String id;
  final String petId;
  final DateTime appointmentDatetime;
  final String? veterinarianName;
  final String motive;
  final String? notes;
  final String status; // 'pending', 'completed', 'cancelled'
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    required this.petId,
    required this.appointmentDatetime,
    this.veterinarianName,
    required this.motive,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  static String _toIsoDateTime(DateTime d) => d.toIso8601String();

  factory AppointmentModel.fromMap(Map<String, dynamic> map) => AppointmentModel(
    id: map['id'] as String,
    petId: map['pet_id'] as String,
    appointmentDatetime: DateTime.parse(map['appointment_datetime'] as String),
    veterinarianName: map['veterinarian_name'] as String?,
    motive: map['motive'] as String,
    notes: map['notes'] as String?,
    status: map['status'] as String? ?? 'pending',
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  Map<String, dynamic> toInsertMap() => {
    if (id.isNotEmpty) 'id': id,
    'pet_id': petId,
    'appointment_datetime': _toIsoDateTime(appointmentDatetime),
    'veterinarian_name': veterinarianName,
    'motive': motive,
    'notes': notes,
    'status': status,
  };

  Map<String, dynamic> toUpdateMap() => {
    'appointment_datetime': _toIsoDateTime(appointmentDatetime),
    'veterinarian_name': veterinarianName,
    'motive': motive,
    'notes': notes,
    'status': status,
  };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String get dateStr => _fmtDate(appointmentDatetime);
  String get timeStr => _fmtTime(appointmentDatetime);

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  AppointmentModel copyWith({
    String? id,
    String? petId,
    DateTime? appointmentDatetime,
    String? veterinarianName,
    String? motive,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      appointmentDatetime: appointmentDatetime ?? this.appointmentDatetime,
      veterinarianName: veterinarianName ?? this.veterinarianName,
      motive: motive ?? this.motive,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
