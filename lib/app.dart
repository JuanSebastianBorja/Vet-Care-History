import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'data/services/app_sync_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/history_viewmodel.dart';
import 'viewmodels/pet_viewmodel.dart';
import 'ui/auth/login_screen.dart';
import 'ui/pets/pet_list_screen.dart';

/// Widget raíz de la aplicación VetCare.
///
/// Configura la inyección de dependencias global usando [MultiProvider] para proveer
/// los ViewModels principales ([AuthViewModel], [PetViewModel], [HistoryViewModel])
/// a todo el árbol de widgets. También establece el tema visual y la pantalla inicial.
class VetCareApp extends StatelessWidget {
  const VetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => PetViewModel()),
        ChangeNotifierProvider(create: (_) => HistoryViewModel()),
      ],
      child: MaterialApp(
        title: 'VetCare',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AuthWrapper(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF1B4D3E); // Elegant forest green
    const secondary = Color(0xFFE27B58); // Friendly warm coral
    const background = Color(0xFFF7FAF8); // Super soft warm off-white/cream

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: primary.withValues(alpha: 0.06),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEEF3F0)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          elevation: 2,
          shadowColor: primary.withValues(alpha: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E6E2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E6E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7A72)),
        floatingLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.bold),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: const BorderSide(color: Colors.transparent),
        backgroundColor: const Color(0xFFEEF3F0),
        selectedColor: primary,
        secondarySelectedColor: primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.fredokaTextTheme(baseTheme.textTheme),
    );
  }
}

/// Wrapper de autenticación y observador de ciclo de vida.
///
/// Determina qué pantalla mostrar (carga, lista de mascotas o login) según el estado
/// de sesión en [AuthViewModel]. Además, implementa [WidgetsBindingObserver] para
/// sincronizar cambios locales pendientes con Supabase cada vez que la app vuelve a primer plano.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registra este widget como observador de cambios en el ciclo de vida de la aplicación.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verifica de forma asíncrona si hay una sesión activa de Supabase.
      context.read<AuthViewModel>().checkSession();
    });
  }

  @override
  void dispose() {
    // Limpia el observador al destruir el widget para evitar fugas de memoria.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app vuelve a estar visible en pantalla (primer plano),
    // dispara inmediatamente un ciclo de sincronización de datos pendientes.
    if (state == AppLifecycleState.resumed) {
      AppSyncService().syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, viewModel, child) {
        // Pantalla de carga mientras se verifica la sesión.
        if (viewModel.isLoading) {
          return Scaffold(
            backgroundColor: const Color(0xFF1B4D3E),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pets, size: 80, color: Colors.white)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 0.8, end: 1.2, duration: 800.ms, curve: Curves.easeInOut)
                      .rotate(begin: -0.05, end: 0.05, duration: 800.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 40),
                  const Text(
                    'Cargando VetCare...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 800.ms)
                      .then()
                      .fadeOut(duration: 800.ms),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 48,
                    child: LinearProgressIndicator(
                      color: Color(0xFFE27B58),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Si hay una sesión de usuario válida, redirige al listado de mascotas.
        if (viewModel.isSignedIn) {
          return const PetListScreen();
        }

        // Si no está autenticado, redirige al inicio de sesión.
        return const LoginScreen();
      },
    );
  }
}
