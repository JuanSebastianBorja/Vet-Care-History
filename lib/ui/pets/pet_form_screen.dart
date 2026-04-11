import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/pet_model.dart';
import '../../viewmodels/pet_viewmodel.dart';

class PetFormScreen extends StatefulWidget {
  final String userId;
  final PetModel? pet;

  const PetFormScreen({super.key, required this.userId, this.pet});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();

  static const _speciesOptions = ['Perro', 'Gato', 'Ave', 'Conejo', 'Reptil', 'Otro'];
  static const _sexValues = ['male', 'female', 'unknown'];
  static const _sexLabels = ['Macho', 'Hembra', 'Desconocido'];

  String _species = 'Perro';
  String? _sex;
  DateTime? _birthDate;
  bool _notifications = true;
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _saving = false;

  bool get _isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.pet!;
      _nameCtrl.text = p.name;
      _breedCtrl.text = p.breed ?? '';
      _species = _speciesOptions.contains(p.species) ? p.species : 'Otro';
      _sex = p.sex;
      _birthDate = p.birthDate;
      _notifications = p.notificationsEnabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _photo = xFile;
        _photoBytes = bytes;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final pet = PetModel(
      id: widget.pet?.id ?? '',
      userId: widget.userId,
      name: _nameCtrl.text.trim(),
      species: _species,
      breed: _breedCtrl.text.trim().isEmpty ? null : _breedCtrl.text.trim(),
      birthDate: _birthDate,
      sex: _sex,
      photoUrl: widget.pet?.photoUrl,
      notificationsEnabled: _notifications,
      createdAt: widget.pet?.createdAt ?? DateTime.now(),
    );

    final vm = context.read<PetViewModel>();
    final bool ok;
    if (_isEditing) {
      ok = await vm.updatePet(pet, newPhoto: _photo);
    } else {
      ok = await vm.addPet(pet, photo: _photo);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Error al guardar'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar mascota' : 'Nueva mascota'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _species,
                decoration: const InputDecoration(
                  labelText: 'Especie *',
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
                items: _speciesOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _species = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Raza (opcional)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildSexField(),
              const SizedBox(height: 16),
              _buildNotificationsToggle(),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditing
                          ? 'Guardar cambios'
                          : 'Registrar mascota'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    DecorationImage? image;
    if (_photoBytes != null) {
      image = DecorationImage(
          image: MemoryImage(_photoBytes!), fit: BoxFit.cover);
    } else if (widget.pet?.photoUrl != null) {
      image = DecorationImage(
          image: NetworkImage(widget.pet!.photoUrl!), fit: BoxFit.cover);
    }

    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9),
                border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                image: image,
              ),
              child: image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 32, color: Color(0xFF2E7D32)),
                        SizedBox(height: 4),
                        Text('Foto',
                            style: TextStyle(
                                color: Color(0xFF2E7D32), fontSize: 12)),
                      ],
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _birthDate != null
                    ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                    : 'Fecha de nacimiento (opcional)',
                style: TextStyle(
                  color: _birthDate != null
                      ? Colors.black87
                      : Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ),
            if (_birthDate != null)
              GestureDetector(
                onTap: () => setState(() => _birthDate = null),
                child: const Icon(Icons.clear, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSexField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sexo (opcional)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: List.generate(_sexValues.length, (i) {
            final active = _sex == _sexValues[i];
            return ChoiceChip(
              label: Text(_sexLabels[i]),
              selected: active,
              onSelected: (v) =>
                  setState(() => _sex = active ? null : _sexValues[i]),
              selectedColor: const Color(0xFF2E7D32),
              labelStyle: TextStyle(
                color: active ? Colors.white : Colors.grey.shade700,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNotificationsToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Recordatorios de citas y vacunas'),
        value: _notifications,
        onChanged: (v) => setState(() => _notifications = v),
        activeThumbColor: const Color(0xFF2E7D32),
        secondary: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
