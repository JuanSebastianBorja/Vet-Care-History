class DewormingModel {
  final String id;
  final String petId;
  final String product;
  final String? dose;
  final String? route;
  final DateTime applicationDate;
  final DateTime? nextDueDate;
  final DateTime createdAt;

  const DewormingModel({
    required this.id,
    required this.petId,
    required this.product,
    this.dose,
    this.route,
    required this.applicationDate,
    this.nextDueDate,
    required this.createdAt,
  });

  static String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory DewormingModel.fromMap(Map<String, dynamic> map) => DewormingModel(
        id: map['id'] as String,
        petId: map['pet_id'] as String,
        product: map['product'] as String,
        dose: map['dose'] as String?,
        route: map['route'] as String?,
        applicationDate: DateTime.parse(map['application_date'] as String),
        nextDueDate: map['next_due_date'] != null
            ? DateTime.parse(map['next_due_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'pet_id': petId,
        'product': product,
        if (dose != null && dose!.isNotEmpty) 'dose': dose,
        if (route != null && route!.isNotEmpty) 'route': route,
        'application_date': _toIsoDate(applicationDate),
        if (nextDueDate != null) 'next_due_date': _toIsoDate(nextDueDate!),
      };

  Map<String, dynamic> toUpdateMap() => {
        'product': product,
        'dose': dose?.isNotEmpty == true ? dose : null,
        'route': route?.isNotEmpty == true ? route : null,
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

  String get detailStr {
    final parts = [
      if (dose != null && dose!.isNotEmpty) dose!,
      if (route != null && route!.isNotEmpty) route!,
    ];
    return parts.isEmpty ? applicationDateStr : '${parts.join(' · ')} · $applicationDateStr';
  }
}
