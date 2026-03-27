class AppConstants {
  // Crendenciales supabase
  static const String supabaseUrl = 'https://kzrnuulihgmpayoiiyiu.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_0s7KypEkigClj1Gcr294jw_9SK1VYqQ';

  // Buckets de Storage
  static const String avatarBucket = 'avatars';
  static const String petPhotoBucket = 'pet-photos';
  static const String examPhotoBucket = 'exam-photos';

  // Configuraciones
  static const int minPasswordLength = 6;
  static const int maxPhotosPerConsultation = 5;
}
