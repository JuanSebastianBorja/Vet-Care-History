import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/deworming_model.dart';
import '../../data/models/pet_model.dart';
import '../../data/models/vaccine_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../consultations/consultation_form_screen.dart';
import '../dewormings/deworming_form_screen.dart';
import '../vaccines/vaccine_form_screen.dart';
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
          '¿Eliminar a ${_pet.name}? Se borrará todo su historial.',
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
                  const SizedBox(height: 20),
                  if (histVm.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  else ...[
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
      expandedHeight: 300,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
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
                    Colors.black.withValues(alpha: 0.65),
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
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _badge(_pet.species, const Color(0xFF2E7D32)),
                      if (_pet.breed != null) ...[
                        const SizedBox(width: 8),
                        _badge(_pet.breed!, Colors.blueGrey),
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
      return Image.network(
        _pet.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _photoPlaceholder(),
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.pets, size: 80, color: Colors.white24),
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildStatRow() => Row(
    children: [
      _statCard(
        Icons.cake_outlined,
        'Edad',
        _pet.ageString,
        const Color(0xFF1565C0),
      ),
      const SizedBox(width: 10),
      _statCard(
        Icons.wc_outlined,
        'Sexo',
        _pet.sexLabel,
        const Color(0xFF6A1B9A),
      ),
      const SizedBox(width: 10),
      _statCard(
        _pet.notificationsEnabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        'Avisos',
        _pet.notificationsEnabled ? 'Activo' : 'Apagado',
        const Color(0xFF2E7D32),
      ),
    ],
  );

  Widget _statCard(IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );

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
                    itemBuilder: (ctx, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        c.photos[i].photoUrl,
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
    final dueColor = overdue ? Colors.red.shade600 : const Color(0xFF2E7D32);

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
              Row(
                children: [
                  Text(
                    'Próxima: ${v.nextDueDateStr}',
                    style: TextStyle(fontSize: 12, color: dueColor),
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 4),
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
              Row(
                children: [
                  Text(
                    'Próxima: ${d.nextDueDateStr}',
                    style: TextStyle(fontSize: 12, color: dueColor),
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 4),
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
}
