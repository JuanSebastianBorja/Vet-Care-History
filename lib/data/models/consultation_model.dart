class ConsultationPhotoModel {
  final String id;
  final String consultationId;
  final String photoUrl;
  final String? description;
  final DateTime createdAt;

  const ConsultationPhotoModel({
    required this.id,
    required this.consultationId,
    required this.photoUrl,
    this.description,
    required this.createdAt,
  });

  factory ConsultationPhotoModel.fromMap(Map<String, dynamic> map) =>
      ConsultationPhotoModel(
        id: map['id'] as String,
        consultationId: map['consultation_id'] as String,
        photoUrl: map['photo_url'] as String,
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class ConsultationModel {
  final String id;
  final String petId;
  final DateTime visitDate;
  final String motive;
  final String? diagnosis;
  final String? treatment;
  final String? notes;
  final List<ConsultationPhotoModel> photos;
  final DateTime createdAt;

  const ConsultationModel({
    required this.id,
    required this.petId,
    required this.visitDate,
    required this.motive,
    this.diagnosis,
    this.treatment,
    this.notes,
    this.photos = const [],
    required this.createdAt,
  });

  static String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory ConsultationModel.fromMap(Map<String, dynamic> map) {
    final rawPhotos =
        (map['consultation_photos'] as List<dynamic>?) ?? [];
    return ConsultationModel(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      visitDate: DateTime.parse(map['visit_date'] as String),
      motive: map['motive'] as String,
      diagnosis: map['diagnosis'] as String?,
      treatment: map['treatment'] as String?,
      notes: map['notes'] as String?,
      photos: rawPhotos
          .map((p) => ConsultationPhotoModel.fromMap(p))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'pet_id': petId,
        'visit_date': _toIsoDate(visitDate),
        'motive': motive,
        if (diagnosis != null && diagnosis!.isNotEmpty) 'diagnosis': diagnosis,
        if (treatment != null && treatment!.isNotEmpty) 'treatment': treatment,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  Map<String, dynamic> toUpdateMap() => {
        'visit_date': _toIsoDate(visitDate),
        'motive': motive,
        'diagnosis': diagnosis?.isNotEmpty == true ? diagnosis : null,
        'treatment': treatment?.isNotEmpty == true ? treatment : null,
        'notes': notes?.isNotEmpty == true ? notes : null,
      };

  ConsultationModel copyWith({
    List<ConsultationPhotoModel>? photos,
    String? diagnosis,
    String? treatment,
    String? notes,
  }) =>
      ConsultationModel(
        id: id,
        petId: petId,
        visitDate: visitDate,
        motive: motive,
        diagnosis: diagnosis ?? this.diagnosis,
        treatment: treatment ?? this.treatment,
        notes: notes ?? this.notes,
        photos: photos ?? this.photos,
        createdAt: createdAt,
      );

  String get formattedDate =>
      '${visitDate.day.toString().padLeft(2, '0')}/${visitDate.month.toString().padLeft(2, '0')}/${visitDate.year}';

  String get dayStr => visitDate.day.toString().padLeft(2, '0');

  String get monthStr {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return months[visitDate.month - 1];
  }
}
