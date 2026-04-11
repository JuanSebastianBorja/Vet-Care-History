import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/pet_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../auth/login_screen.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';

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
    final firstName =
        authVm.user?.fullName?.split(' ').first ?? 'Veterinario';

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
  final String name;
  final VoidCallback onLogout;

  const _AppBarSliver({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: Column(
        children: [
          const Text('VetCare'),
          Text(
            'Hola, $name',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Cerrar sesión',
          onPressed: onLogout,
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
