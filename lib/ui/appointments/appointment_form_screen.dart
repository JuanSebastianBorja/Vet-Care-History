import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/appointment_model.dart';
import '../../viewmodels/history_viewmodel.dart';

class AppointmentFormScreen extends StatefulWidget {
  final String petId;
  final String petName;
  final AppointmentModel? appointment;

  const AppointmentFormScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.appointment,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motiveCtrl = TextEditingController();
  final _vetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _status = 'pending';
  bool _saving = false;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.appointment!;
      _motiveCtrl.text = a.motive;
      _vetCtrl.text = a.veterinarianName ?? '';
      _notesCtrl.text = a.notes ?? '';
      _selectedDate = a.appointmentDatetime;
      _selectedTime = TimeOfDay(
        hour: a.appointmentDatetime.hour,
        minute: a.appointmentDatetime.minute,
      );
      _status = a.status;
    }
  }

  @override
  void dispose() {
    _motiveCtrl.dispose();
    _vetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final appointmentDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointment = AppointmentModel(
      id: widget.appointment?.id ?? '',
      petId: widget.petId,
      appointmentDatetime: appointmentDateTime,
      veterinarianName: _vetCtrl.text.trim().isEmpty ? null : _vetCtrl.text.trim(),
      motive: _motiveCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: _status,
      createdAt: widget.appointment?.createdAt ?? DateTime.now(),
    );

    final vm = context.read<HistoryViewModel>();
    final bool ok;
    if (_isEditing) {
      ok = await vm.updateAppointment(appointment, widget.petName);
    } else {
      ok = await vm.addAppointment(appointment, widget.petName);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Error al guardar la cita'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar cita' : 'Nueva cita'),
        backgroundColor: themeColor,
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
                controller: _motiveCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la cita *',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El motivo es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vetCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Veterinario / Clínica (opcional)',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pickerField(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha',
                      value: '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerField(
                      icon: Icons.access_time_outlined,
                      label: 'Hora',
                      value: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                  DropdownMenuItem(value: 'completed', child: Text('Completada')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelada')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas / Recomendaciones (opcional)',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Guardar cambios' : 'Agendar cita',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
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
            Icon(icon, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
