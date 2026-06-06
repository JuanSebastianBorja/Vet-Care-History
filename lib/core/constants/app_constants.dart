class AppConstants {
  // Credenciales Supabase — proyecto Vet Care 1 (kzrnuulihgmpayoiiyiu)
  static const String supabaseUrl =
      'https://kzrnuulihgmpayoiiyiu.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_IxMaVZn9dBEsYM0dU9GHow_ySX4gpgW';

  // OAuth de Google
  // El Web Client ID tambien se usa como serverClientId en Android para obtener idToken.
  static const String googleWebClientId =
      '505055190057-1f6dtnnakg6ke8kkh4enhm448g75dqf0.apps.googleusercontent.com';
  static const String googleAndroidClientId =
      '505055190057-3ac4u41t788li7m77vs4h8bapdt160kr.apps.googleusercontent.com';
  static const String googleIosClientId = '';

  // Redirect deep link usado por proveedores OAuth como GitHub.
  static const String oauthRedirectUri = 'vetcare://login-callback';

  // OAuth de Google
  // El Web Client ID tambien se usa como serverClientId en Android para obtener idToken.
  static const String googleWebClientId =
      '505055190057-1f6dtnnakg6ke8kkh4enhm448g75dqf0.apps.googleusercontent.com';
  static const String googleAndroidClientId =
      '505055190057-3ac4u41t788li7m77vs4h8bapdt160kr.apps.googleusercontent.com';
  static const String googleIosClientId = '';

  // Redirect deep link usado por proveedores OAuth como GitHub.
  static const String oauthRedirectUri = 'vetcare://login-callback';

  // Buckets de Storage
  static const String avatarBucket = 'avatars';
  static const String petPhotoBucket = 'pet-photos';
  static const String examPhotoBucket = 'exam-photos';

  // Configuraciones
  static const int minPasswordLength = 6;
  static const int maxPhotosPerConsultation = 5;

  /// Tiempo máximo de espera para peticiones de autenticación (evita botón colgado).
  static const Duration authRequestTimeout = Duration(seconds: 30);

  /// Resumen seguro de la config Supabase para logs de depuración.
  static String get supabaseConfigDebug {
    final keyPreview = supabaseAnonKey.length > 12
        ? '${supabaseAnonKey.substring(0, 12)}…'
        : '(vacía)';
    return 'URL=$supabaseUrl | Key=$keyPreview';
  }
}
