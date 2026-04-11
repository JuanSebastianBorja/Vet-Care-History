class VaccineModel {
  final String id;
  final String petId;
  final String vaccineName;
  final DateTime applicationDate;
  final DateTime? nextDueDate;
  final DateTime createdAt;

  const VaccineModel({
    required this.id,
    required this.petId,
    required this.vaccineName,
    required this.applicationDate,
    this.nextDueDate,
    required this.createdAt,
  });

  static String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory VaccineModel.fromMap(Map<String, dynamic> map) => VaccineModel(
        id: map['id'] as String,
        petId: map['pet_id'] as String,
        vaccineName: map['vaccine_name'] as String,
        applicationDate: DateTime.parse(map['application_date'] as String),
        nextDueDate: map['next_due_date'] != null
            ? DateTime.parse(map['next_due_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'pet_id': petId,
        'vaccine_name': vaccineName,
        'application_date': _toIsoDate(applicationDate),
        if (nextDueDate != null) 'next_due_date': _toIsoDate(nextDueDate!),
      };

  Map<String, dynamic> toUpdateMap() => {
        'vaccine_name': vaccineName,
        'application_date': _toIsoDate(applicationDate),
        'next_due_date': nextDueDate != null ? _toIsoDate(nextDueDate!) : null,
      };

  bool get isOverdue =>
      nextDueDate != null && nextDueDate!.isBefore(DateTime.now());

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get applicationDateStr => _fmtDate(applicationDate);

  String get nextDueDateStr =>
      nextDueDate != null ? _fmtDate(nextDueDate!) : 'Sin próxima dosis';
}
