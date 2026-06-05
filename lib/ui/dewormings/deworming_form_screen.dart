import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/deworming_model.dart';
import '../../viewmodels/history_viewmodel.dart';

class DewormingFormScreen extends StatefulWidget {
  final String petId;
  final String petName;
  final DewormingModel? deworming;

  const DewormingFormScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.deworming,
  });

  @override
  State<DewormingFormScreen> createState() => _DewormingFormScreenState();
}

class _DewormingFormScreenState extends State<DewormingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();

  static const _routeOptions = ['Oral', 'Inyectable', 'Tópica', 'Otro'];

  String? _route;
  DateTime _applicationDate = DateTime.now();
  DateTime? _nextDueDate;
  bool _saving = false;

  bool get _isEditing => widget.deworming != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.deworming!;
      _productCtrl.text = d.product;
      _doseCtrl.text = d.dose ?? '';
      _route = d.route;
      _applicationDate = d.applicationDate;
      _nextDueDate = d.nextDueDate;
    }
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isApplication) async {
    final initial = isApplication
        ? _applicationDate
        : (_nextDueDate ?? DateTime.now());
    final first = isApplication ? DateTime(2000) : _applicationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF00838F)),
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

    final deworming = DewormingModel(
      id: widget.deworming?.id ?? '',
      petId: widget.petId,
      product: _productCtrl.text.trim(),
      dose: _doseCtrl.text.trim().isEmpty ? null : _doseCtrl.text.trim(),
      route: _route,
      applicationDate: _applicationDate,
      nextDueDate: _nextDueDate,
      createdAt: widget.deworming?.createdAt ?? DateTime.now(),
    );

    final vm = context.read<HistoryViewModel>();
    final bool ok;

    if (_isEditing) {
      ok = await vm.updateDeworming(deworming, widget.petName);
    } else {
      ok = await vm.addDeworming(deworming, widget.petName);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar desparasitación' : 'Nueva desparasitación',
        ),
        backgroundColor: const Color(0xFF00838F),
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
                controller: _productCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Producto *',
                  prefixIcon: Icon(Icons.bug_report_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El producto es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosis (opcional)',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _route,
                decoration: const InputDecoration(
                  labelText: 'Vía de administración (opcional)',
                  prefixIcon: Icon(Icons.route_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sin especificar'),
                  ),
                  ..._routeOptions.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  ),
                ],
                onChanged: (v) => setState(() => _route = v),
              ),
              const SizedBox(height: 16),
              _dateField(
                label: 'Fecha de aplicación *',
                date: _applicationDate,
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 16),
              _dateField(
                label: 'Próxima aplicación (opcional)',
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
                    backgroundColor: const Color(0xFF00838F),
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
                          _isEditing
                              ? 'Guardar cambios'
                              : 'Registrar desparasitación',
                        ),
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
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}
