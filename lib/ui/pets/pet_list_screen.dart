import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/pet_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/user_avatar_image.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';
import 'pet_photo_image.dart';

class PetListScreen extends StatefulWidget {
  const PetListScreen({super.key});

  @override
  State<PetListScreen> createState() => _PetListScreenState();
}

class _PetListScreenState extends State<PetListScreen> {
  final _searchCtrl = TextEditingController();

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

  void _load() {
    final uid = context.read<AuthViewModel>().user?.id;
    if (uid != null) context.read<PetViewModel>().loadPets(uid);
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final petVm = context.watch<PetViewModel>();
    final firstName = authVm.user?.fullName?.split(' ').first ?? 'Veterinario';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _AppBarSliver(
            name: firstName,
            onLogout: () async {
              await authVm.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
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
          if (petVm.pendingSyncCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                          '${petVm.pendingSyncCount} cambio(s) pendiente(s) de sincronizar',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (petVm.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4D3E)),
              ),
            )
          else if (petVm.pets.isEmpty)
            SliverFillRemaining(
              child: petVm.hasPets
                  ? const _NoSearchResultsState()
                  : _EmptyState(onAdd: _openForm),
            )
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
  final String name;
  final VoidCallback onLogout;

  const _AppBarSliver({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.user;
    final avatarUrl = user?.avatarUrl;

    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: const Color(0xFF1B4D3E),
      elevation: 4,
      shadowColor: const Color(0xFF1B4D3E).withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VetCare',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            'Hola, $name 👋',
            style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 2),
              ),
              child: UserAvatarImage(
                key: ValueKey('${avatarUrl}_${authVm.avatarVersion}'),
                avatarUrl: avatarUrl,
                radius: 16,
                backgroundColor: Colors.white24,
                iconColor: Colors.white,
                iconSize: 18,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Cerrar sesión',
          onPressed: onLogout,
        ),
        const SizedBox(width: 8),
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

  String _emojiForSpecies(String s) {
    switch (s.toLowerCase()) {
      case 'todos':
        return '🔍 Todos';
      case 'perro':
        return '🐶 Perros';
      case 'gato':
        return '🐱 Gatos';
      case 'ave':
        return '🦜 Aves';
      case 'conejo':
        return '🐰 Conejos';
      case 'reptil':
        return '🦎 Reptiles';
      default:
        return '🧩 Otros';
    }
  }

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
          return FilterChip(
            label: Text(_emojiForSpecies(s)),
            selected: active,
            onSelected: (_) => onSelect(s),
            selectedColor: const Color(0xFF1B4D3E),
            checkmarkColor: Colors.white,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: active ? Colors.transparent : const Color(0xFFE0E6E2),
              width: 1,
            ),
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFF333D38),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ).animate(target: active ? 1 : 0).scaleXY(end: 1.08, duration: 150.ms);
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3F0),
                borderRadius: BorderRadius.circular(65),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B4D3E).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.pets, size: 64, color: Color(0xFF1B4D3E)),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 0.92, end: 1.08, duration: 1200.ms, curve: Curves.easeInOut)
            .rotate(begin: -0.05, end: 0.05, duration: 1200.ms, curve: Curves.easeInOut),
            const SizedBox(height: 28),
            const Text(
              '¡Sin mascotas aún!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B4D3E)),
            ),
            const SizedBox(height: 10),
            Text(
              'Registra a tu primera mascota para\ncomenzar a llevar su historial clínico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar mascota'),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white24),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _PetCard(pet: pets[i], onTap: () => onTap(pets[i]))
              .animate(delay: (i * 80).ms)
              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          childCount: pets.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
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
        elevation: 3,
        shadowColor: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: color.withValues(alpha: 0.12), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildPhoto(color)),
            _buildInfo(color),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(Color color) {
    if (pet.displayPhotoSource != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          PetPhotoImage(
            pet: pet,
            fit: BoxFit.cover,
            placeholder: () => _placeholder(color),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Center(
                    child: CircularProgressIndicator(color: color, strokeWidth: 2),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _buildGenderBadge(pet.sex),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _placeholder(color),
        Positioned(
          top: 8,
          right: 8,
          child: _buildGenderBadge(pet.sex),
        ),
      ],
    );
  }

  Widget _placeholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(_speciesIcon(pet.species), size: 48, color: color),
      ),
    );
  }

  Widget _buildGenderBadge(String? sex) {
    final isMale = sex == 'male';
    final isFemale = sex == 'female';
    final icon = isMale ? Icons.male_rounded : (isFemale ? Icons.female_rounded : Icons.device_unknown_rounded);
    final bg = isMale ? const Color(0xFFE3F2FD) : (isFemale ? const Color(0xFFFCE4EC) : const Color(0xFFECEFF1));
    final fg = isMale ? const Color(0xFF1565C0) : (isFemale ? const Color(0xFFC2185B) : const Color(0xFF455A64));

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }

  Widget _buildInfo(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pet.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B4D3E)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _speciesLabel(pet.species),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.cake_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  pet.ageString,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _speciesLabel(String s) {
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
        return const Color(0xFF2B86C5);
      case 'gato':
        return const Color(0xFF9B59B6);
      case 'ave':
        return const Color(0xFF1ABC9C);
      case 'conejo':
        return const Color(0xFFFD746C);
      case 'reptil':
        return const Color(0xFF27AE60);
      default:
        return const Color(0xFF7F8C8D);
    }
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron mascotas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otro nombre o filtro',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
