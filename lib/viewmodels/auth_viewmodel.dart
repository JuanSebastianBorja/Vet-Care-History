import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../data/services/supabase_service.dart';
import '../data/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSignedIn => _user != null;

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    if (_supabase.isSignedIn) {
      _user = UserModel(
        id: _supabase.currentUser!.id,
        email: _supabase.currentUser!.email!,
        fullName: _supabase.currentUser!.userMetadata?['full_name'],
        avatarUrl: _supabase.currentUser!.userMetadata?['avatar_url'],
        createdAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _supabase.signUp(email, password, fullName);
      if (_user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _supabase.signIn(email, password);
      if (_user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateUserProfile(String fullName, XFile? photo) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_user == null) throw Exception('No hay usuario autenticado');
      String? avatarUrl = _user!.avatarUrl;

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final mimeType = photo.mimeType ?? 'image/jpeg';
        avatarUrl = await _supabase.uploadAvatar(_user!.id, bytes, mimeType);
      }

      _user = await _supabase.updateProfile(fullName: fullName, avatarUrl: avatarUrl);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
