import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

class ExcelService {
  static final _supabase = Supabase.instance.client;

  /// Exporta la lista de tickets a un archivo Excel (.xlsx)
  static Future<void> exportarAExcel(List<Map<String, dynamic>> tickets) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Hojas_de_Servicio'];
    excel.setDefaultSheet('Hojas_de_Servicio');

    // ENCABEZADOS DE LA TABLA
    sheet.appendRow([
      TextCellValue('FOLIO'),
      TextCellValue('CLIENTE'),
      TextCellValue('SOLICITA'),
      TextCellValue('TELÉFONO'),
      TextCellValue('EMAIL'),
      TextCellValue('LUGAR'),
      TextCellValue('FECHA'),
      TextCellValue('HORA INICIO'),
      TextCellValue('HORA FIN'),
      TextCellValue('ESTADO'),
      TextCellValue('DESCRIPCIÓN'),
      TextCellValue('RECIBIÓ'),
    ]);

    // FILAS DE DATOS
    for (final t in tickets) {
      sheet.appendRow([
        TextCellValue(t['folio']?.toString() ?? ''),
        TextCellValue(t['cliente']?.toString() ?? ''),
        TextCellValue(t['solicita']?.toString() ?? ''),
        TextCellValue(t['telefono']?.toString() ?? ''),
        TextCellValue(t['email']?.toString() ?? ''),
        TextCellValue(t['lugar']?.toString() ?? ''),
        TextCellValue(t['fecha']?.toString() ?? ''),
        TextCellValue(t['hora_inicio']?.toString() ?? ''),
        TextCellValue(t['hora_fin']?.toString() ?? ''),
        TextCellValue((t['estado'] ?? 'pendiente').toString().toUpperCase()),
        TextCellValue(t['descripcion_servicio']?.toString() ?? ''),
        TextCellValue(t['recibio_nombre']?.toString() ?? ''),
      ]);
    }

    final List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      final Uint8List bytes = Uint8List.fromList(fileBytes);
      final String nombreArchivo =
          'HOJAS_DE_SERVICIO_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      await Printing.sharePdf(
        bytes: bytes,
        filename: nombreArchivo,
      );
    }
  }

  /// Convierte un número de serie de fecha de Excel (ej: 46287) o texto a formato YYYY-MM-DD
  static String _normalizarFecha(String valorRaw) {
    final texto = _limpiarTexto(valorRaw);
    if (texto.isEmpty) return '';

    // Si ya viene en formato YYYY-MM-DD o YYYY/MM/DD
    if (RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}').hasMatch(texto)) {
      return texto.replaceAll('/', '-');
    }

    // Si viene en formato DD/MM/YYYY o DD-MM-YYYY
    final matchDMY = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(texto);
    if (matchDMY != null) {
      final dia = matchDMY.group(1)!.padLeft(2, '0');
      final mes = matchDMY.group(2)!.padLeft(2, '0');
      final anio = matchDMY.group(3)!;
      return '$anio-$mes-$dia';
    }

    // Si es un número entero de serie de Excel (ej: 46287)
    final numExcel = int.tryParse(texto) ?? double.tryParse(texto)?.toInt();
    if (numExcel != null && numExcel > 30000 && numExcel < 100000) {
      // Época base de Excel: 30 de Diciembre de 1899
      final fechaBase = DateTime(1899, 12, 30);
      final dt = fechaBase.add(Duration(days: numExcel));
      final mes = dt.month.toString().padLeft(2, '0');
      final dia = dt.day.toString().padLeft(2, '0');
      return '${dt.year}-$mes-$dia';
    }

    return texto;
  }

  /// Limpia la cadena eliminando caracteres nulos y comillas residuales
  static String _limpiarTexto(dynamic valor) {
    if (valor == null) return '';
    return valor
        .toString()
        .replaceAll('\u0000', '')
        .replaceAll('"', '')
        .trim();
  }

  /// Importa registros desde archivos Excel (.xlsx) o CSV (.csv) a Supabase
  static Future<int> importarDesdeExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return 0;
    }

    final bytes = result.files.single.bytes!;
    final fileName = result.files.single.name.toLowerCase();

    // Obtener folios existentes para evitar duplicados
    final List<dynamic> foliosExistentesResponse =
        await _supabase.from('tickets').select('folio');
    final Set<int> foliosExistentes = foliosExistentesResponse
        .map((e) => e['folio'])
        .where((f) => f != null)
        .map<int>((f) => int.parse(f.toString()))
        .toSet();

    if (fileName.endsWith('.csv')) {
      return await _importarDesdeCSVBytes(bytes, foliosExistentes);
    }

    // Intentar decodificar con la librería 'excel'
    try {
      final excel = Excel.decodeBytes(bytes);
      int insertados = 0;

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          final folioStr = _obtenerValorCelda(row, 0);
          final folioNum = int.tryParse(folioStr);
          final clienteStr = _obtenerValorCelda(row, 1);

          if (clienteStr.isEmpty) continue;

          if (folioNum != null && foliosExistentes.contains(folioNum)) {
            continue;
          }

          final fechaFormateada = _normalizarFecha(_obtenerValorCelda(row, 6));

          final Map<String, dynamic> nuevoTicket = {
            'folio': folioNum,
            'cliente': clienteStr,
            'solicita': _obtenerValorCelda(row, 2),
            'telefono': _obtenerValorCelda(row, 3),
            'email': _obtenerValorCelda(row, 4),
            'lugar': _obtenerValorCelda(row, 5),
            'fecha': fechaFormateada.isNotEmpty ? fechaFormateada : null,
            'hora_inicio': _obtenerValorCelda(row, 7),
            'hora_fin': _obtenerValorCelda(row, 8),
            'estado': _obtenerValorCelda(row, 9).toLowerCase().contains('comp')
                ? 'completado'
                : 'realizando',
            'descripcion_servicio': _obtenerValorCelda(row, 10).isNotEmpty
                ? _obtenerValorCelda(row, 10)
                : 'Importado desde Excel',
            'recibio_nombre': _obtenerValorCelda(row, 11),
          };

          await _supabase.from('tickets').insert(nuevoTicket);
          if (folioNum != null) foliosExistentes.add(folioNum);
          insertados++;
        }
      }

      return insertados;
    } catch (_) {
      // Fallback resiliente usando descompresión ZIP/XML
      return await _importarXLSXResiliente(bytes, foliosExistentes);
    }
  }

  static String _obtenerValorCelda(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) {
      return '';
    }
    final cell = row[index]!;
    if (cell.value == null) {
      return '';
    }
    return _limpiarTexto(cell.value);
  }

  /// Lector resiliente para archivos .xlsx
  static Future<int> _importarXLSXResiliente(
      Uint8List bytes, Set<int> foliosExistentes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Extraer tabla de cadenas compartidas (sharedStrings.xml)
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    final List<String> sharedStrings = [];

    if (sharedStringsFile != null) {
      final content = utf8.decode(sharedStringsFile.content as List<int>);
      final document = XmlDocument.parse(content);
      for (final node in document.findAllElements('si')) {
        sharedStrings.add(node.innerText);
      }
    }

    // 2. Localizar la primera hoja de trabajo (sheet1.xml)
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) return 0;

    final sheetContent = utf8.decode(sheetFile.content as List<int>);
    final sheetDoc = XmlDocument.parse(sheetContent);
    final rowNodes = sheetDoc.findAllElements('row');

    int insertados = 0;
    bool primeraFila = true;

    for (final rowNode in rowNodes) {
      if (primeraFila) {
        primeraFila = false; // Omitir la fila de encabezados
        continue;
      }

      final Map<int, String> celdas = {};

      for (final cellNode in rowNode.findElements('c')) {
        final cellRef = cellNode.getAttribute('r') ?? '';
        final cellType = cellNode.getAttribute('t') ?? '';
        final valNode = cellNode.findElements('v').firstOrNull;

        if (valNode == null) continue;

        String rawVal = valNode.innerText;
        String valFinal = rawVal;

        if (cellType == 's') {
          final idx = int.tryParse(rawVal);
          if (idx != null && idx < sharedStrings.length) {
            valFinal = sharedStrings[idx];
          }
        }

        final colIdx = _columnaLetraAIndice(cellRef);
        celdas[colIdx] = _limpiarTexto(valFinal);
      }

      final folioStr = celdas[0] ?? '';
      final folioNum = int.tryParse(folioStr);
      final clienteStr = celdas[1] ?? '';

      if (clienteStr.isEmpty) continue;

      if (folioNum != null && foliosExistentes.contains(folioNum)) {
        continue;
      }

      final fechaFormateada = _normalizarFecha(celdas[6] ?? '');

      final Map<String, dynamic> nuevoTicket = {
        'folio': folioNum,
        'cliente': clienteStr,
        'solicita': celdas[2] ?? '',
        'telefono': celdas[3] ?? '',
        'email': celdas[4] ?? '',
        'lugar': celdas[5] ?? '',
        'fecha': fechaFormateada.isNotEmpty ? fechaFormateada : null,
        'hora_inicio': celdas[7] ?? '',
        'hora_fin': celdas[8] ?? '',
        'estado': (celdas[9] ?? '').toLowerCase().contains('comp')
            ? 'completado'
            : 'realizando',
        'descripcion_servicio': (celdas[10] ?? '').isNotEmpty
            ? celdas[10]!
            : 'Importado desde Excel',
        'recibio_nombre': celdas[11] ?? '',
      };

      await _supabase.from('tickets').insert(nuevoTicket);
      if (folioNum != null) foliosExistentes.add(folioNum);
      insertados++;
    }

    return insertados;
  }

  static int _columnaLetraAIndice(String ref) {
    final letras = ref.replaceAll(RegExp(r'[0-9]'), '');
    int index = 0;
    for (int i = 0; i < letras.length; i++) {
      index = index * 26 + (letras.codeUnitAt(i) - 64);
    }
    return index > 0 ? index - 1 : 0;
  }

  /// Importador CSV robusto
  static Future<int> _importarDesdeCSVBytes(
      Uint8List bytes, Set<int> foliosExistentes) async {
    String contenido;

    try {
      contenido = const Utf8Decoder(allowMalformed: true).convert(bytes);
    } catch (_) {
      contenido = latin1.decode(bytes);
    }

    contenido = contenido.replaceAll('\u0000', '');

    final primeraLinea = contenido.split('\n').first;
    final String separador = primeraLinea.contains(';') ? ';' : ',';

    final List<List<dynamic>> filas = CsvToListConverter(
      fieldDelimiter: separador,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(contenido);

    if (filas.length <= 1) return 0;

    int insertados = 0;

    for (int i = 1; i < filas.length; i++) {
      final row = filas[i];
      if (row.isEmpty) continue;

      final folioStr = row.isNotEmpty ? _limpiarTexto(row[0]) : '';
      final folioNum = int.tryParse(folioStr);
      final clienteStr = row.length > 1 ? _limpiarTexto(row[1]) : '';

      if (clienteStr.isEmpty) continue;

      if (folioNum != null && foliosExistentes.contains(folioNum)) {
        continue;
      }

      String val(int idx) => idx < row.length ? _limpiarTexto(row[idx]) : '';

      final fechaFormateada = _normalizarFecha(val(6));

      final Map<String, dynamic> nuevoTicket = {
        'folio': folioNum,
        'cliente': clienteStr,
        'solicita': val(2),
        'telefono': val(3),
        'email': val(4),
        'lugar': val(5),
        'fecha': fechaFormateada.isNotEmpty ? fechaFormateada : null,
        'hora_inicio': val(7),
        'hora_fin': val(8),
        'estado': val(9).toLowerCase().contains('comp')
            ? 'completado'
            : 'realizando',
        'descripcion_servicio':
            val(10).isNotEmpty ? val(10) : 'Importado desde CSV',
        'recibio_nombre': val(11),
      };

      await _supabase.from('tickets').insert(nuevoTicket);
      if (folioNum != null) foliosExistentes.add(folioNum);
      insertados++;
    }

    return insertados;
  }
}