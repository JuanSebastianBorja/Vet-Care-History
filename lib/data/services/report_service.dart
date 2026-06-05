import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/pet_model.dart';
import '../models/consultation_model.dart';
import '../models/vaccine_model.dart';
import '../models/deworming_model.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<Uint8List> generateClinicalReport({
    required PetModel pet,
    required List<ConsultationModel> consultations,
    required List<VaccineModel> vaccines,
    required List<DewormingModel> dewormings,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final df = DateFormat('dd/MM/yyyy');
    final startStr = startDate != null ? df.format(startDate) : 'Inicio';
    final endStr = endDate != null ? df.format(endDate) : 'Presente';
    final dateRangeStr = 'Rango: $startStr - $endStr';

    // Filtrar datos según rango de fechas
    final filteredConsultations = consultations.where((c) {
      if (startDate != null && c.visitDate.isBefore(startDate)) return false;
      if (endDate != null && c.visitDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    final filteredVaccines = vaccines.where((v) {
      if (startDate != null && v.applicationDate.isBefore(startDate)) return false;
      if (endDate != null && v.applicationDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    final filteredDewormings = dewormings.where((d) {
      if (startDate != null && d.applicationDate.isBefore(startDate)) return false;
      if (endDate != null && d.applicationDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE CLÍNICO',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Sistema VetCare', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateRangeStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('Generado: ${df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Pet Details
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DATOS DE LA MASCOTA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Nombre: ${pet.name}'),
                        pw.Text('Especie: ${pet.species}'),
                        pw.Text('Raza: ${pet.breed ?? 'N/A'}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Edad: ${pet.ageString}'),
                        pw.Text('Sexo: ${pet.sexLabel}'),
                        pw.Text('Nacimiento: ${pet.birthDate != null ? df.format(pet.birthDate!) : "Desconocido"}'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Consultations
          pw.Header(level: 1, child: pw.Text('Consultas Médicas (${filteredConsultations.length})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
          if (filteredConsultations.isEmpty)
            pw.Paragraph(text: 'No hay consultas registradas en este rango de fechas.', style: const pw.TextStyle(color: PdfColors.grey500))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Fecha', 'Motivo', 'Diagnóstico', 'Tratamiento', 'Notas'],
              data: filteredConsultations.map((c) => [
                df.format(c.visitDate),
                c.motive,
                c.diagnosis ?? '-',
                c.treatment ?? '-',
                c.notes ?? '-',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellPadding: const pw.EdgeInsets.all(6),
              cellAlignment: pw.Alignment.topLeft,
            ),
          pw.SizedBox(height: 20),

          // Vaccines
          pw.Header(level: 1, child: pw.Text('Vacunas Aplicadas (${filteredVaccines.length})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
          if (filteredVaccines.isEmpty)
            pw.Paragraph(text: 'No hay vacunas registradas en este rango de fechas.', style: const pw.TextStyle(color: PdfColors.grey500))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Fecha Aplicación', 'Vacuna', 'Próxima Dosis'],
              data: filteredVaccines.map((v) => [
                df.format(v.applicationDate),
                v.vaccineName,
                v.nextDueDate != null ? df.format(v.nextDueDate!) : 'Sin programar',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellPadding: const pw.EdgeInsets.all(6),
              cellAlignment: pw.Alignment.topLeft,
            ),
          pw.SizedBox(height: 20),

          // Dewormings
          pw.Header(level: 1, child: pw.Text('Desparasitaciones (${filteredDewormings.length})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
          if (filteredDewormings.isEmpty)
            pw.Paragraph(text: 'No hay desparasitaciones registradas en este rango de fechas.', style: const pw.TextStyle(color: PdfColors.grey500))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Fecha Aplicación', 'Producto', 'Dosis', 'Vía', 'Próxima Dosis'],
              data: filteredDewormings.map((d) => [
                df.format(d.applicationDate),
                d.product,
                d.dose ?? '-',
                d.route ?? '-',
                d.nextDueDate != null ? df.format(d.nextDueDate!) : 'Sin programar',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellPadding: const pw.EdgeInsets.all(6),
              cellAlignment: pw.Alignment.topLeft,
            ),
        ],
      ),
    );

    return pdf.save();
  }
}
