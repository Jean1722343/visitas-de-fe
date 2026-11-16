import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Una foto lista para guardarse en Firestore: la versión para ver en
/// grande y una miniatura para las listas.
class FotoPreparada {
  const FotoPreparada(this.grande, this.miniatura);
  final Uint8List grande;
  final Uint8List miniatura;
}

/// Firestore admite documentos de hasta 1 MB; se deja margen.
const pesoMaximoFoto = 700 * 1024;

typedef _Pedido = ({Uint8List bytes, int lado, int ladoMini});

Uint8List _reducir(img.Image original, int lado, int calidad) {
  final mayor = original.width > original.height
      ? original.width
      : original.height;
  final imagen = mayor <= lado
      ? original
      : img.copyResize(
          original,
          width: original.width >= original.height ? lado : null,
          height: original.height > original.width ? lado : null,
          interpolation: img.Interpolation.average,
        );
  return img.encodeJpg(imagen, quality: calidad);
}

FotoPreparada _preparar(_Pedido p) {
  final decodificada = img.decodeImage(p.bytes);
  if (decodificada == null) {
    throw const FormatException('No se pudo leer la foto.');
  }
  final original = img.bakeOrientation(decodificada);
  // Si aun comprimida pesa de más, se baja la calidad hasta que quepa.
  var calidad = 72;
  var grande = _reducir(original, p.lado, calidad);
  while (grande.length > pesoMaximoFoto && calidad > 40) {
    calidad -= 12;
    grande = _reducir(original, p.lado, calidad);
  }
  return FotoPreparada(grande, _reducir(original, p.ladoMini, 62));
}

/// Reduce una foto en segundo plano para no trabar la pantalla.
Future<FotoPreparada> prepararFoto(
  File archivo, {
  int lado = 1280,
  int ladoMini = 320,
}) async {
  final bytes = await archivo.readAsBytes();
  return compute(_preparar, (bytes: bytes, lado: lado, ladoMini: ladoMini));
}
