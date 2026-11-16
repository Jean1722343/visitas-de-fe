import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/modelos.dart';

final _f = DateFormat('dd/MM/yyyy', 'es');

/// Arma el libro de Excel: una hoja con todos los registros y otra con el
/// resumen por hospital y por servidor.
List<int> generarExcel({
  required String iglesia,
  required DateTime desde,
  required DateTime hasta,
  required List<Registro> registros,
}) {
  final libro = Excel.createExcel();
  final inicial = libro.getDefaultSheet();

  final hoja = libro['Registros'];
  hoja.appendRow([TextCellValue('$iglesia - Registros de oración')]);
  hoja.appendRow([
    TextCellValue('Del ${_f.format(desde)} al ${_f.format(hasta)}'),
  ]);
  hoja.appendRow([]);
  hoja.appendRow([
    for (final t in const [
      'Fecha',
      'Hospital',
      'Nombre completo',
      'Edad',
      'Teléfono',
      'Domicilio',
      'Ora por',
      'Familiar',
      'Parentesco',
      'Padecimiento',
      'Ubicación',
      'Petición',
      'Seguimiento',
      'Estado',
      'Testimonio',
      'Oraron',
      'Registró',
      'Notas',
    ])
      TextCellValue(t),
  ]);
  for (final r in registros) {
    hoja.appendRow([
      TextCellValue(_f.format(r.fecha)),
      TextCellValue(r.hospitalNombre),
      TextCellValue(r.nombre),
      r.edad == null ? TextCellValue('') : IntCellValue(r.edad!),
      TextCellValue(r.telefono),
      TextCellValue(r.domicilio),
      TextCellValue(r.paraQuien.nombre),
      TextCellValue(r.familiarNombre),
      TextCellValue(r.parentesco),
      TextCellValue(r.padecimiento),
      TextCellValue(r.ubicacion),
      TextCellValue(r.peticion),
      TextCellValue(r.quiereSeguimiento ? 'Sí' : 'No'),
      TextCellValue(r.estado.nombre),
      TextCellValue(r.testimonio),
      IntCellValue(r.oraron.length),
      TextCellValue(r.registradoPorNombre),
      TextCellValue(r.notas),
    ]);
  }

  final resumen = libro['Resumen'];
  resumen.appendRow([TextCellValue('$iglesia - Resumen')]);
  resumen.appendRow([
    TextCellValue('Del ${_f.format(desde)} al ${_f.format(hasta)}'),
  ]);
  resumen.appendRow([
    TextCellValue('Total de registros'),
    IntCellValue(registros.length),
  ]);
  resumen.appendRow([]);
  resumen.appendRow([
    TextCellValue('Por hospital'),
    TextCellValue('Registros'),
  ]);
  for (final e in _contar(registros.map((r) => r.hospitalNombre))) {
    resumen.appendRow([TextCellValue(e.key), IntCellValue(e.value)]);
  }
  resumen.appendRow([]);
  resumen.appendRow([
    TextCellValue('Por servidor'),
    TextCellValue('Registros'),
  ]);
  for (final e in _contar(registros.map((r) => r.registradoPorNombre))) {
    resumen.appendRow([TextCellValue(e.key), IntCellValue(e.value)]);
  }
  resumen.appendRow([]);
  resumen.appendRow([TextCellValue('Por estado'), TextCellValue('Registros')]);
  for (final e in _contar(registros.map((r) => r.estado.nombre))) {
    resumen.appendRow([TextCellValue(e.key), IntCellValue(e.value)]);
  }

  libro.setDefaultSheet('Registros');
  if (inicial != null && inicial != 'Registros') libro.delete(inicial);
  return libro.save()!;
}

List<MapEntry<String, int>> _contar(Iterable<String> valores) {
  final m = <String, int>{};
  for (final v in valores) {
    m[v.isEmpty ? '(sin dato)' : v] =
        (m[v.isEmpty ? '(sin dato)' : v] ?? 0) + 1;
  }
  return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

Future<void> compartirExcel({
  required String iglesia,
  required DateTime desde,
  required DateTime hasta,
  required List<Registro> registros,
}) async {
  final carpeta = await getTemporaryDirectory();
  final nombre =
      'registros_${DateFormat('yyyy-MM-dd').format(desde)}_'
      '${DateFormat('yyyy-MM-dd').format(hasta)}.xlsx';
  final archivo = File('${carpeta.path}/$nombre');
  await archivo.writeAsBytes(
    generarExcel(
      iglesia: iglesia,
      desde: desde,
      hasta: hasta,
      registros: registros,
    ),
    flush: true,
  );
  await SharePlus.instance.share(
    ShareParams(files: [XFile(archivo.path)], subject: 'Registros - $iglesia'),
  );
}
