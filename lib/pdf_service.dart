import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  // URLs de las imágenes de los logos
  static const String logoJcrUrl = 'https://huvxdtlbmzoylmgedanb.supabase.co/storage/v1/object/public/logos/logo_jcr.jpg';
  static const String logoConocerUrl = 'https://huvxdtlbmzoylmgedanb.supabase.co/storage/v1/object/public/logos/logo_conocer.png'; 
  static const String logoContpaqUrl = 'https://huvxdtlbmzoylmgedanb.supabase.co/storage/v1/object/public/logos/logo_contpaq.png';

  static Future<void> generarYDescargarPdf(Map<String, dynamic> ticket) async {
    final pdf = pw.Document();

    // Descarga de imágenes
    Uint8List? firmaBytes;
    Uint8List? logoJcrBytes;
    Uint8List? logoConocerBytes;
    Uint8List? logoContpaqBytes;

    try {
      if (ticket['firma_url'] != null && ticket['firma_url'].toString().isNotEmpty) {
        final resFirma = await http.get(Uri.parse(ticket['firma_url']));
        if (resFirma.statusCode == 200) firmaBytes = resFirma.bodyBytes;
      }
      
      final resJcr = await http.get(Uri.parse(logoJcrUrl));
      if (resJcr.statusCode == 200) logoJcrBytes = resJcr.bodyBytes;

      final resConocer = await http.get(Uri.parse(logoConocerUrl));
      if (resConocer.statusCode == 200) logoConocerBytes = resConocer.bodyBytes;

      final resContpaq = await http.get(Uri.parse(logoContpaqUrl));
      if (resContpaq.statusCode == 200) logoContpaqBytes = resContpaq.bodyBytes;
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ENCABEZADO CON LOGOS MÁS GRANDES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LADO IZQUIERDO: JCR + CONOCER
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Logo JCR
                      pw.Container(
                        width: 120,
                        height: 45,
                        child: logoJcrBytes != null
                            ? pw.Image(pw.MemoryImage(logoJcrBytes), fit: pw.BoxFit.contain)
                            : pw.Text('JCR', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ),
                      pw.SizedBox(height: 4),
                      // Logo Conocer debajo
                      pw.Container(
                        width: 110,
                        height: 35,
                        child: logoConocerBytes != null
                            ? pw.Image(pw.MemoryImage(logoConocerBytes), fit: pw.BoxFit.contain)
                            : pw.Container(),
                      ),
                    ],
                  ),

                  // TEXTO CENTRAL
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Column(
                      children: [
                        pw.Text('JOSE MARIA CANUL RAMOS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('Tels: (999)1662277', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('email: ventas@-asesoria-sistemas.com | contacto@asesoria-sistemas.com', style: const pw.TextStyle(fontSize: 7)),
                        pw.SizedBox(height: 8),
                        pw.Text('HOJA DE SERVICIO', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),

                  // LADO DERECHO: CONTPAQi
                  pw.Container(
                    width: 120,
                    height: 65,
                    child: logoContpaqBytes != null
                        ? pw.Image(pw.MemoryImage(logoContpaqBytes), fit: pw.BoxFit.contain)
                        : pw.Container(),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // TABLA FOLIO Y FECHA
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // CAJA 1: Ticket y Folio
                    pw.Container(
                      width: 140,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.8),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1),
                          1: pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                child: pw.Text('Ticket', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                child: pw.Text('${ticket['folio'] ?? ''}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // CAJA 2: Fecha
                    pw.Container(
                      width: 140,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.8),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1),
                          1: pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                child: pw.Text('FECHA', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                child: pw.Text('${ticket['fecha'] ?? ''}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // TABLA DATOS DEL CLIENTE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('CLIENTE: ${ticket['cliente'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Solicita: ${ticket['solicita'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                ],
              ),

              // TABLA CONTACTO Y HORARIOS
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.1),
                  3: pw.FlexColumnWidth(1.1),
                  4: pw.FlexColumnWidth(2.1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Teléfono', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Lugar', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Hora inicial', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Hora final', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('e-mail', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${ticket['telefono'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${ticket['lugar'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${ticket['hora_inicio'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${ticket['hora_fin'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${ticket['email'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),

              // DESCRIPCIÓN DEL SERVICIO
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text('DESCRIPCIÓN DEL SERVICIO REALIZADO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      height: 280,
                      child: pw.Text('${ticket['descripcion_servicio'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
                    ),
                  ],
                ),
              ),

              // FIRMA Y FINALIZACIÓN
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Asignado a: Albert Ivan Chan Zib', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Recibió servicio: ${ticket['recibio_nombre'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
                            if (firmaBytes != null)
                              pw.Container(
                                height: 35,
                                width: 110,
                                child: pw.Image(pw.MemoryImage(firmaBytes)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Fecha: ${ticket['fecha'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Sanitización y conversión a MAYÚSCULAS
    final String clienteLimpio = (ticket['cliente'] ?? 'CLIENTE')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ''); // Elimina caracteres especiales
    
    final String folio = (ticket['folio'] ?? '0').toString();

    // Nombre dinámico en MAYÚSCULAS
    final String nombreArchivo = 'TICKET${folio} ${clienteLimpio}.pdf';

    // Usar sharePdf para forzar la descarga directa con el nombre correcto en Web
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: nombreArchivo,
    );
  }
}