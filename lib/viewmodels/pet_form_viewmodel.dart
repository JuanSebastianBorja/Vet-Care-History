import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../data/models/pet_model.dart';
import '../data/services/pet_service.dart';

enum PetFormStatus { initial, loading, success, error }

class PetFormViewModel extends ChangeNotifier {
  final PetService _petService = PetService();
  final String userId;

  PetFormViewModel({required this.userId});

  PetFormStatus _status = PetFormStatus.initial;
  String? _errorMessage;
  File? _selectedImage;
  
  // Controladores de formulario
  final nameController = TextEditingController();
  final speciesController = TextEditingController();
  final breedController = TextEditingController();
  DateTime? selectedBirthDate;
  String? selectedSex;
  bool notificationsEnabled = true;

  PetFormStatus get status => _status;
  String? get errorMessage => _errorMessage;
  File? get selectedImage => _selectedImage;
  bool get isFormValid => nameController.text.isNotEmpty && 
                          speciesController.text.isNotEmpty;

  void pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      notifyListeners();
    }
  }

  void selectBirthDate(DateTime date) {
    selectedBirthDate = date;
    notifyListeners();
  }

  Future<void> submitForm() async {
    if (!isFormValid) {
      _errorMessage = 'Nombre y especie son requeridos';
      _status = PetFormStatus.error;
      notifyListeners();
      return;
    }

    _status = PetFormStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Crear mascota
      final pet = PetModel(
        userId: userId,
        name: nameController.text.trim(),
        species: speciesController.text.trim(),
        breed: breedController.text.trim().isEmpty 
            ? null 
            : breedController.text.trim(),
        birthDate: selectedBirthDate,
        sex: selectedSex,
        notificationsEnabled: notificationsEnabled,
      );

      final createdPet = await _petService.createPet(pet);

      if (createdPet == null) {
        throw Exception('No se pudo crear la mascota');
      }

      // 2. Subir foto si existe
      if (_selectedImage != null && createdPet.id != null) {
        final imageBytes = await _selectedImage!.readAsBytes();
        await _petService.uploadPetPhoto(createdPet.id!, imageBytes);
      }

      _status = PetFormStatus.success;
      notifyListeners();
    } catch (e) {
      _status = PetFormStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void resetForm() {
    nameController.clear();
    speciesController.clear();
    breedController.clear();
    selectedBirthDate = null;
    selectedSex = null;
    _selectedImage = null;
    _status = PetFormStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    speciesController.dispose();
    breedController.dispose();
    super.dispose();
  }
}
