import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final carpeta = await getTemporaryDirectory();
  final archivo = File('${carpeta.path}/visitas-de-fe-${a.version}.apk');
  // Se borran descargas de versiones anteriores.
  for (final f in carpeta.listSync().whereType<File>()) {
    if (f.path.endsWith('.apk') && f.path != archivo.path) {
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
    await _descargar(a, archivo, alAvanzar);
  }
  final resultado = await _canal.invokeMethod<String>('instalar', {
    'ruta': archivo.path,
  });
  if (resultado == 'sin_permiso') {
    throw const PermisoInstalacion();
  }
}

Future<void> _descargar(
  Actualizacion a,
  File archivo,
  void Function(double) alAvanzar,
) async {
  final temporal = File('${archivo.path}.parte');
  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final pedido = await cliente.getUrl(Uri.parse(a.url));
    pedido.headers.set(HttpHeaders.userAgentHeader, 'visitas-de-fe-app');
    final respuesta = await pedido.close();
    if (respuesta.statusCode != 200) {
      throw HttpException('Respuesta ${respuesta.statusCode}');
    }
    final total = respuesta.contentLength > 0
        ? respuesta.contentLength
        : a.tamano;
    final salida = temporal.openWrite();
    var recibido = 0;
    await for (final trozo in respuesta) {
      salida.add(trozo);
      recibido += trozo.length;
      if (total > 0) alAvanzar(recibido / total);
    }
    await salida.close();
    if (total > 0 && recibido != total) {
      throw const HttpException('Descarga incompleta');
    }
    // Solo cuando llegó completa toma su nombre final.
    await temporal.rename(archivo.path);
  } finally {
    cliente.close(force: true);
  }
}

/// Android necesita que el usuario permita instalar apps desde esta app.
/// Se abre la pantalla del permiso; al volver se reintenta.
class PermisoInstalacion implements Exception {
  const PermisoInstalacion();
}
