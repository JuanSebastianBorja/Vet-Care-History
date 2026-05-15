class AppConstants {
  // Crendenciales supabase
  static const String supabaseUrl = 'https://lhhdccfgtwghacroayfn.supabase.co/';
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

  // Buckets de Storage
  static const String avatarBucket = 'avatars';
  static const String petPhotoBucket = 'pet-photos';
  static const String examPhotoBucket = 'exam-photos';

  // Configuraciones
  static const int minPasswordLength = 6;
  static const int maxPhotosPerConsultation = 5;
}
