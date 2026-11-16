import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/version.dart';

/// Repositorio de GitHub donde se publican las versiones (Releases). Cada
/// release lleva como etiqueta la versión (v1.0.1) y el APK como archivo.
const repositorio = 'Jean1722343/visitas-de-fe';

/// Una versión publicada más nueva que la instalada.
class Actualizacion {
  const Actualizacion({
    required this.version,
    required this.url,
    this.notas = '',
    this.tamano = 0,
  });

  final String version;

  /// Enlace directo al APK.
  final String url;

  /// Lo que cambió (el texto del release).
  final String notas;
  final int tamano;
}

final versionInstaladaProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Se pregunta una vez al abrir la app si hay una versión más nueva.
final actualizacionProvider = FutureProvider<Actualizacion?>((ref) async {
  final instalada = await ref.watch(versionInstaladaProvider.future);
  return buscarActualizacion(instalada);
});

/// Consulta la última versión publicada en GitHub. Sin conexión o ante
/// cualquier falla devuelve null y la app sigue igual.
Future<Actualizacion?> buscarActualizacion(String instalada) async {
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final pedido = await cliente.getUrl(
      Uri.https('api.github.com', '/repos/$repositorio/releases/latest'),
    );
    pedido.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'visitas-de-fe-app');
    final respuesta = await pedido.close().timeout(const Duration(seconds: 10));
    if (respuesta.statusCode != 200) return null;
    final datos = jsonDecode(await respuesta.transform(utf8.decoder).join());
    return leerVersionPublicada(datos, instalada);
  } catch (_) {
    return null;
  } finally {
    cliente.close(force: true);
  }
}

/// Saca de la respuesta de GitHub la versión y el APK, solo si es más nueva
/// que la instalada. Si hay varios APK (uno por arquitectura), prefiere el
/// universal o el de arm64, que es el de casi todos los teléfonos.
Actualizacion? leerVersionPublicada(dynamic datos, String instalada) {
  if (datos is! Map) return null;
  final etiqueta = datos['tag_name'];
  if (etiqueta is! String || !esMasNueva(etiqueta, instalada)) return null;
  final archivos = datos['assets'];
  if (archivos is! List) return null;
  Map? elegido;
  var puntos = -1;
  for (final a in archivos) {
    if (a is! Map) continue;
    final nombre = a['name'];
    if (nombre is! String || !nombre.endsWith('.apk')) continue;
    if (a['browser_download_url'] is! String) continue;
    final p = nombre.contains('arm64')
        ? 2
        : (nombre.contains('armeabi') || nombre.contains('x86'))
        ? 0
        : 3;
    if (p > puntos) {
      puntos = p;
      elegido = a;
    }
  }
  if (elegido == null) return null;
  return Actualizacion(
    version: etiqueta.replaceFirst(RegExp('^[vV]'), ''),
    url: elegido['browser_download_url'] as String,
    notas: (datos['body'] as String?)?.trim() ?? '',
    tamano: (elegido['size'] as num?)?.toInt() ?? 0,
  );
}

const _canal = MethodChannel('visitasdefe/instalador');

/// Descarga el APK reportando el avance (0 a 1) y abre el instalador de
/// Android. Android siempre pide confirmar la instalación; la sesión y los
/// datos guardados se conservan.
Future<void> descargarEInstalar(
  Actualizacion a, {
  required void Function(double avance) alAvanzar,
}) async {
  // No en la caché: Android la vacía sola cuando el teléfono tiene poco
  // espacio, aunque sea a mitad de la descarga.
  final carpeta = Directory(
    '${(await getApplicationSupportDirectory()).path}/actualizaciones',
  );
  await carpeta.create(recursive: true);
  final archivo = File('${carpeta.path}/visitas-de-fe-${a.version}.apk');
  // Se borran descargas de versiones anteriores.
  for (final f in carpeta.listSync().whereType<File>()) {
    if (!f.path.startsWith(archivo.path)) {
      f.deleteSync();
    }
  }
  // Si ya se había descargado completa (se canceló la instalación), no se
  // vuelve a bajar.
  final yaEsta =
      a.tamano > 0 && archivo.existsSync() && archivo.lengthSync() == a.tamano;
  if (yaEsta) {
    alAvanzar(1);
  } else {
    // Una sola descarga a la vez: si ya hay una en curso (por ejemplo, la
    // pantalla se reconstruyó), esta se suma a ella en lugar de empezar
    // otra sobre el mismo archivo.
    void avisar() => alAvanzar(_progreso.value);
    _progreso.addListener(avisar);
    try {
      await (_enCurso ??= _descargar(
        a,
        archivo,
        (v) => _progreso.value = v,
      ).whenComplete(() => _enCurso = null));
    } catch (e) {
      // ignore: avoid_print
      print('[actualizacion] descarga: $e');
      throw ErrorActualizacion('descarga', e);
    } finally {
      _progreso.removeListener(avisar);
    }
  }
  final String? resultado;
  try {
    resultado = await _canal.invokeMethod<String>('instalar', {
      'ruta': archivo.path,
    });
  } catch (e) {
    // ignore: avoid_print
    print('[actualizacion] instalador: $e');
    throw ErrorActualizacion('instalador', e);
  }
  if (resultado == 'sin_permiso') {
    throw const PermisoInstalacion();
  }
}

Future<void>? _enCurso;
final _progreso = ValueNotifier<double>(0);

/// Descarga el APK. Si una descarga anterior se cortó (señal débil en el
/// hospital), sigue desde donde se quedó en lugar de empezar de cero.
Future<void> _descargar(
  Actualizacion a,
  File archivo,
  void Function(double) alAvanzar,
) async {
  final temporal = File('${archivo.path}.parte');
  for (var intento = 0; intento < 4; intento++) {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final ya = temporal.existsSync() ? temporal.lengthSync() : 0;
      final pedido = await cliente.getUrl(Uri.parse(a.url));
      pedido.headers.set(HttpHeaders.userAgentHeader, 'visitas-de-fe-app');
      if (ya > 0) pedido.headers.set(HttpHeaders.rangeHeader, 'bytes=$ya-');
      final respuesta = await pedido.close().timeout(
        const Duration(seconds: 30),
      );
      final continua = respuesta.statusCode == HttpStatus.partialContent;
      if (respuesta.statusCode != HttpStatus.ok && !continua) {
        if (respuesta.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
          temporal.deleteSync();
          continue;
        }
        throw HttpException('Respuesta ${respuesta.statusCode}');
      }
      var recibido = continua ? ya : 0;
      final total = continua
          ? ya + respuesta.contentLength
          : (respuesta.contentLength > 0 ? respuesta.contentLength : a.tamano);
      final salida = temporal.openWrite(
        mode: continua ? FileMode.append : FileMode.write,
      );
      try {
        // Si la red se queda congelada 45 s, se corta y se reintenta.
        await for (final trozo in respuesta.timeout(
          const Duration(seconds: 45),
        )) {
          salida.add(trozo);
          recibido += trozo.length;
          if (total > 0) alAvanzar(recibido / total);
        }
      } finally {
        await salida.close();
      }
      if (total > 0 && recibido < total) {
        throw HttpException('Incompleta: $recibido de $total');
      }
      // Solo cuando llegó completa toma su nombre final.
      await temporal.rename(archivo.path);
      return;
    } catch (e) {
      // ignore: avoid_print
      print('[actualizacion] intento ${intento + 1}: $e');
      if (intento == 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 2 * (intento + 1)));
    } finally {
      cliente.close(force: true);
    }
  }
}

/// Falla al descargar o al abrir el instalador.
class ErrorActualizacion implements Exception {
  const ErrorActualizacion(this.paso, this.causa);
  final String paso;
  final Object causa;
  @override
  String toString() => 'Falla en $paso: $causa';
}

/// Android necesita que el usuario permita instalar apps desde esta app.
/// Se abre la pantalla del permiso; al volver se reintenta.
class PermisoInstalacion implements Exception {
  const PermisoInstalacion();
}

/// Borra los APK ya descargados (cuando ya no hay nada que instalar).
Future<void> limpiarDescargas() async {
  try {
    final carpeta = Directory(
      '${(await getApplicationSupportDirectory()).path}/actualizaciones',
    );
    if (carpeta.existsSync()) await carpeta.delete(recursive: true);
  } catch (_) {}
}

/// Si Android ya permite que esta app instale actualizaciones.
Future<bool> puedeInstalar() async {
  try {
    return await _canal.invokeMethod<bool>('puedeInstalar') ?? false;
  } catch (_) {
    return false;
  }
}

/// Abre la pantalla de Ajustes donde se permite instalar la actualización.
Future<void> abrirPermisoInstalacion() async {
  try {
    await _canal.invokeMethod<void>('abrirPermiso');
  } catch (_) {}
}
