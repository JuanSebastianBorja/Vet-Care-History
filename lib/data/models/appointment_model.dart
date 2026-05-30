class AppointmentModel {
  final String id;
  final String petId;
  final DateTime appointmentDate;
  final String? vetName;
  final String motive;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const AppointmentModel({
    required this.id,
    required this.petId,
    required this.appointmentDate,
    this.vetName,
    required this.motive,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) => AppointmentModel(
        id: map['id'] as String,
        petId: map['pet_id'] as String,
        appointmentDate: DateTime.parse(map['appointment_date'] as String),
        vetName: map['vet_name'] as String?,
        motive: map['motive'] as String,
        notes: map['notes'] as String?,
        status: (map['status'] as String?) ?? 'pending',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'pet_id': petId,
        'appointment_date': appointmentDate.toIso8601String(),
        if (vetName != null && vetName!.isNotEmpty) 'vet_name': vetName,
        'motive': motive,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'status': status,
      };

  Map<String, dynamic> toUpdateMap() => {
        'appointment_date': appointmentDate.toIso8601String(),
        'vet_name': (vetName != null && vetName!.isNotEmpty) ? vetName : null,
        'motive': motive,
        'notes': (notes != null && notes!.isNotEmpty) ? notes : null,
        'status': status,
      };

  AppointmentModel copyWith({
    String? id,
    String? petId,
    DateTime? appointmentDate,
    String? vetName,
    bool clearVetName = false,
    String? motive,
    String? notes,
    bool clearNotes = false,
    String? status,
    DateTime? createdAt,
  }) =>
      AppointmentModel(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        appointmentDate: appointmentDate ?? this.appointmentDate,
        vetName: clearVetName ? null : (vetName ?? this.vetName),
        motive: motive ?? this.motive,
        notes: clearNotes ? null : (notes ?? this.notes),
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );

  String get dateStr =>
      '${appointmentDate.day.toString().padLeft(2, '0')}/${appointmentDate.month.toString().padLeft(2, '0')}/${appointmentDate.year}';

  String get timeStr =>
      '${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}';

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }
}
