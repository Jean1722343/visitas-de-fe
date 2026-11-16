import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/modelos.dart';

final _f = DateFormat('dd/MM/yyyy', 'es');
final _fLarga = DateFormat("d 'de' MMMM 'de' yyyy", 'es');

/// Qué lista se imprime.
class FiltroReporte {
  const FiltroReporte({required this.titulo, this.hospital});

  /// Por ejemplo «Lista actual» o «Lista del 15/11/2026».
  final String titulo;

  /// Solo un hospital (null = todos).
  final Hospital? hospital;

  String descripcion(List<Registro> registros) {
    final fechas = registros.map((r) => r.fecha).toList()..sort();
    return [
      titulo,
      hospital?.nombre ?? 'Todos los hospitales',
      if (fechas.isNotEmpty)
        fechas.first == fechas.last
            ? _f.format(fechas.first)
            : 'Del ${_f.format(fechas.first)} al ${_f.format(fechas.last)}',
    ].join('  ·  ');
  }

  /// Los registros de este filtro, del más antiguo al más reciente.
  List<Registro> aplicar(List<Registro> todos) =>
      todos
          .where((r) => hospital == null || r.hospitalId == hospital!.id)
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
}

/// Arma el reporte: portada con resumen y tablas, y la tabla completa de
/// registros en hojas horizontales.
Future<Uint8List> generarReportePdf({
  required Iglesia iglesia,
  required FiltroReporte filtro,
  required List<Registro> registros,
}) async {
  Future<pw.Font> fuente(String ruta) async =>
      pw.Font.ttf(await rootBundle.load(ruta));
  final texto = await fuente('assets/fuentes/Figtree-400.ttf');
  final negrita = await fuente('assets/fuentes/Figtree-700.ttf');
  final titulos = await fuente('assets/fuentes/Bricolage-800.ttf');

  final color = PdfColor.fromInt(iglesia.color);
  final claro = PdfColor.fromInt(_mezclar(iglesia.color, 0xFFFFFFFF, .88));
  const gris = PdfColor.fromInt(0xFF4E6663);
  const filete = PdfColor.fromInt(0xFFD6E4E1);
  final logo = iglesia.logo == null ? null : pw.MemoryImage(iglesia.logo!);

  final tema = pw.ThemeData.withFont(base: texto, bold: negrita);
  final doc = pw.Document(
    theme: tema,
    title: 'Registros - ${iglesia.nombre}',
    author: iglesia.nombre,
  );

  pw.Widget encabezado(pw.Context c) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: color, width: 2)),
    ),
    child: pw.Row(
      children: [
        if (logo != null) ...[
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(logo, width: 34, height: 34, fit: pw.BoxFit.cover),
          ),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                iglesia.nombre,
                style: pw.TextStyle(font: titulos, fontSize: 15, color: color),
              ),
              pw.Text(
                'Registros de oración  ·  ${filtro.descripcion(registros)}',
                style: const pw.TextStyle(fontSize: 9, color: gris),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  pw.Widget pie(pw.Context c) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'Generado el ${_fLarga.format(DateTime.now())} · Información '
        'confidencial: solo para oración y seguimiento pastoral.',
        style: const pw.TextStyle(fontSize: 7.5, color: gris),
      ),
      pw.Text(
        'Página ${c.pageNumber} de ${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: gris),
      ),
    ],
  );

  pw.Widget tablaResumen(String titulo, Map<String, int> datos) {
    final filas = datos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(font: titulos, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: const ['', 'Registros'],
          data: [
            for (final e in filas) [e.key, '${e.value}'],
          ],
          headerStyle: pw.TextStyle(
            font: negrita,
            fontSize: 9,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: color),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {1: pw.Alignment.centerRight},
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.2),
          },
          oddRowDecoration: pw.BoxDecoration(color: claro),
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: filete, width: .5),
          ),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
        ),
      ],
    );
  }

  Map<String, int> contar(String Function(Registro) clave) {
    final m = <String, int>{};
    for (final r in registros) {
      final k = clave(r).trim().isEmpty ? '(sin dato)' : clave(r).trim();
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  pw.Widget cifra(String valor, String etiqueta) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: claro,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            valor,
            style: pw.TextStyle(font: titulos, fontSize: 20, color: color),
          ),
          pw.Text(
            etiqueta,
            style: const pw.TextStyle(fontSize: 9, color: gris),
          ),
        ],
      ),
    ),
  );

  // --------------------------------------------------- Hoja de resumen
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
      header: encabezado,
      footer: pie,
      build: (c) => [
        pw.Text('Resumen', style: pw.TextStyle(font: titulos, fontSize: 22)),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            cifra('${registros.length}', 'personas registradas'),
            cifra(
              '${registros.where((r) => r.estado != Estado.respondida).length}',
              'peticiones activas',
            ),
            cifra(
              '${registros.where((r) => r.estado == Estado.respondida).length}',
              'oraciones respondidas',
            ),
            cifra(
              '${registros.where((r) => r.quiereSeguimiento).length}',
              'quieren seguimiento',
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        tablaResumen('Por hospital', contar((r) => r.hospitalNombre)),
        pw.SizedBox(height: 14),
        tablaResumen(
          'Por servidor que registró',
          contar((r) => r.registradoPorNombre),
        ),
        pw.SizedBox(height: 14),
        tablaResumen('Por estado', contar((r) => r.estado.nombre)),
        pw.SizedBox(height: 14),
        tablaResumen('Por día', {
          for (final e in contar((r) => _f.format(r.fecha)).entries)
            e.key: e.value,
        }),
      ],
    ),
  );

  // ------------------------------------------- Tabla de todos los datos
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 26),
      header: encabezado,
      footer: pie,
      build: (c) => [
        pw.TableHelper.fromTextArray(
          headers: const [
            'Fecha',
            'Hospital',
            'Persona',
            'Se ora por',
            'Padecimiento',
            'Teléfono',
            'Domicilio',
            'Petición',
            'Estado',
            'Registró',
          ],
          data: [
            for (final r in registros)
              [
                _f.format(r.fecha),
                r.hospitalNombre,
                [r.nombre, if (r.edad != null) '${r.edad} años'].join(', '),
                r.paraQuien == ParaQuien.familiar
                    ? [
                        r.familiarNombre,
                        if (r.parentesco.isNotEmpty) '(${r.parentesco})',
                      ].join(' ')
                    : 'La persona',
                [
                  r.padecimiento,
                  if (r.ubicacion.isNotEmpty) 'Ubic.: ${r.ubicacion}',
                ].where((s) => s.isNotEmpty).join('\n'),
                r.telefono,
                r.domicilio,
                [
                  r.peticion,
                  if (r.quiereSeguimiento) '[Quiere seguimiento]',
                  if (r.testimonio.isNotEmpty) 'Testimonio: ${r.testimonio}',
                ].where((s) => s.isNotEmpty).join('\n'),
                r.estado.nombre,
                r.registradoPorNombre,
              ],
          ],
          headerStyle: pw.TextStyle(
            font: negrita,
            fontSize: 8,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: color),
          cellStyle: const pw.TextStyle(fontSize: 7.5),
          oddRowDecoration: pw.BoxDecoration(color: claro),
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: filete, width: .5),
          ),
          cellAlignment: pw.Alignment.topLeft,
          headerAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(46),
            1: pw.FlexColumnWidth(1.3),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FixedColumnWidth(58),
            6: pw.FlexColumnWidth(1.6),
            7: pw.FlexColumnWidth(2.2),
            8: pw.FixedColumnWidth(50),
            9: pw.FlexColumnWidth(1.1),
          },
        ),
        if (registros.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Text('No hay registros con estos filtros.'),
          ),
      ],
    ),
  );

  return doc.save();
}

/// Mezcla dos colores ARGB: [t] = 0 da [a], 1 da [b].
int _mezclar(int a, int b, double t) {
  int canal(int c, int s) => (c >> s) & 0xFF;
  int mix(int s) =>
      (canal(a, s) + (canal(b, s) - canal(a, s)) * t).round() & 0xFF;
  return 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}
