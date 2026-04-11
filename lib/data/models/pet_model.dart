class PetModel {
  final String id;
  final String userId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? sex;
  final String? photoUrl;
  final bool notificationsEnabled;
  final DateTime createdAt;

  const PetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sex,
    this.photoUrl,
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  static String _toIsoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory PetModel.fromMap(Map<String, dynamic> map) => PetModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        species: map['species'] as String,
        breed: map['breed'] as String?,
        birthDate: map['birth_date'] != null
            ? DateTime.parse(map['birth_date'] as String)
            : null,
        sex: map['sex'] as String?,
        photoUrl: map['photo_url'] as String?,
        notificationsEnabled: (map['notifications_enabled'] as bool?) ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'name': name,
        'species': species,
        if (breed != null && breed!.isNotEmpty) 'breed': breed,
        if (birthDate != null) 'birth_date': _toIsoDate(birthDate!),
        if (sex != null) 'sex': sex,
        if (photoUrl != null) 'photo_url': photoUrl,
        'notifications_enabled': notificationsEnabled,
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'species': species,
        'breed': (breed != null && breed!.isNotEmpty) ? breed : null,
        'birth_date': birthDate != null ? _toIsoDate(birthDate!) : null,
        'sex': sex,
        'photo_url': photoUrl,
        'notifications_enabled': notificationsEnabled,
      };

  PetModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? sex,
    String? photoUrl,
    bool clearPhotoUrl = false,
    bool? notificationsEnabled,
    DateTime? createdAt,
  }) =>
      PetModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        sex: sex ?? this.sex,
        photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        createdAt: createdAt ?? this.createdAt,
      );

  String get ageString {
    if (birthDate == null) return 'Sin edad';
    final now = DateTime.now();
    final years = now.year -
        birthDate!.year -
        (now.month < birthDate!.month ||
                (now.month == birthDate!.month && now.day < birthDate!.day)
            ? 1
            : 0);
    if (years >= 1) return years == 1 ? '1 año' : '$years años';
    final months = (now.difference(birthDate!).inDays / 30).floor();
    if (months >= 1) return months == 1 ? '1 mes' : '$months meses';
    return '${now.difference(birthDate!).inDays} días';
  }

  String get sexLabel {
    switch (sex) {
      case 'male':
        return 'Macho';
      case 'female':
        return 'Hembra';
      default:
        return 'Sin datos';
    }
  }
}
