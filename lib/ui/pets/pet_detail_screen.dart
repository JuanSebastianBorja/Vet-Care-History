import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/deworming_model.dart';
import '../../data/models/pet_model.dart';
import '../../data/models/vaccine_model.dart';
import '../../data/models/appointment_model.dart';
import '../../data/services/clinical_report_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../consultations/consultation_form_screen.dart';
import '../dewormings/deworming_form_screen.dart';
import '../vaccines/vaccine_form_screen.dart';
import '../appointments/appointment_form_screen.dart';
import 'pet_form_screen.dart';

class PetDetailScreen extends StatefulWidget {
  final PetModel initialPet;

  const PetDetailScreen({super.key, required this.initialPet});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late PetModel _pet;

  @override
  void initState() {
    super.initState();
    _pet = widget.initialPet;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadForPet(_pet.id);
    });
  }

  Future<void> _reload() =>
      context.read<HistoryViewModel>().loadForPet(_pet.id);

  Future<void> _openEdit() async {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PetFormScreen(userId: uid, pet: _pet)),
    );
    if (!mounted) return;
    final updated = context
        .read<PetViewModel>()
        .pets
        .where((p) => p.id == _pet.id)
        .firstOrNull;
    if (updated != null) setState(() => _pet = updated);
  }

  void _confirmDeletePet() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar mascota'),
        content:
            Text('¿Eliminar a ${_pet.name}? Se borrara todo su historial.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok =
                  await context.read<PetViewModel>().deletePet(_pet.id);
              if (ok && mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String label, Future<bool> Function() action) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar $label'),
        content: const Text('¿Eliminar este registro? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await action();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    DateTime? startDate;
    DateTime? endDate;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2E7D32)),
              SizedBox(width: 10),
              Text('Generar Reporte'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona un rango de fechas. Si no seleccionas ninguno, se incluira todo el historial completo.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              _dateRow(
                context: context,
                label: 'Fecha Inicio:',
                date: startDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setStateDialog(() => startDate = picked);
                  }
                },
                onClear: () => setStateDialog(() => startDate = null),
              ),
              const SizedBox(height: 12),
              _dateRow(
                context: context,
                label: 'Fecha Fin:',
                date: endDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setStateDialog(() => endDate = picked);
                  }
                },
                onClear: () => setStateDialog(() => endDate = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateReport(startDate, endDate);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date != null
                          ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                          : 'Seleccionar...',
                      style: TextStyle(
                        fontSize: 13,
                        color: date != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  if (date != null)
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateReport(DateTime? start, DateTime? end) async {
    final histVm = context.read<HistoryViewModel>();

    final cFilter = histVm.consultations.where((c) {
      if (start != null && c.visitDate.isBefore(start)) return false;
      if (end != null && c.visitDate.isAfter(end)) return false;
      return true;
    }).toList();

    final vFilter = histVm.vaccines.where((v) {
      if (start != null && v.applicationDate.isBefore(start)) return false;
      if (end != null && v.applicationDate.isAfter(end)) return false;
      return true;
    }).toList();

    final dFilter = histVm.dewormings.where((d) {
      if (start != null && d.applicationDate.isBefore(start)) return false;
      if (end != null && d.applicationDate.isAfter(end)) return false;
      return true;
    }).toList();

    if (cFilter.isEmpty && vFilter.isEmpty && dFilter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No hay registros en este periodo.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF2E7D32)),
                SizedBox(height: 16),
                Text('Generando reporte clinico...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final path = await ClinicalReportService.generateAndSaveReport(
        pet: _pet,
        consultations: histVm.consultations,
        vaccines: histVm.vaccines,
        dewormings: histVm.dewormings,
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte guardado en Descargas: ${path.split(RegExp(r'[\\/]')).last}'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar el reporte: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final histVm = context.watch<HistoryViewModel>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Column(
                children: [
                  _buildStatRow(),
                  if (histVm.pendingSyncCount > 0) ...[
                    const SizedBox(height: 12),
                    _buildSyncBanner(histVm.pendingSyncCount),
                  ],
                  const SizedBox(height: 20),
                  if (histVm.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32)),
                    )
                  else ...[
                    _buildAppointmentSection(histVm),
                    const SizedBox(height: 12),
                    _buildConsultationSection(histVm),
                    const SizedBox(height: 12),
                    _buildVaccineSection(histVm),
                    const SizedBox(height: 12),
                    _buildDewormingSection(histVm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'delete_pet',
            onPressed: _confirmDeletePet,
            backgroundColor: Colors.red.shade600,
            mini: true,
            child: const Icon(Icons.delete_outline, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'edit_pet',
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0F766E),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
              tooltip: 'Generar reporte clinico',
              onPressed: _showReportDialog,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroPhoto(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pet.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _badge(_pet.species, const Color(0xFF0D9488)),
                      if (_pet.breed != null) ...[
                        const SizedBox(width: 8),
                        _badge(_pet.breed!, Colors.grey.shade700),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPhoto() {
    if (_pet.photoUrl != null) {
      return Image.network(_pet.photoUrl!, fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _photoPlaceholder());
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          ),
        ),
        child: const Center(
            child: Icon(Icons.pets_rounded, size: 72, color: Colors.white24)),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _buildStatRow() => Row(
        children: [
          _statCard(Icons.cake_outlined, 'Edad', _pet.ageString,
              const Color(0xFF0284C7)),
          const SizedBox(width: 10),
          _statCard(Icons.wc_outlined, 'Sexo', _pet.sexLabel,
              const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          _statCard(
            _pet.notificationsEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            'Avisos',
            _pet.notificationsEnabled ? 'Activo' : 'Apagado',
            const Color(0xFF0F766E),
          ),
        ],
      );

  Widget _buildSyncBanner(int pendingCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_outlined,
            size: 18,
            color: Color(0xFF00796B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$pendingCount cambio(s) pendiente(s) de sincronizar',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF004D40),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _buildAppointmentSection(HistoryViewModel vm) {
    const sectionColor = Color(0xFF0F766E);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_month_outlined,
                color: sectionColor, size: 20),
          ),
          title: Text(
              'Citas Veterinarias (${vm.appointments.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          children: [
            _addButton('Agregar cita', sectionColor, () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AppointmentFormScreen(petId: _pet.id)),
              );
              _reload();
            }),
            if (vm.appointments.isEmpty)
              _emptyState(Icons.calendar_month_outlined)
            else
              ...vm.appointments.map((a) => _appointmentTile(a, vm)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _appointmentTile(AppointmentModel a, HistoryViewModel vm) {
    final isPast = a.appointmentDate.isBefore(DateTime.now());
    final isPending = a.status == 'pending';

    Color statusColor;
    if (a.status == 'completed') {
      statusColor = const Color(0xFF0F766E);
    } else if (a.status == 'cancelled') {
      statusColor = Colors.grey.shade500;
    } else {
      statusColor = const Color(0xFF0284C7);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      a.motive,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${a.dateStr} a las ${a.timeStr}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (a.vetName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'Veterinario: ${a.vetName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
              if (a.notes != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a.notes!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isPast && isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await vm.updateAppointment(a.copyWith(status: 'completed'));
                        },
                        icon: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF0F766E)),
                        label: const Text('Completar', style: TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await vm.updateAppointment(a.copyWith(status: 'cancelled'));
                        },
                        icon: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                        label: const Text('Cancelar', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F766E)),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentFormScreen(petId: _pet.id, appointment: a),
                        ),
                      );
                      _reload();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                    onPressed: () => _confirmDelete(
                      'cita',
                      () => vm.deleteAppointment(a.id),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsultationSection(HistoryViewModel vm) {
    const sectionColor = Color(0xFF0284C7);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.medical_services_outlined,
                color: sectionColor, size: 20),
          ),
          title: Text(
              'Consultas (${vm.consultations.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          children: [
            _addButton('Agregar consulta', sectionColor, () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ConsultationFormScreen(petId: _pet.id)),
              );
              _reload();
            }),
            if (vm.consultations.isEmpty)
              _emptyState(Icons.medical_services_outlined)
            else
              ...vm.consultations.map((c) => _consultationTile(c, vm)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _consultationTile(ConsultationModel c, HistoryViewModel vm) {
    const itemColor = Color(0xFF0284C7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(c.dayStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: itemColor)),
                        Text(c.monthStr,
                            style: const TextStyle(
                                fontSize: 11, color: itemColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.motive,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14)),
                        if (c.diagnosis != null &&
                            c.diagnosis!.isNotEmpty)
                          Text(c.diagnosis!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (vm.consultationIdsWithPendingPhotos.contains(c.id)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE0B2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Subiendo fotos...',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (c.photos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              size: 14, color: itemColor),
                          SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
              if (c.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: c.photos.length,
                    separatorBuilder: (ctx, i) =>
                        const SizedBox(width: 8),
                    itemBuilder: (ctx, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        c.photos[i].photoUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              size: 20, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConsultationFormScreen(
                              petId: _pet.id, consultation: c),
                        ),
                      );
                      _reload();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                        foregroundColor: itemColor,
                        visualDensity: VisualDensity.compact),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(
                        'consulta', () => vm.deleteConsultation(c.id)),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaccineSection(HistoryViewModel vm) {
    const sectionColor = Color(0xFF7C3AED);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.vaccines_outlined,
                color: sectionColor, size: 20),
          ),
          title: Text('Vacunas (${vm.vaccines.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          children: [
            _addButton('Agregar vacuna', sectionColor, () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => VaccineFormScreen(petId: _pet.id, petName: _pet.name)),
              );
              _reload();
            }),
            if (vm.vaccines.isEmpty)
              _emptyState(Icons.vaccines_outlined)
            else
              ...vm.vaccines.map((v) => _vaccineTile(v, vm)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _vaccineTile(VaccineModel v, HistoryViewModel vm) {
    final overdue = v.isOverdue;
    final dueColor = overdue ? const Color(0xFFF43F5E) : const Color(0xFF0F766E);
    const itemColor = Color(0xFF7C3AED);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.vaccines_outlined, color: dueColor, size: 22),
          ),
          title: Text(v.vaccineName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aplicada: ${v.applicationDateStr}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Próxima: ${v.nextDueDateStr}',
                        style: TextStyle(fontSize: 12, color: dueColor, fontWeight: FontWeight.w600)),
                    if (overdue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VENCIDA',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                  size: 18, color: itemColor),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VaccineFormScreen(petId: _pet.id, petName: _pet.name, vaccine: v),
                    ),
                  );
                  _reload();
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
                onPressed: () => _confirmDelete(
                    'vacuna', () => vm.deleteVaccine(v.id)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDewormingSection(HistoryViewModel vm) {
    const sectionColor = Color(0xFF0D9488);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.bug_report_outlined,
                color: sectionColor, size: 20),
          ),
          title: Text(
              'Desparasitaciones (${vm.dewormings.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          children: [
            _addButton('Agregar desparasitación', sectionColor,
                () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DewormingFormScreen(petId: _pet.id, petName: _pet.name)),
              );
              _reload();
            }),
            if (vm.dewormings.isEmpty)
              _emptyState(Icons.bug_report_outlined)
            else
              ...vm.dewormings.map((d) => _dewormingTile(d, vm)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _dewormingTile(DewormingModel d, HistoryViewModel vm) {
    final overdue = d.isOverdue;
    final dueColor = overdue ? const Color(0xFFF43F5E) : const Color(0xFF0D9488);
    const itemColor = Color(0xFF0D9488);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.bug_report_outlined, color: dueColor, size: 22),
          ),
          title: Text(d.product,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.detailStr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Próxima: ${d.nextDueDateStr}',
                        style: TextStyle(fontSize: 12, color: dueColor, fontWeight: FontWeight.w600)),
                    if (overdue) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VENCIDA',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                  size: 18, color: itemColor),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DewormingFormScreen(
                          petId: _pet.id, petName: _pet.name, deworming: d),
                    ),
                  );
                  _reload();
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
                onPressed: () => _confirmDelete(
                    'desparasitacion', () => vm.deleteDeworming(d.id)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(String label, Color color, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.add_rounded, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      );

  Widget _emptyState(IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Sin registros',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
