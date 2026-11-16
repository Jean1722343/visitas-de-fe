import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:visitas_de_fe/services/reporte_pdf.dart';
import 'package:visitas_de_fe/core/version.dart';
import 'package:visitas_de_fe/models/modelos.dart';
import 'package:visitas_de_fe/services/actualizacion.dart';
import 'package:visitas_de_fe/widgets/comunes.dart';

void main() {
  group('versiones', () {
    test('compara números, con o sin v y compilación', () {
      expect(esMasNueva('v1.0.1', '1.0.0'), isTrue);
      expect(esMasNueva('1.2.0', '1.10.0'), isFalse);
      expect(esMasNueva('2.0.0+5', '1.9.9'), isTrue);
      expect(esMasNueva('1.0.0', '1.0.0'), isFalse);
      expect(esMasNueva('1.0', '1.0.0'), isFalse);
    });
  });

  group('release de GitHub', () {
    Map<String, dynamic> release(String tag, List<String> apks) => {
      'tag_name': tag,
      'body': 'Arreglos',
      'assets': [
        for (final n in apks)
          {'name': n, 'browser_download_url': 'https://x/$n', 'size': 1000},
      ],
    };

    test('ignora versiones iguales o viejas', () {
      expect(
        leerVersionPublicada(release('v1.0.0', ['a.apk']), '1.0.0'),
        isNull,
      );
      expect(
        leerVersionPublicada(release('v0.9.0', ['a.apk']), '1.0.0'),
        isNull,
      );
    });

    test('prefiere el APK universal, luego arm64', () {
      final a = leerVersionPublicada(
        release('v1.1.0', [
          'app-armeabi-v7a-release.apk',
          'app-arm64-v8a-release.apk',
          'visitas-de-fe.apk',
        ]),
        '1.0.0',
      )!;
      expect(a.version, '1.1.0');
      expect(a.url, 'https://x/visitas-de-fe.apk');
      expect(a.notas, 'Arreglos');

      final b = leerVersionPublicada(
        release('v1.1.0', [
          'app-armeabi-v7a-release.apk',
          'app-arm64-v8a-release.apk',
        ]),
        '1.0.0',
      )!;
      expect(b.url, 'https://x/app-arm64-v8a-release.apk');
    });

    test('sin APK no hay actualización', () {
      expect(
        leerVersionPublicada(release('v2.0.0', ['notas.txt']), '1.0.0'),
        isNull,
      );
      expect(leerVersionPublicada('basura', '1.0.0'), isNull);
    });
  });

  test('búsqueda sin acentos', () {
    expect(sinAcentos('José Ñúñez CÁNCER'), 'jose nunez cancer');
  });

  test('el reporte PDF se genera con acentos y familiares', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es');
    final r = Registro(
      id: '1',
      fecha: DateTime(2026, 11, 15),
      hospitalId: 'h1',
      hospitalNombre: 'Hospital General',
      nombre: 'María Ñúñez',
      edad: 54,
      telefono: '4771234567',
      paraQuien: ParaQuien.familiar,
      familiarNombre: 'José Pérez',
      parentesco: 'Esposo',
      padecimiento: 'Cirugía de corazón',
      peticion: 'Que salga bien de la operación',
      registradoPorNombre: 'Ana',
    );
    const filtro = FiltroReporte(titulo: 'Lista actual');
    final pdf = await generarReportePdf(
      iglesia: const Iglesia(
        id: 'i',
        nombre: 'Iglesia de prueba',
        ciudad: 'León',
        lema: '',
        color: 0xFF0F6E64,
        creadoPor: 'x',
      ),
      filtro: filtro,
      registros: filtro.aplicar([r, r, r]),
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(5000));
  });

  test('teléfono para WhatsApp agrega lada de México', () {
    expect(telefonoParaWhatsApp('(477) 123-4567'), '524771234567');
    expect(telefonoParaWhatsApp('+52 477 123 4567'), '524771234567');
  });
}
