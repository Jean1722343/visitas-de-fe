import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'formulario.dart';
import 'perfil.dart';
import 'registros.dart';
import 'reportes.dart';

/// Verde de monitor de hospital para la línea de vida.
const _verdeMonitor = Color(0xFF6FF2C8);

class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key, required this.alIr});

  /// Cambia de pestaña en la pantalla principal.
  final ValueChanged<int> alIr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registros = ref.watch(registrosProvider).value ?? const [];
    final uid = ref.watch(miUidProvider);
    final esAdmin = ref.watch(esAdminProvider);
    final hoy = DateTime.now();
    final inicioSemana = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: hoy.weekday - 1));
    final deHoy = registros.where((r) => mismoDia(r.fecha, hoy)).length;
    final deSemana = registros
        .where((r) => !r.fecha.isBefore(inicioSemana))
        .length;
    final activas = registros
        .where((r) => r.estado != Estado.respondida)
        .toList();
    final paraMi = activas.where((r) => !r.oraron.containsKey(uid)).take(4);

    // Fondo claro: la hora y la batería van en oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              const _Barra(),
              const SizedBox(height: 18),
              Entrada(
                child: _Monitor(
                  activas: activas.length,
                  hoy: deHoy,
                  semana: deSemana,
                ),
              ),
              const AvisoSinSubir(),
              if (esAdmin) ...[
                const SizedBox(height: 14),
                Entrada(
                  orden: 1,
                  child: _AccesoListas(nuevos: registros.length),
                ),
              ],
              if (paraMi.isNotEmpty) ...[
                const TituloSeccion('Ora por ellos'),
                for (final (i, r) in paraMi.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Entrada(orden: i + 2, child: _OraPor(r)),
                  ),
              ],
              TituloSeccion(
                'Recientes',
                accion: registros.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => alIr(1),
                        child: const Text('Ver todos'),
                      ),
              ),
              if (registros.isEmpty)
                const _SinRegistros()
              else
                for (final (i, r) in registros.take(4).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Entrada(orden: i + 3, child: TarjetaRegistro(r)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo y nombre de la iglesia, con la foto del usuario.
class _Barra extends ConsumerWidget {
  const _Barra();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iglesia = ref.watch(iglesiaProvider).value;
    final yo = ref.watch(yoProvider).value;
    final nombre = ref.watch(miNombreProvider);
    final h = DateTime.now().hour;
    final saludo = h < 12
        ? 'Buenos días'
        : h < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    return Row(
      children: [
        LogoIglesia(iglesia, lado: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$saludo, ${nombre.split(' ').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colores.textoSuave,
                  fontSize: 13.5,
                ),
              ),
              Text(
                iglesia?.nombre ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titulo(20),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Mi perfil',
          child: GestureDetector(
            onTap: () => abrir(context, const PantallaMiPerfil()),
            child: FotoPersona(nombre, yo?.foto, radio: 22),
          ),
        ),
      ],
    );
  }
}

/// La pieza central: un monitor cardíaco con las peticiones activas y el
/// botón para registrar.
class _Monitor extends StatelessWidget {
  const _Monitor({
    required this.activas,
    required this.hoy,
    required this.semana,
  });

  final int activas;
  final int hoy;
  final int semana;

  @override
  Widget build(BuildContext context) {
    final fondo = oscuro(context.principal, .62);
    return Container(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: fondo.withValues(alpha: .35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Cuadricula())),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _Latido(),
                              const SizedBox(width: 6),
                              Text(
                                'PETICIONES ACTIVAS',
                                style: TextStyle(
                                  color: _verdeMonitor.withValues(alpha: .85),
                                  fontSize: 11.5,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activas',
                            style: titulo(54, color: Colores.blanco).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Dato(valor: hoy, etiqueta: 'hoy'),
                    const SizedBox(width: 18),
                    _Dato(valor: semana, etiqueta: 'semana'),
                  ],
                ),
                const SizedBox(height: 8),
                const LineaDeVida(alto: 74, grosor: 2.4, color: _verdeMonitor),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colores.coral,
                    foregroundColor: Colores.blanco,
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                      fontFamily: Fuentes.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                  onPressed: () => abrir(context, const PantallaFormulario()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Registrar persona'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});
  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$valor', style: titulo(24, color: Colores.blanco)),
        Text(
          etiqueta,
          style: TextStyle(
            color: Colores.blanco.withValues(alpha: .6),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Corazón que late.
class _Latido extends StatefulWidget {
  const _Latido();
  @override
  State<_Latido> createState() => _LatidoState();
}

class _LatidoState extends State<_Latido> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      // Dos golpes rápidos («lub-dub») y una pausa.
      final t = _c.value;
      final golpe = t < .12
          ? t / .12
          : t < .24
          ? 1 - (t - .12) / .12
          : t < .34
          ? (t - .24) / .10 * .7
          : t < .46
          ? .7 - (t - .34) / .12 * .7
          : 0.0;
      return Transform.scale(scale: 1 + golpe * .28, child: child);
    },
    child: const Icon(Icons.favorite_rounded, color: Colores.coral, size: 16),
  );
}

/// Cuadrícula tenue de monitor.
class _Cuadricula extends CustomPainter {
  const _Cuadricula();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1;
    const paso = 22.0;
    for (var x = paso; x < s.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    for (var y = paso; y < s.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Cuadricula old) => false;
}

/// Acceso del administrador a las listas en PDF.
class _AccesoListas extends StatelessWidget {
  const _AccesoListas({required this.nuevos});
  final int nuevos;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => abrir(context, const PantallaReportes()),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: suave(context.principal, .14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: context.principal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lista de oración en PDF',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    nuevos == 0
                        ? 'Sin registros nuevos'
                        : nuevos == 1
                        ? '1 registro nuevo para la lista'
                        : '$nuevos registros nuevos para la lista',
                    style: const TextStyle(
                      color: Colores.textoSuave,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (nuevos > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colores.coral,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$nuevos',
                  style: const TextStyle(
                    color: Colores.blanco,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colores.textoApagado,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SinRegistros extends StatelessWidget {
  const _SinRegistros();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.volunteer_activism_rounded, color: context.principal),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Aún no hay registros. Cuando platiquen con alguien en el '
              'hospital, toquen «Registrar persona».',
              style: TextStyle(color: Colores.textoSuave),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Petición por la que el usuario todavía no ha orado.
class _OraPor extends ConsumerWidget {
  const _OraPor(this.r);
  final Registro r;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        abrir(context, PantallaRegistro(r.id));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: Colores.coral,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.porQuienSeOra,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    [
                      if (r.padecimiento.isNotEmpty) r.padecimiento,
                      r.hospitalNombre,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colores.textoSuave,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () {
                ref
                    .read(repoProvider)
                    .marcarOre(
                      ref.read(iglesiaIdProvider)!,
                      r.id,
                      true,
                      ref.read(miNombreProvider),
                    );
                avisar(
                  context,
                  'Amén. Quedó anotado que oraste por ${r.porQuienSeOra}.',
                );
              },
              icon: const Icon(Icons.front_hand_rounded, size: 18),
              label: const Text('Oré'),
            ),
          ],
        ),
      ),
    ),
  );
}
