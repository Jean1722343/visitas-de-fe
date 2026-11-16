import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/repo.dart';

// ------------------------------------------------------------------ Fechas

final _larga = DateFormat("EEEE d 'de' MMMM", 'es');
final _corta = DateFormat('d MMM yyyy', 'es');
final _hora = DateFormat('h:mm a', 'es');

String fechaLarga(DateTime d) {
  final s = _larga.format(d);
  final r = s[0].toUpperCase() + s.substring(1);
  return d.year == DateTime.now().year ? r : '$r de ${d.year}';
}

String fechaCorta(DateTime d) => _corta.format(d);
String hora(DateTime d) => _hora.format(d);

/// «Hoy», «Ayer» o la fecha corta.
String fechaRelativa(DateTime d) {
  final hoy = DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(hoy.year, hoy.month, hoy.day);
  final dias = b.difference(a).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  if (dias > 1 && dias < 7) return 'Hace $dias días';
  return fechaCorta(d);
}

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ------------------------------------------------------------------ Errores

String mensajeDeError(Object e) {
  if (e is ErrorDeUso) return e.mensaje;
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no coinciden.';
      case 'email-already-in-use':
        return 'Ya hay una cuenta con ese correo. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'Ese correo no es válido.';
      case 'network-request-failed':
        return 'No hay conexión a internet.';
      case 'web-context-canceled':
      case 'canceled':
        return 'Se canceló el inicio de sesión.';
    }
    return e.message ?? 'No se pudo iniciar sesión.';
  }
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'No tienes permiso para hacer esto.';
      case 'unavailable':
        return 'No hay conexión. Inténtalo cuando tengas señal.';
    }
    return e.message ?? 'Ocurrió un error.';
  }
  return 'Ocurrió un error. Inténtalo de nuevo.';
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Ejecuta una acción y muestra el error si falla. Devuelve si salió bien.
Future<bool> intentar(
  BuildContext context,
  Future<void> Function() accion,
) async {
  try {
    await accion();
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, mensajeDeError(e));
    return false;
  }
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String aceptar = 'Aceptar',
  bool peligroso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: peligroso
              ? TextButton.styleFrom(foregroundColor: Colores.rojo)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r == true;
}

// --------------------------------------------------------------- Navegación

/// Transición: la pantalla nueva sube un poco mientras aparece.
class Ruta<T> extends PageRouteBuilder<T> {
  Ruta(Widget pantalla)
    : super(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => pantalla,
        transitionsBuilder: (_, a, _, child) {
          final curva = CurvedAnimation(
            parent: a,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curva,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .04),
                end: Offset.zero,
              ).animate(curva),
              child: child,
            ),
          );
        },
      );
}

Future<T?> abrir<T>(BuildContext context, Widget pantalla) =>
    Navigator.of(context).push<T>(Ruta<T>(pantalla));

/// Aparición escalonada para listas y tarjetas.
class Entrada extends StatelessWidget {
  const Entrada({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final retraso = (orden.clamp(0, 8)) * 0.06;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (retraso * 1000).round()),
      curve: Interval(
        retraso / (0.42 + retraso),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------------ Piezas

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Mensaje para pantallas sin datos, con una acción opcional.
class Vacio extends StatelessWidget {
  const Vacio({
    super.key,
    required this.icono,
    required this.texto,
    this.boton,
    this.alTocar,
  });

  final IconData icono;
  final String texto;
  final String? boton;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: suave(context.principal),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 40, color: context.principal),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colores.textoSuave),
          ),
          if (boton != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: alTocar, child: Text(boton!)),
          ],
        ],
      ),
    ),
  );
}

String iniciales(String nombre) => nombre
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

/// Foto de una persona, o sus iniciales.
class FotoPersona extends StatelessWidget {
  const FotoPersona(this.nombre, this.foto, {super.key, this.radio = 22});

  final String nombre;
  final Uint8List? foto;
  final double radio;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radio,
    backgroundColor: suave(context.principal, .16),
    foregroundImage: foto == null ? null : MemoryImage(foto!),
    child: Text(
      iniciales(nombre),
      style: TextStyle(
        color: oscuro(context.principal),
        fontFamily: Fuentes.titulos,
        fontWeight: FontWeight.w800,
        fontSize: radio * .72,
      ),
    ),
  );
}

/// Logo de la iglesia o, si no tiene, una cruz sobre su color.
class LogoIglesia extends StatelessWidget {
  const LogoIglesia(this.iglesia, {super.key, this.lado = 48});

  final Iglesia? iglesia;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final logo = iglesia?.logo;
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: Colores.blanco,
        borderRadius: BorderRadius.circular(lado * .28),
        border: Border.all(color: Colores.blanco, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logo != null
          ? Image.memory(logo, fit: BoxFit.cover, gaplessPlayback: true)
          : CustomPaint(painter: _Cruz(Color(iglesia?.color ?? 0xFF0F6E64))),
    );
  }
}

class _Cruz extends CustomPainter {
  _Cruz(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = suave(color, .14));
    final p = Paint()..color = color;
    final g = s.width * .16;
    final r = Radius.circular(g * .3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s.width / 2, s.height / 2),
          width: g,
          height: s.height * .62,
        ),
        r,
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s.width / 2, s.height * .4),
          width: s.width * .46,
          height: g,
        ),
        r,
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(_Cruz old) => old.color != color;
}

/// Monitor cardíaco: latidos reales (onda P, complejo QRS, onda T) que
/// barre la pantalla como en un monitor de hospital. Al final la línea sube
/// y se vuelve una cruz, que se enciende cuando llega el barrido.
class LineaDeVida extends StatefulWidget {
  const LineaDeVida({
    super.key,
    this.color = Colores.blanco,
    this.alto = 56,
    this.animar = true,
    this.grosor = 2.2,
    this.duracion = const Duration(milliseconds: 2600),
  });

  final Color color;
  final double alto;

  /// Si es falso, el trazo se dibuja completo y quieto.
  final bool animar;
  final double grosor;

  /// Lo que tarda un barrido completo.
  final Duration duracion;

  @override
  State<LineaDeVida> createState() => _LineaDeVidaState();
}

class _LineaDeVidaState extends State<LineaDeVida>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duracion);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = !widget.animar || MediaQuery.disableAnimationsOf(context);
    if (quieto) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.alto,
    width: double.infinity,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _Monitor(
            _c.value,
            widget.color,
            widget.grosor,
            quieto: !_c.isAnimating,
          ),
        ),
      ),
    ),
  );
}

/// Un latido dentro de [ancho], empezando en [x0], sobre la línea [base].
void _latido(Path p, double x0, double ancho, double base, double h) {
  double x(double u) => x0 + ancho * u;
  p
    ..lineTo(x(.16), base)
    // Onda P: loma pequeña y redonda.
    ..cubicTo(x(.19), base - h * .10, x(.27), base - h * .10, x(.30), base)
    ..lineTo(x(.37), base)
    // Complejo QRS: muesca, pico alto y afilado, caída profunda.
    ..lineTo(x(.40), base + h * .06)
    ..lineTo(x(.445), base - h * .56)
    ..lineTo(x(.49), base + h * .22)
    ..lineTo(x(.525), base)
    // Segmento ST y onda T: loma ancha.
    ..lineTo(x(.60), base)
    ..cubicTo(x(.65), base - h * .17, x(.76), base - h * .17, x(.81), base)
    ..lineTo(x(1), base);
}

/// Trazo completo: varios latidos y, al final, la subida que forma la cruz.
Path caminoLineaDeVida(Size s) {
  final h = s.height;
  final w = s.width;
  final base = h * .64;
  final cx = w - h * .34; // poste de la cruz
  final r = h * .09; // curva con la que la línea sube
  final brazo = h * .19;
  final brazoY = h * .26;
  final util = cx - r - h * .10;
  final n = (util / (h * 1.55)).floor().clamp(1, 12);
  final ancho = util / n;
  final p = Path()..moveTo(0, base);
  for (var i = 0; i < n; i++) {
    _latido(p, ancho * i, ancho, base, h);
  }
  return p
    ..lineTo(cx - r, base)
    ..quadraticBezierTo(cx, base, cx, base - r)
    ..lineTo(cx, h * .02)
    ..lineTo(cx, brazoY)
    ..lineTo(cx - brazo, brazoY)
    ..lineTo(cx + brazo, brazoY);
}

class _Monitor extends CustomPainter {
  _Monitor(this.t, this.color, this.grosor, {required this.quieto});

  /// Avance del barrido (0 a 1).
  final double t;
  final Color color;
  final double grosor;
  final bool quieto;

  @override
  void paint(Canvas canvas, Size s) {
    final metrica = caminoLineaDeVida(s).computeMetrics().first;
    final largo = metrica.length;
    Paint pincel(double alfa, {double extra = 0, double desenfoque = 0}) {
      final p = Paint()
        ..color = color.withValues(alpha: alfa * color.a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor + extra
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (desenfoque > 0) {
        p.maskFilter = MaskFilter.blur(BlurStyle.normal, desenfoque);
      }
      return p;
    }

    if (quieto) {
      canvas.drawPath(metrica.extractPath(0, largo), pincel(1));
      return;
    }

    // Rastro tenue de todo el trazo, como el fósforo de un monitor.
    canvas.drawPath(metrica.extractPath(0, largo), pincel(.16));

    // El barrido avanza un poco más allá del final para que la cruz se
    // quede encendida un momento.
    final cabeza = largo * (t * 1.25).clamp(0, 1);
    final estela = largo * .42;
    const tramos = 18;
    for (var i = 0; i < tramos; i++) {
      final a = cabeza - estela * (1 - i / tramos);
      final b = cabeza - estela * (1 - (i + 1) / tramos);
      if (b <= 0) continue;
      final alfa = ((i + 1) / tramos);
      canvas.drawPath(
        metrica.extractPath(a.clamp(0, largo), b.clamp(0, largo)),
        pincel(alfa * alfa),
      );
    }
    // Brillo alrededor de la parte más reciente.
    canvas.drawPath(
      metrica.extractPath((cabeza - estela * .25).clamp(0, largo), cabeza),
      pincel(.55, extra: grosor * 2.2, desenfoque: grosor * 2),
    );
    if (cabeza < largo) {
      final tg = metrica.getTangentForOffset(cabeza);
      if (tg != null) {
        canvas.drawCircle(
          tg.position,
          grosor * 4,
          Paint()
            ..color = color.withValues(alpha: .35 * color.a)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, grosor * 3),
        );
        canvas.drawCircle(
          tg.position,
          grosor * 1.3,
          Paint()..color = color.withValues(alpha: color.a),
        );
      }
    } else {
      // La cruz encendida: se desvanece antes del siguiente barrido.
      final brillo = (1 - (t * 1.25 - 1) / .25).clamp(0.0, 1.0);
      final cruz = metrica.extractPath(largo * .86, largo);
      canvas.drawPath(
        cruz,
        pincel(.6 * brillo, extra: grosor * 3, desenfoque: grosor * 3),
      );
      canvas.drawPath(cruz, pincel(brillo));
    }
  }

  @override
  bool shouldRepaint(_Monitor old) =>
      old.t != t || old.color != color || old.quieto != quieto;
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?accion,
      ],
    ),
  );
}

/// Píldora de color con el estado de la petición.
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.estado, {super.key});
  final Estado estado;

  static Color colorDe(Estado e) => switch (e) {
    Estado.pendiente => Colores.coral,
    Estado.orando => Colores.ambar,
    Estado.respondida => Colores.ok,
  };

  static IconData iconoDe(Estado e) => switch (e) {
    Estado.pendiente => Icons.schedule_rounded,
    Estado.orando => Icons.front_hand_rounded,
    Estado.respondida => Icons.favorite_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = colorDe(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoDe(estado), size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            estado.nombre,
            style: TextStyle(
              color: oscuro(c, .15),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una cifra del resumen.
class Cifra extends StatelessWidget {
  const Cifra({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.icono,
    this.color,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.principal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, size: 18, color: c),
            ),
            const SizedBox(height: 10),
            Text(
              valor,
              style: titulo(26)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Colores.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Acciones

Future<File?> elegirFoto(BuildContext context) async {
  final origen = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (origen == null) return null;
  final foto = await ImagePicker().pickImage(
    source: origen,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 88,
  );
  return foto == null ? null : File(foto.path);
}

/// Solo los dígitos de un teléfono; a los de 10 dígitos se les agrega la
/// lada de México para WhatsApp.
String telefonoParaWhatsApp(String tel) {
  final d = tel.replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '52$d' : d;
}

Future<void> llamar(String tel) => launchUrl(Uri(scheme: 'tel', path: tel));

Future<void> whatsapp(String tel, {String texto = ''}) => launchUrl(
  Uri.https('wa.me', '/${telefonoParaWhatsApp(tel)}', {
    if (texto.isNotEmpty) 'text': texto,
  }),
  mode: LaunchMode.externalApplication,
);

Future<void> abrirMapa(String direccion) => launchUrl(
  Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': direccion,
  }),
  mode: LaunchMode.externalApplication,
);

void copiar(BuildContext context, String texto, String aviso) {
  Clipboard.setData(ClipboardData(text: texto));
  avisar(context, aviso);
}
