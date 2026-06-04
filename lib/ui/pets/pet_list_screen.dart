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
      expandedHeight: 110,
      backgroundColor: const Color(0xFF0F766E),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F766E),
                Color(0xFF115E59),
              ],
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VetCare',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user?.fullName != null ? 'Hola, ${user!.fullName!.split(" ").first} 👋' : 'Hola, Veterinario 👋',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  tooltip: 'Avisos',
                  onPressed: onNotificationsTap,
                ),
                if (hasReminders)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF43F5E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onProfileTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8.0),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar mascota...',
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0F766E)),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
                : null,
          ),
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
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: species.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = species[i];
          final active = selected == s;
          return GestureDetector(
            onTap: () => onSelect(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      )
                    : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? Colors.transparent : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  if (active)
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _speciesIcon(s),
                    size: 16,
                    color: active ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade700,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _speciesIcon(String s) {
    switch (s.toLowerCase()) {
      case 'todos':
        return Icons.grid_view_rounded;
      case 'perro':
        return Icons.pets_rounded;
      case 'gato':
        return Icons.catching_pokemon_rounded;
      case 'ave':
        return Icons.flutter_dash_rounded;
      case 'conejo':
        return Icons.cruelty_free_rounded;
      case 'reptil':
        return Icons.bug_report_rounded;
      default:
        return Icons.help_outline_rounded;
    }
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
                ),
                borderRadius: BorderRadius.circular(65),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 64,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Sin mascotas registradas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Text(
              'Registra a tu primera mascota para llevar\nsu expediente clínico al día.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5),
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
          childAspectRatio: 0.85,
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(_speciesIcon(pet.species), size: 48, color: color),
      ),
    );
  }

  Widget _buildInfo(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pet.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pet.species,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pet.ageString,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  IconData _speciesIcon(String s) {
    switch (s.toLowerCase()) {
      case 'perro':
        return Icons.pets_rounded;
      case 'gato':
        return Icons.catching_pokemon_rounded;
      case 'ave':
        return Icons.flutter_dash_rounded;
      case 'conejo':
        return Icons.cruelty_free_rounded;
      default:
        return Icons.pets_rounded;
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
