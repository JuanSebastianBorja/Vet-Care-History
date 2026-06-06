import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/deworming_model.dart';
import '../../data/models/pet_model.dart';
import '../../data/models/vaccine_model.dart';
import '../../data/models/appointment_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../../data/services/report_service.dart';
import '../consultations/consultation_form_screen.dart';
import '../dewormings/deworming_form_screen.dart';
import '../vaccines/vaccine_form_screen.dart';
import '../appointments/appointment_form_screen.dart';
import 'pet_form_screen.dart';
import 'pet_photo_image.dart';

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
        builder: (_) => PetFormScreen(userId: uid, pet: _pet),
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar mascota'),
        content: Text(
          '¿Eliminar a ${_pet.name}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<PetViewModel>().deletePet(_pet.id);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar $label'),
        content: Text(
          '¿Eliminar este registro? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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
                        color: Color(0xFF1B4D3E),
                      ),
                    )
                  else ...[
                    _buildConsultationSection(histVm),
                    const SizedBox(height: 12),
                    _buildVaccineSection(histVm),
                    const SizedBox(height: 12),
                    _buildDewormingSection(histVm),
                    const SizedBox(height: 12),
                    _buildPhotosSection(histVm),
                    const SizedBox(height: 12),
                    _buildAppointmentSection(histVm),
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
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFF1B4D3E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          tooltip: 'Generar Reporte Clínico',
          onPressed: _showReportDateRangePicker,
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
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pet.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _badge(_speciesEmojiLabel(_pet.species), const Color(0xFFE27B58)),
                      if (_pet.breed != null) ...[
                        const SizedBox(width: 8),
                        _badge(_pet.breed!, Colors.white24),
                      ],
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.15, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _speciesEmojiLabel(String s) {
    switch (s.toLowerCase()) {
      case 'perro':
        return '🐶 Perro';
      case 'gato':
        return '🐱 Gato';
      case 'ave':
        return '🦜 Ave';
      case 'conejo':
        return '🐰 Conejo';
      case 'reptil':
        return '🦎 Reptil';
      default:
        return '🧩 Otro';
    }
  }

  Widget _buildHeroPhoto() {
    if (_pet.displayPhotoSource != null) {
      return PetPhotoImage(
        pet: _pet,
        fit: BoxFit.cover,
        placeholder: _photoPlaceholder,
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B4D3E), Color(0xFF3F826D)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.pets, size: 80, color: Colors.white24),
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildStatRow() => Row(
    children: [
      Expanded(
        child: _statCard(
          Icons.cake_outlined,
          'Edad',
          _pet.ageString,
          const Color(0xFF1565C0),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _statCard(
          Icons.wc_outlined,
          'Sexo',
          _pet.sexLabel,
          const Color(0xFF6A1B9A),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: _toggleNotifications,
          child: _statCard(
            _pet.notificationsEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            'Avisos',
            _pet.notificationsEnabled ? 'Activo' : 'Apagado',
            const Color(0xFF1B4D3E),
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
      ),
    ],
  );

  Widget _statCard(IconData icon, String label, String value, Color color) =>
      Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1B4D3E),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );

  Widget _buildSyncBanner(int pendingCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_outlined,
            size: 18,
            color: Color(0xFF8D6E63),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$pendingCount cambio(s) pendiente(s) de sincronizar',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5D4037),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationSection(HistoryViewModel vm) {
    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.medical_services_outlined,
            color: Color(0xFF1565C0),
            size: 20,
          ),
        ),
        title: Text(
          'Consultas (${vm.consultations.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          _addButton('Agregar consulta', const Color(0xFF1565C0), () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsultationFormScreen(petId: _pet.id),
              ),
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
    );
  }

  Widget _consultationTile(ConsultationModel c, HistoryViewModel vm) {
    final hasPendingPhotos = vm.hasPendingConsultationPhotos(c.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: const Color(0xFFF5F8FF),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          c.dayStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        Text(
                          c.monthStr,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.motive,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (c.diagnosis != null && c.diagnosis!.isNotEmpty)
                          Text(
                            c.diagnosis!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (c.photos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo,
                            size: 12,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${c.photos.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (c.photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: c.photos.length,
                    separatorBuilder: (ctx, i) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final p = c.photos[i];
                      return GestureDetector(
                        onTap: () => _openFullScreenPhoto(p.photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            p.photoUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (hasPendingPhotos) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 12,
                        color: Color(0xFF8D6E63),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Fotos pendientes de sincronizar',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasPendingPhotos) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 12,
                        color: Color(0xFF8D6E63),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Fotos pendientes de sincronizar',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                            petId: _pet.id,
                            consultation: c,
                          ),
                        ),
                      );
                      _reload();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(
                      'consulta',
                      () => vm.deleteConsultation(c.id),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
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
    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.vaccines_outlined,
            color: Color(0xFF6A1B9A),
            size: 20,
          ),
        ),
        title: Text(
          'Vacunas (${vm.vaccines.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          _addButton('Agregar vacuna', const Color(0xFF6A1B9A), () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VaccineFormScreen(petId: _pet.id, petName: _pet.name),
              ),
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
    );
  }

  Widget _vaccineTile(VaccineModel v, HistoryViewModel vm) {
    final overdue = v.isOverdue;
    final dueColor = overdue ? Colors.red.shade600 : const Color(0xFF1B4D3E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: const Color(0xFFF9F5FF),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.vaccines_outlined, color: dueColor, size: 20),
          ),
          title: Text(
            v.vaccineName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aplicada: ${v.applicationDateStr}',
                style: const TextStyle(fontSize: 12),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Próxima: ${v.nextDueDateStr}',
                    style: TextStyle(fontSize: 12, color: dueColor),
                  ),
                  if (overdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VENCIDA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF6A1B9A),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VaccineFormScreen(
                        petId: _pet.id,
                        vaccine: v,
                        petName: _pet.name,
                      ),
                    ),
                  );
                  _reload();
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade400,
                ),
                onPressed: () =>
                    _confirmDelete('vacuna', () => vm.deleteVaccine(v.id)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDewormingSection(HistoryViewModel vm) {
    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00838F).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.bug_report_outlined,
            color: Color(0xFF00838F),
            size: 20,
          ),
        ),
        title: Text(
          'Desparasitaciones (${vm.dewormings.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          _addButton(
            'Agregar desparasitación',
            const Color(0xFF00838F),
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DewormingFormScreen(petId: _pet.id, petName: _pet.name),
                ),
              );
              _reload();
            },
          ),
          if (vm.dewormings.isEmpty)
            _emptyState(Icons.bug_report_outlined)
          else
            ...vm.dewormings.map((d) => _dewormingTile(d, vm)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _dewormingTile(DewormingModel d, HistoryViewModel vm) {
    final overdue = d.isOverdue;
    final dueColor = overdue ? Colors.red.shade600 : const Color(0xFF00838F);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: const Color(0xFFF5FAFA),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bug_report_outlined, color: dueColor, size: 20),
          ),
          title: Text(
            d.product,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.detailStr, style: const TextStyle(fontSize: 12)),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Próxima: ${d.nextDueDateStr}',
                    style: TextStyle(fontSize: 12, color: dueColor),
                  ),
                  if (overdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VENCIDA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF00838F),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DewormingFormScreen(
                        petId: _pet.id,
                        deworming: d,
                        petName: _pet.name,
                      ),
                    ),
                  );
                  _reload();
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade400,
                ),
                onPressed: () => _confirmDelete(
                  'desparasitación',
                  () => vm.deleteDeworming(d.id),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(String label, Color color, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );

  Widget _emptyState(IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      children: [
        Icon(icon, size: 36, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Sin registros', style: TextStyle(color: Colors.grey.shade500)),
      ],
    ),
  );

  Future<void> _toggleNotifications() async {
    final newValue = !_pet.notificationsEnabled;
    final vm = context.read<PetViewModel>();

    // Optimistic update (actualizar UI inmediatamente)
    setState(() {
      _pet = _pet.copyWith(notificationsEnabled: newValue);
    });

    final success = await vm.togglePetNotifications(_pet.id, newValue);

    if (success) {
      if (mounted) {
        await context.read<HistoryViewModel>().updateNotificationsState(newValue, _pet.name);
      }
    } else if (mounted) {
      // Revertir si falló
      setState(() {
        _pet = _pet.copyWith(notificationsEnabled: !newValue);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Error al actualizar notificaciones'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Widget _buildAppointmentSection(HistoryViewModel vm) {
    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D3E).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_today_outlined,
            color: Color(0xFF1B4D3E),
            size: 20,
          ),
        ),
        title: Text(
          'Citas Veterinarias (${vm.appointments.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          _addButton('Agendar cita', const Color(0xFF1B4D3E), () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppointmentFormScreen(
                  petId: _pet.id,
                  petName: _pet.name,
                ),
              ),
            );
            _reload();
          }),
          if (vm.appointments.isEmpty)
            _emptyState(Icons.calendar_today_outlined)
          else
            ...vm.appointments.map((a) => _appointmentTile(a, vm)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _appointmentTile(AppointmentModel a, HistoryViewModel vm) {
    final statusColor = a.status == 'completed'
        ? Colors.blue.shade600
        : a.status == 'cancelled'
            ? Colors.red.shade600
            : Colors.orange.shade700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: const Color(0xFFF5FAF5),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_outlined, color: statusColor, size: 20),
          ),
          title: Text(
            a.motive,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${a.dateStr} a las ${a.timeStr}'),
              if (a.veterinarianName != null)
                Text('Vet: ${a.veterinarianName}'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  a.statusLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1B4D3E)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentFormScreen(
                        petId: _pet.id,
                        petName: _pet.name,
                        appointment: a,
                      ),
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
        ),
      ),
    );
  }

  Future<void> _showReportDateRangePicker() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1B4D3E)),
        ),
        child: child!,
      ),
    );

    if (pickedRange == null) return;

    _generateReport(pickedRange.start, pickedRange.end);
  }

  Future<void> _generateReport(DateTime start, DateTime end) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF1B4D3E)),
            SizedBox(width: 20),
            Text('Generando reporte PDF...'),
          ],
        ),
      ),
    );

    try {
      final histVm = context.read<HistoryViewModel>();
      final pdfBytes = await ReportService().generateClinicalReport(
        pet: _pet,
        consultations: histVm.consultations,
        vaccines: histVm.vaccines,
        dewormings: histVm.dewormings,
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de progreso

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: Text('Reporte - ${_pet.name}'),
              backgroundColor: const Color(0xFF1B4D3E),
            ),
            body: PdfPreview(
              build: (format) => pdfBytes,
              onPrinted: (context) => print('Impreso con éxito'),
              onShared: (context) => print('Compartido con éxito'),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _openFullScreenPhoto(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const CircularProgressIndicator(color: Colors.white),
                errorBuilder: (_, __, ___) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white54, size: 48),
                    SizedBox(height: 8),
                    Text('No se pudo cargar la imagen', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSection(HistoryViewModel vm) {
    final allPhotos = vm.consultations.expand((c) => c.photos).toList();

    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFAD1457).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.photo_library_outlined,
            color: Color(0xFFAD1457),
            size: 20,
          ),
        ),
        title: Text(
          'Fotos de Exámenes (${allPhotos.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          if (allPhotos.isEmpty)
            _emptyState(Icons.photo_library_outlined)
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: allPhotos.length,
                itemBuilder: (context, index) {
                  final photo = allPhotos[index];
                  return GestureDetector(
                    onTap: () => _openFullScreenPhoto(photo.photoUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photo.photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
