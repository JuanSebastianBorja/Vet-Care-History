import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    const primary = Color(0xFF0B5945);

    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
          ).copyWith(
            primary: primary,
            onPrimary: Colors.white,
            secondary: const Color(0xFF10B981),
            surface: Colors.white,
          ),
      scaffoldBackgroundColor: const Color(0xFFF6FAF8),
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
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
          return const Scaffold(
            backgroundColor: Color(0xFF2E7D32),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 72, color: Colors.white54),
                  SizedBox(height: 32),
                  CircularProgressIndicator(color: Colors.white),
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
