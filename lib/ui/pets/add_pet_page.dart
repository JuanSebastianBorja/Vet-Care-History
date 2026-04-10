import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pet_form_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';

class AddPetPage extends StatelessWidget {
  const AddPetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthViewModel>().user?.id;

    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no autenticado')),
        );
        Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => PetFormViewModel(userId: userId),
      child: const _AddPetForm(),
    );
  }
}

class _AddPetForm extends StatefulWidget {
  const _AddPetForm();

  @override
  State<_AddPetForm> createState() => _AddPetFormState();
}

class _AddPetFormState extends State<_AddPetForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PetFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Mascota'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto de perfil
            Center(
              child: GestureDetector(
                onTap: () => viewModel.pickImage(),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: viewModel.selectedImage != null
                      ? FileImage(viewModel.selectedImage!)
                      : null,
                  child: viewModel.selectedImage == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white70)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => viewModel.pickImage(),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('Agregar foto'),
              ),
            ),
            const SizedBox(height: 24),

            // Nombre
            TextFormField(
              controller: viewModel.nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Especie
            TextFormField(
              controller: viewModel.speciesController,
              decoration: const InputDecoration(
                labelText: 'Especie *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La especie es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Raza
            TextFormField(
              controller: viewModel.breedController,
              decoration: const InputDecoration(
                labelText: 'Raza',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),

            // Fecha de nacimiento
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                viewModel.selectedBirthDate != null
                    ? 'Fecha: ${_formatDate(viewModel.selectedBirthDate!)}'
                    : 'Fecha de nacimiento',
              ),
              subtitle: viewModel.selectedBirthDate != null
                  ? Text('Edad: ${_calculateAge(viewModel.selectedBirthDate!)} años')
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  viewModel.selectBirthDate(date);
                }
              },
            ),
            const SizedBox(height: 16),

            // Sexo
            DropdownButtonFormField<String>(
              value: viewModel.selectedSex,
              decoration: const InputDecoration(
                labelText: 'Sexo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.male),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Macho')),
                DropdownMenuItem(value: 'female', child: Text('Hembra')),
                DropdownMenuItem(value: 'unknown', child: Text('Desconocido')),
              ],
              onChanged: (value) {
                setState(() {
                  viewModel.selectedSex = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Notificaciones
            SwitchListTile(
              title: const Text('Activar recordatorios'),
              subtitle: const Text('Recibir notificaciones de citas y vacunas'),
              value: viewModel.notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  viewModel.notificationsEnabled = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Botón guardar
            if (viewModel.status == PetFormStatus.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await viewModel.submitForm();
                    if (viewModel.status == PetFormStatus.success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Mascota registrada exitosamente'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } else if (viewModel.errorMessage != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ ${viewModel.errorMessage}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar Mascota'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
