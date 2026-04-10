class PetModel {
  final String? id;
  final String userId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? sex; // 'male', 'female', 'unknown'
  final String? photoUrl;
  final bool notificationsEnabled;
  final DateTime createdAt;

  PetModel({
    this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sex,
    this.photoUrl,
    this.notificationsEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convertir a mapa para Supabase (inserción)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'user_id': userId,
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T')[0],
      if (sex != null) 'sex': sex,
      if (photoUrl != null) 'photo_url': photoUrl,
      'notifications_enabled': notificationsEnabled,
    };
  }

  // Convertir a mapa para Supabase (actualización)
  Map<String, dynamic> toSupabaseUpdateMap() {
    return {
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T')[0],
      if (sex != null) 'sex': sex,
      if (photoUrl != null) 'photo_url': photoUrl,
      'notifications_enabled': notificationsEnabled,
    };
  }

  // Crear desde respuesta de Supabase
  factory PetModel.fromSupabase(Map<String, dynamic> data) {
    return PetModel(
      id: data['id'],
      userId: data['user_id'],
      name: data['name'],
      species: data['species'],
      breed: data['breed'],
      birthDate: data['birth_date'] != null 
          ? DateTime.parse(data['birth_date']) 
          : null,
      sex: data['sex'],
      photoUrl: data['photo_url'],
      notificationsEnabled: data['notifications_enabled'] ?? true,
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  // Calcular edad en años
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month || 
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  // Obtener especie en español
  String get speciesEs {
    switch (species.toLowerCase()) {
      case 'dog':
      case 'perro':
        return 'Perro';
      case 'cat':
      case 'gato':
        return 'Gato';
      case 'bird':
      case 'ave':
        return 'Ave';
      case 'rabbit':
      case 'conejo':
        return 'Conejo';
      default:
        return species;
    }
  }

  // Obtener sexo en español
  String get sexEs {
    switch (sex?.toLowerCase()) {
      case 'male':
        return 'Macho';
      case 'female':
        return 'Hembra';
      case 'unknown':
        return 'Desconocido';
      default:
        return 'No especificado';
    }
  }
}
