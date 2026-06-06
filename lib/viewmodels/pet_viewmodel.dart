import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../data/models/pet_model.dart';
import '../data/repositories/pet_repository.dart';

class PetViewModel extends ChangeNotifier {
  final PetRepository _repository = PetRepository();
  StreamSubscription<int>? _pendingSyncSub;

  List<PetModel> _pets = [];
  List<PetModel> _filtered = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _speciesFilter = 'Todos';
  int _pendingSyncCount = 0;

  List<PetModel> get pets => _filtered;
  bool get hasPets => _pets.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get speciesFilter => _speciesFilter;
  int get pendingSyncCount => _pendingSyncCount;

  PetViewModel() {
    _pendingSyncSub = _repository.watchPendingSyncCount().listen((count) {
      _pendingSyncCount = count;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pendingSyncSub?.cancel();
    super.dispose();
  }

  Future<void> loadPets(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _pets = await _repository.fetchPets(userId);
      _applyFilters();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSpeciesFilter(String species) {
    _speciesFilter = species;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filtered = _pets.where((pet) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          pet.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSpecies =
          _speciesFilter == 'Todos' ||
          pet.species.toLowerCase() == _speciesFilter.toLowerCase();
      return matchesSearch && matchesSpecies;
    }).toList();
  }

  Future<bool> addPet(PetModel pet, {XFile? photo}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repository.addPet(pet, photo: photo);
      _pets.add(saved);
      _applyFilters();
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

  Future<bool> updatePet(PetModel pet, {XFile? newPhoto}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _repository.updatePet(pet, newPhoto: newPhoto);
      final idx = _pets.indexWhere((p) => p.id == pet.id);
      if (idx != -1) _pets[idx] = updated;
      _applyFilters();
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

  Future<bool> deletePet(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.deletePet(petId);
      _pets.removeWhere((p) => p.id == petId);
      _applyFilters();
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> togglePetNotifications(String petId, bool enabled) async {
    try {
      final updatedPet = await _repository.toggleNotifications(petId, enabled);

      // Actualizar la lista local
      final index = _pets.indexWhere((p) => p.id == petId);
      if (index != -1) {
        _pets[index] = updatedPet;
        _applyFilters(); // Re-aplicar filtros por si acaso
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
