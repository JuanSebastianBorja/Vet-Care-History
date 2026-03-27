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
- Supabase (Auth, Postgres, Storage)
- Provider para estado
- MVVM
- PDF package para reportes

