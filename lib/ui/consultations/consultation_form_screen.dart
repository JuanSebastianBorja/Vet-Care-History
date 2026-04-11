import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/consultation_model.dart';
import '../../viewmodels/history_viewmodel.dart';

class ConsultationFormScreen extends StatefulWidget {
  final String petId;
  final ConsultationModel? consultation;

  const ConsultationFormScreen(
      {super.key, required this.petId, this.consultation});

  @override
  State<ConsultationFormScreen> createState() =>
      _ConsultationFormScreenState();
}

class _ConsultationFormScreenState extends State<ConsultationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motiveCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _visitDate = DateTime.now();
  List<ConsultationPhotoModel> _existingPhotos = [];
  final List<String> _photoIdsToDelete = [];
  final List<XFile> _newPhotos = [];
  final List<Uint8List> _newPhotoBytes = [];
  bool _saving = false;

  bool get _isEditing => widget.consultation != null;
  int get _totalPhotos =>
      (_existingPhotos.length - _photoIdsToDelete.length) + _newPhotos.length;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.consultation!;
      _motiveCtrl.text = c.motive;
      _diagnosisCtrl.text = c.diagnosis ?? '';
      _treatmentCtrl.text = c.treatment ?? '';
      _notesCtrl.text = c.notes ?? '';
      _visitDate = c.visitDate;
      _existingPhotos = List.from(c.photos);
    }
  }

  @override
  void dispose() {
    _motiveCtrl.dispose();
    _diagnosisCtrl.dispose();
    _treatmentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickPhotos(ImageSource source) async {
    Navigator.pop(context);
    if (_totalPhotos >= 5) return;

    if (source == ImageSource.gallery) {
      final remaining = 5 - _totalPhotos;
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
      final limited = picked.take(remaining).toList();
      for (final xFile in limited) {
        final bytes = await xFile.readAsBytes();
        setState(() {
          _newPhotos.add(xFile);
          _newPhotoBytes.add(bytes);
        });
      }
    } else {
      final xFile = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 80);
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        setState(() {
          _newPhotos.add(xFile);
          _newPhotoBytes.add(bytes);
        });
      }
    }
  }

  void _showPhotoSourceSheet() {
    if (_totalPhotos >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Máximo 5 fotos por consulta'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => _pickPhotos(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () => _pickPhotos(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final consultation = ConsultationModel(
      id: widget.consultation?.id ?? '',
      petId: widget.petId,
      visitDate: _visitDate,
      motive: _motiveCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim(),
      treatment: _treatmentCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      photos: _existingPhotos,
      createdAt: widget.consultation?.createdAt ?? DateTime.now(),
    );

    final vm = context.read<HistoryViewModel>();
    final bool ok;
    if (_isEditing) {
      ok = await vm.updateConsultation(
          consultation, _newPhotos, _photoIdsToDelete);
    } else {
      ok = await vm.addConsultation(consultation, _newPhotos);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar consulta' : 'Nueva consulta'),
        backgroundColor: const Color(0xFF1565C0),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motiveCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo de consulta *',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El motivo es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnóstico (opcional)',
                  prefixIcon: Icon(Icons.search_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _treatmentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Tratamiento (opcional)',
                  prefixIcon: Icon(Icons.medication_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas adicionales (opcional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _buildPhotosSection(),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0)),
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
                          : 'Registrar consulta'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
            Icon(Icons.calendar_today_outlined,
                color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${_visitDate.day.toString().padLeft(2, '0')}/${_visitDate.month.toString().padLeft(2, '0')}/${_visitDate.year}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text('Fecha de visita *',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 20, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(
              'Fotos de exámenes ($_totalPhotos/5)',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showPhotoSourceSheet,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  size: 18),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_existingPhotos.isNotEmpty || _newPhotos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _visibleExistingCount + _newPhotos.length,
            itemBuilder: (_, i) {
              final visibleExisting =
                  _existingPhotos.where((p) => !_photoIdsToDelete.contains(p.id)).toList();
              if (i < visibleExisting.length) {
                return _existingPhotoThumb(visibleExisting[i]);
              }
              final ni = i - visibleExisting.length;
              return _newPhotoThumb(ni);
            },
          )
        else
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey.shade200, style: BorderStyle.solid),
            ),
            child: Center(
              child: Text('Sin fotos adjuntas',
                  style: TextStyle(color: Colors.grey.shade400)),
            ),
          ),
      ],
    );
  }

  int get _visibleExistingCount =>
      _existingPhotos.where((p) => !_photoIdsToDelete.contains(p.id)).length;

  Widget _existingPhotoThumb(ConsultationPhotoModel photo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(photo.photoUrl, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () =>
                setState(() => _photoIdsToDelete.add(photo.id)),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle),
              child: const Icon(Icons.close,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newPhotoThumb(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(_newPhotoBytes[index], fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() {
              _newPhotos.removeAt(index);
              _newPhotoBytes.removeAt(index);
            }),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle),
              child: const Icon(Icons.close,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
