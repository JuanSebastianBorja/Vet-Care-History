# VetCare History

App móvil desarrollada en Flutter + Dart, con arquitectura MVVM + Provider, y backend en Supabase (Auth, Database, Storage).

VetCare History permite a dueños de mascotas administrar su información clínica, registrar consultas, vacunas, desparasitaciones, citas veterinarias, fotos de exámenes y generar reportes en PDF.

# Características principales
## 🔐 Autenticación & Usuario
- Registro e inicio de sesión con email y contraseña.
- Validación de credenciales y errores claros.
- Edición de nombre y foto de perfil.
- Avatar por defecto si no hay foto.
- Cierre de sesión.


## 🐾 Gestión de mascotas
- Crear mascota con: nombre, especie, raza, nacimiento, foto.
- Buscar mascota por nombre y especie (filtro en tiempo real).
- Editar y eliminar mascotas.
- Ver detalle completo de cada mascota.
- Secciones colapsables para consultas, vacunas, desparasitaciones y fotos.
- Control de notificaciones por mascota.

## 🩺 Historial clínico
- Registrar consultas con motivo, diagnóstico y tratamiento.
- Registrar vacunas y desparasitaciones.
- Recordatorios automáticos según próxima dosis.
- Subir fotos (JPG/PNG) de exámenes.
- Editar o eliminar cualquier registro del historial.

## 📆 Citas veterinarias
- Registrar citas con fecha, motivo, notas y veterinario.
- Notificación 24h antes de la cita.
- Estados: pendiente, completada o cancelada.

## 📄 Reportes en PDF
- Generar reporte clínico por rango de fechas.
- Incluye: datos de mascota + consultas + vacunas + desparasitaciones.
- Descarga automática en el dispositivo.


# Arquitectura del proyecto
El proyecto sigue la arquitectura MVVM, usando Provider como gestor de estado.

```text
lib/
├── core/
│   ├── constants/
│   ├── utils/
│   └── widgets/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── viewmodels/
└── ui/
    ├── auth/
    ├── profile/
    ├── pets/
    ├── historial/
    ├── citas/
    └── reporte/
```

# 🗄️ Base de datos 

## Tablas principales:
- profiles → Información del usuario.
- pets → Mascotas por usuario.
- consultations → Consultas clínicas.
- consultation_photos → Fotos de exámenes.
- vaccines → Vacunas aplicadas.
- dewormings → Desparasitaciones.
- appointments → Citas veterinarias.

## Incluye:
c Triggers de creación de perfiles.
- Row Level Security (RLS) activado.
- Índices para mejorar rendimiento.

# 📚 Tecnologías
- Flutter 3
- Dart
- Supabase (Auth, Database, Storage)
- Provider para estado
- MVVM
- PDF package para reportes

---

# ⚙️ Guía de Despliegue e Instalación Local

Sigue estos pasos para clonar el repositorio, configurar el backend en Supabase, inicializar la base de datos y ejecutar el proyecto localmente.

## 📋 Requisitos Previos
Asegúrate de tener instalado en tu máquina de desarrollo:
* **Flutter SDK** (Versión `>= 3.11.0`).
* **Dart SDK** (instalado junto con Flutter).
* Una cuenta gratuita en **[Supabase](https://supabase.com)**.
* **Git** instalado.

---

## 🚀 Paso 1: Clonar el Repositorio
Abre tu terminal y ejecuta los siguientes comandos para clonar el código e ingresar a la carpeta del proyecto:
```bash
git clone https://github.com/JuanSebastianBorja/Vet-Care-History.git
cd Vet-Care-History
```

---

## 📦 Paso 2: Instalar Dependencias de Flutter
Ejecuta el siguiente comando para descargar e instalar todos los paquetes y dependencias definidos en el `pubspec.yaml`:
```bash
flutter pub get
```

---

## 🗄️ Paso 3: Configurar el Backend en Supabase

### 1. Crear el Proyecto
1. Ve a tu panel de control de Supabase y presiona **New Project**.
2. Asigna un nombre al proyecto (ej. `VetCare History`), establece una contraseña segura para la base de datos y selecciona la región más cercana.

### 2. Inicializar el Esquema de la Base de Datos (SQL Editor)
Dirígete a la sección de **SQL Editor** en la barra lateral de Supabase, crea un nuevo archivo de consulta (*New Query*) y pega el siguiente script completo. Este creará las tablas, activará el cifrado de datos, habilitará Row Level Security (RLS) y configurará un disparador (*trigger*) automático para sincronizar perfiles al registrarse:

```sql
-- Habilitar extensión UUID
create extension if not exists "uuid-ossp";

-- 1. Crear tabla de perfiles (public.profiles)
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS en profiles
alter table public.profiles enable row level security;

-- Políticas de RLS para profiles
create policy "Lectura pública de perfiles" on public.profiles for select using (true);
create policy "Usuarios actualizan su propio perfil" on public.profiles for update using (auth.uid() = id);

-- Función Trigger para crear perfiles automáticamente al registrarse en Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'avatar_url', '')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. Crear tabla de mascotas (public.pets)
create table public.pets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  species text not null,
  breed text,
  birth_date date,
  sex text,
  photo_url text,
  notifications_enabled boolean default true not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.pets enable row level security;

create policy "Ver propias mascotas" on public.pets for select using (auth.uid() = user_id);
create policy "Insertar propias mascotas" on public.pets for insert with check (auth.uid() = user_id);
create policy "Actualizar propias mascotas" on public.pets for update using (auth.uid() = user_id);
create policy "Eliminar propias mascotas" on public.pets for delete using (auth.uid() = user_id);


-- 3. Crear tabla de consultas (public.consultations)
create table public.consultations (
  id uuid default gen_random_uuid() primary key,
  pet_id uuid references public.pets(id) on delete cascade not null,
  visit_date timestamp with time zone not null,
  motive text not null,
  diagnosis text,
  treatment text,
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.consultations enable row level security;

create policy "Ver consultas de sus mascotas" on public.consultations for select using (
  exists (select 1 from public.pets where pets.id = consultations.pet_id and pets.user_id = auth.uid())
);
create policy "Insertar consultas de sus mascotas" on public.consultations for insert with check (
  exists (select 1 from public.pets where pets.id = consultations.pet_id and pets.user_id = auth.uid())
);
create policy "Actualizar consultas de sus mascotas" on public.consultations for update using (
  exists (select 1 from public.pets where pets.id = consultations.pet_id and pets.user_id = auth.uid())
);
create policy "Eliminar consultas de sus mascotas" on public.consultations for delete using (
  exists (select 1 from public.pets where pets.id = consultations.pet_id and pets.user_id = auth.uid())
);


-- 4. Crear tabla de fotos de consultas (public.consultation_photos)
create table public.consultation_photos (
  id uuid default gen_random_uuid() primary key,
  consultation_id uuid references public.consultations(id) on delete cascade not null,
  photo_url text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.consultation_photos enable row level security;

create policy "Ver fotos de consultas de sus mascotas" on public.consultation_photos for select using (
  exists (
    select 1 from public.consultations c
    inner join public.pets p on p.id = c.pet_id
    where c.id = consultation_photos.consultation_id and p.user_id = auth.uid()
  )
);
create policy "Insertar fotos de consultas" on public.consultation_photos for insert with check (
  exists (
    select 1 from public.consultations c
    inner join public.pets p on p.id = c.pet_id
    where c.id = consultation_photos.consultation_id and p.user_id = auth.uid()
  )
);
create policy "Eliminar fotos de consultas" on public.consultation_photos for delete using (
  exists (
    select 1 from public.consultations c
    inner join public.pets p on p.id = c.pet_id
    where c.id = consultation_photos.consultation_id and p.user_id = auth.uid()
  )
);


-- 5. Crear tabla de vacunas (public.vaccines)
create table public.vaccines (
  id uuid default gen_random_uuid() primary key,
  pet_id uuid references public.pets(id) on delete cascade not null,
  vaccine_name text not null,
  application_date date not null,
  next_due_date date,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.vaccines enable row level security;

create policy "Ver vacunas de sus mascotas" on public.vaccines for select using (
  exists (select 1 from public.pets where pets.id = vaccines.pet_id and pets.user_id = auth.uid())
);
create policy "Insertar vacunas de sus mascotas" on public.vaccines for insert with check (
  exists (select 1 from public.pets where pets.id = vaccines.pet_id and pets.user_id = auth.uid())
);
create policy "Actualizar vacunas de sus mascotas" on public.vaccines for update using (
  exists (select 1 from public.pets where pets.id = vaccines.pet_id and pets.user_id = auth.uid())
);
create policy "Eliminar vacunas de sus mascotas" on public.vaccines for delete using (
  exists (select 1 from public.pets where pets.id = vaccines.pet_id and pets.user_id = auth.uid())
);


-- 6. Crear tabla de desparasitaciones (public.dewormings)
create table public.dewormings (
  id uuid default gen_random_uuid() primary key,
  pet_id uuid references public.pets(id) on delete cascade not null,
  product text not null,
  dose text,
  route text,
  application_date date not null,
  next_due_date date,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.dewormings enable row level security;

create policy "Ver desparasitaciones de sus mascotas" on public.dewormings for select using (
  exists (select 1 from public.pets where pets.id = dewormings.pet_id and pets.user_id = auth.uid())
);
create policy "Insertar desparasitaciones" on public.dewormings for insert with check (
  exists (select 1 from public.pets where pets.id = dewormings.pet_id and pets.user_id = auth.uid())
);
create policy "Actualizar desparasitaciones" on public.dewormings for update using (
  exists (select 1 from public.pets where pets.id = dewormings.pet_id and pets.user_id = auth.uid())
);
create policy "Eliminar desparasitaciones" on public.dewormings for delete using (
  exists (select 1 from public.pets where pets.id = dewormings.pet_id and pets.user_id = auth.uid())
);


-- 7. Crear tabla de citas (public.appointments)
create table public.appointments (
  id uuid default gen_random_uuid() primary key,
  pet_id uuid references public.pets(id) on delete cascade not null,
  appointment_datetime timestamp with time zone not null,
  veterinarian_name text,
  motive text not null,
  notes text,
  status text default 'pending'::text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.appointments enable row level security;

create policy "Ver citas de sus mascotas" on public.appointments for select using (
  exists (select 1 from public.pets where pets.id = appointments.pet_id and pets.user_id = auth.uid())
);
create policy "Insertar citas de sus mascotas" on public.appointments for insert with check (
  exists (select 1 from public.pets where pets.id = appointments.pet_id and pets.user_id = auth.uid())
);
create policy "Actualizar citas de sus mascotas" on public.appointments for update using (
  exists (select 1 from public.pets where pets.id = appointments.pet_id and pets.user_id = auth.uid())
);
create policy "Eliminar citas de sus mascotas" on public.appointments for delete using (
  exists (select 1 from public.pets where pets.id = appointments.pet_id and pets.user_id = auth.uid())
);
```

Presiona **Run** para ejecutar el script y crear toda la estructura relacional.

### 3. Configurar el Almacenamiento (Storage Buckets)
Para que los usuarios puedan subir fotos de perfil y exámenes, debes crear los siguientes tres buckets públicos en la sección de **Storage**:
1. `avatars` (Público)
2. `pet-photos` (Público)
3. `exam-photos` (Público)

*Nota: Asegúrate de habilitar la opción de acceso público al crear cada uno para permitir la carga y visualización de URLs públicas.*

---

## 📝 Paso 4: Configurar Credenciales en Flutter
Abre el archivo [app_constants.dart](file:///lib/core/constants/app_constants.dart) y reemplaza la URL y la llave anónima con las credenciales de tu proyecto de Supabase (las puedes obtener en *Project Settings -> API*):
```dart
class AppConstants {
  // Credenciales Supabase
  static const String supabaseUrl = 'https://TU_PROYECTO.supabase.co';
  static const String supabaseAnonKey = 'TU_LLAVE_ANONIMA_SUPABASE';
  
  // ... resto de constantes
}
```

---

## 🛠️ Paso 5: Generar Código de Drift (Base de Datos Local)
La aplicación utiliza Drift para la base de datos offline. Debes regenerar los archivos autogenerados de bases de datos antes de compilar:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📱 Paso 6: Compilar y Ejecutar
Una vez configurado Supabase y generada la base de datos local, puedes compilar y ejecutar el proyecto en tu simulador, emulador o dispositivo físico conectado:

```bash
# Ver dispositivos conectados
flutter devices

# Ejecutar la aplicación en modo Debug
flutter run
```
