import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/vaccine_model.dart';
import '../../viewmodels/history_viewmodel.dart';

class VaccineFormScreen extends StatefulWidget {
  final String petId;
  final VaccineModel? vaccine;

  const VaccineFormScreen({super.key, required this.petId, this.vaccine});

  @override
  State<VaccineFormScreen> createState() => _VaccineFormScreenState();
}

class _VaccineFormScreenState extends State<VaccineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  DateTime _applicationDate = DateTime.now();
  DateTime? _nextDueDate;
  bool _saving = false;

  bool get _isEditing => widget.vaccine != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.vaccine!;
      _nameCtrl.text = v.vaccineName;
      _applicationDate = v.applicationDate;
      _nextDueDate = v.nextDueDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isApplication) async {
    final initial = isApplication ? _applicationDate : (_nextDueDate ?? DateTime.now());
    final first = isApplication ? DateTime(2000) : _applicationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6A1B9A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isApplication) {
          _applicationDate = picked;
          if (_nextDueDate != null && _nextDueDate!.isBefore(picked)) {
            _nextDueDate = null;
          }
        } else {
          _nextDueDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vaccine = VaccineModel(
      id: widget.vaccine?.id ?? '',
      petId: widget.petId,
      vaccineName: _nameCtrl.text.trim(),
      applicationDate: _applicationDate,
      nextDueDate: _nextDueDate,
      createdAt: widget.vaccine?.createdAt ?? DateTime.now(),
    );

    final vm = context.read<HistoryViewModel>();
    final bool ok;
    if (_isEditing) {
      ok = await vm.updateVaccine(vaccine);
    } else {
      ok = await vm.addVaccine(vaccine);
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
        title: Text(_isEditing ? 'Editar vacuna' : 'Nueva vacuna'),
        backgroundColor: const Color(0xFF6A1B9A),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la vacuna *',
                  prefixIcon: Icon(Icons.vaccines_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              _dateField(
                label: 'Fecha de aplicación *',
                date: _applicationDate,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 16),
              _dateField(
                label: 'Próxima dosis (opcional)',
                date: _nextDueDate,
                onTap: () => _pickDate(false),
                clearable: true,
                onClear: () => setState(() => _nextDueDate = null),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A)),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditing ? 'Guardar cambios' : 'Registrar vacuna'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool clearable = false,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: Colors.grey.shade600),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                    : label,
                style: TextStyle(
                  fontSize: 16,
                  color: date != null ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ),
            if (date != null && clearable)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 20),
              )
            else
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
