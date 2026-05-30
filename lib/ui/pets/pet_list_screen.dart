import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/pet_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/appointment_model.dart';
import '../../data/services/appointment_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';

class PetListScreen extends StatefulWidget {
  const PetListScreen({super.key});

  @override
  State<PetListScreen> createState() => _PetListScreenState();
}

class _PetListScreenState extends State<PetListScreen> {
  final _searchCtrl = TextEditingController();
  List<AppointmentModel> _allTomorrowAppointments = [];

  static const _species = [
    'Todos',
    'Perro',
    'Gato',
    'Ave',
    'Conejo',
    'Reptil',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() async {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid == null) return;

    final petVm = context.read<PetViewModel>();
    await petVm.loadPets(uid);

    final apptService = AppointmentService();
    List<AppointmentModel> tomorrowList = [];
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    for (final pet in petVm.pets) {
      try {
        final appointments = await apptService.fetchAppointments(pet.id);
        final filtered = appointments.where((a) {
          if (a.status != 'pending') return false;
          return a.appointmentDate.year == tomorrow.year &&
              a.appointmentDate.month == tomorrow.month &&
              a.appointmentDate.day == tomorrow.day;
        }).toList();
        tomorrowList.addAll(filtered);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _allTomorrowAppointments = tomorrowList;
      });

      if (tomorrowList.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recordatorio: Tienes ${tomorrowList.length} cita(s) programada(s) para mañana.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showRemindersDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFF2E7D32)),
            SizedBox(width: 10),
            Text('Avisos de Mañana'),
          ],
        ),
        content: _allTomorrowAppointments.isEmpty
            ? const Text('No tienes citas programadas para el dia de mañana.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _allTomorrowAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final a = _allTomorrowAppointments[i];
                    return Card(
                      color: const Color(0xFFF5FAF5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.motive,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text('Hora: ${a.timeStr}', style: const TextStyle(fontSize: 12)),
                            if (a.vetName != null)
                              Text('Veterinario: ${a.vetName}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final petVm = context.watch<PetViewModel>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _AppBarSliver(
            user: authVm.user,
            onProfileTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _load());
            },
            onNotificationsTap: _showRemindersDialog,
            hasReminders: _allTomorrowAppointments.isNotEmpty,
          ),
          SliverToBoxAdapter(
            child: _SearchBar(
              controller: _searchCtrl,
              onChanged: petVm.setSearch,
              onClear: () {
                _searchCtrl.clear();
                petVm.setSearch('');
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _SpeciesFilter(
              species: _species,
              selected: petVm.speciesFilter,
              onSelect: petVm.setSpeciesFilter,
            ),
          ),
          if (petVm.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            )
          else if (petVm.pets.isEmpty)
            SliverFillRemaining(child: _EmptyState(onAdd: _openForm))
          else
            _PetGrid(
              pets: petVm.pets,
              onTap: (pet) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetDetailScreen(initialPet: pet),
                ),
              ).then((_) => _load()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_pet',
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva mascota'),
      ),
    );
  }

  void _openForm() {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetFormScreen(userId: uid)),
    ).then((_) => _load());
  }
}

class _AppBarSliver extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final bool hasReminders;

  const _AppBarSliver({
    required this.user,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.hasReminders,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user?.fullName != null && user!.fullName!.isNotEmpty
        ? user!.fullName!.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    ImageProvider? imageProvider;
    if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(user!.avatarUrl!);
    }

    return SliverAppBar(
      floating: true,
      snap: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VetCare'),
          Text(
            user?.fullName != null ? 'Hola, ${user!.fullName!.split(" ").first}' : 'Hola, Veterinario',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Avisos',
              onPressed: onNotificationsTap,
            ),
            if (hasReminders)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onProfileTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
                color: Colors.white24,
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar mascota...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : null,
        ),
      ),
    );
  }
}

class _SpeciesFilter extends StatelessWidget {
  final List<String> species;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SpeciesFilter({
    required this.species,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: species.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = species[i];
          final active = selected == s;
          return FilterChip(
            label: Text(s),
            selected: active,
            onSelected: (_) => onSelect(s),
            selectedColor: const Color(0xFF2E7D32),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: active ? Colors.white : Colors.grey.shade700,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.pets,
                size: 60,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin mascotas registradas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra a tu primera mascota\npara llevar su historial clínico',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar mascota'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetGrid extends StatelessWidget {
  final List<PetModel> pets;
  final ValueChanged<PetModel> onTap;

  const _PetGrid({required this.pets, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _PetCard(pet: pets[i], onTap: () => onTap(pets[i])),
          childCount: pets.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final PetModel pet;
  final VoidCallback onTap;

  const _PetCard({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _speciesColor(pet.species);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _buildPhoto(color)),
            Expanded(flex: 2, child: _buildInfo(color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(Color color) {
    if (pet.photoUrl != null) {
      return Image.network(
        pet.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _placeholder(color),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Center(
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              ),
      );
    }
    return _placeholder(color);
  }

  Widget _placeholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(_speciesIcon(pet.species), size: 52, color: color),
      ),
    );
  }

  Widget _buildInfo(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pet.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pet.species,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pet.ageString,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  IconData _speciesIcon(String s) {
    switch (s.toLowerCase()) {
      case 'perro':
        return Icons.pets;
      case 'gato':
        return Icons.catching_pokemon;
      case 'ave':
        return Icons.flutter_dash;
      case 'conejo':
        return Icons.cruelty_free;
      default:
        return Icons.pets;
    }
  }

  Color _speciesColor(String s) {
    switch (s.toLowerCase()) {
      case 'perro':
        return const Color(0xFF1565C0);
      case 'gato':
        return const Color(0xFF6A1B9A);
      case 'ave':
        return const Color(0xFF00838F);
      case 'conejo':
        return const Color(0xFFAD1457);
      case 'reptil':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF37474F);
    }
  }
}
