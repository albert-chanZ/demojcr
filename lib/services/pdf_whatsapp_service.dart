import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfWhatsAppService {
  /// Genera y comparte por WhatsApp el PDF de un ticket o lista de tickets seleccionados
  static Future<void> compartirPdfPorWhatsApp(List<Map<String, dynamic>> tickets) async {
    if (tickets.isEmpty) return;

    final pdf = pw.Document();

    for (final ticket in tickets) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final folio = ticket['folio']?.toString() ?? 'S/F';
            final cliente = ticket['cliente']?.toString() ?? 'N/A';
            final solicita = ticket['solicita']?.toString() ?? 'N/A';
            final telefono = ticket['telefono']?.toString() ?? 'N/A';
            final email = ticket['email']?.toString() ?? 'N/A';
            final lugar = ticket['lugar']?.toString() ?? 'N/A';
            final fecha = ticket['fecha']?.toString() ?? 'N/A';
            final horaInicio = ticket['hora_inicio']?.toString() ?? 'N/A';
            final horaFin = ticket['hora_fin']?.toString() ?? 'Pendiente';
            final estado = (ticket['estado'] ?? 'realizando').toString().toUpperCase();
            final descripcion = ticket['descripcion_servicio']?.toString() ?? 'Sin descripción';
            final recibio = ticket['recibio_nombre']?.toString() ?? 'N/A';

            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ENCABEZADO DEL TICKET
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'HOJA DE SERVICIO',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'FOLIO: #$folio',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10),

                  // DATOS GENERALES
                  pw.Text('CLIENTE: $cliente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('SOLICITA: $solicita'),
                  pw.Text('TELÉFONO: $telefono  |  EMAIL: $email'),
                  pw.Text('LUGAR: $lugar'),
                  pw.SizedBox(height: 10),

                  // HORARIOS Y ESTADO
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    color: PdfColors.grey200,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('FECHA: $fecha'),
                        pw.Text('HORA: $horaInicio - $horaFin'),
                        pw.Text('ESTADO: $estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 15),

                  // DESCRIPCIÓN
                  pw.Text('DESCRIPCIÓN DEL SERVICIO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(descripcion),
                  ),
                  pw.SizedBox(height: 20),

                  // FIRMA / RECIBIÓ
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 180, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('RECIBIÓ: $recibio'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final Uint8List pdfBytes = await pdf.save();

    final nombreArchivo = tickets.length == 1
        ? 'TICKET_${tickets.first['folio'] ?? 'SERVICIO'}.pdf'
        : 'REPORTES_SELECCIONADOS_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // Abre la ventana de compartir nativa para enviarlo directo por WhatsApp
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: nombreArchivo,
    );
  }
}