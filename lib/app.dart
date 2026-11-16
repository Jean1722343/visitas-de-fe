import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/tema.dart';
import 'features/acceso.dart';
import 'features/principal.dart';
import 'features/sin_iglesia.dart';
import 'services/proveedores.dart';
import 'widgets/comunes.dart';

class AppVisitas extends ConsumerWidget {
  const AppVisitas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Toda la app toma el color que eligió la iglesia abierta.
    final color = ref.watch(iglesiaProvider).value?.color;
    return MaterialApp(
      title: 'Visitas de Fe',
      debugShowCheckedModeBanner: false,
      theme: temaPara(color == null ? Colores.verde : Color(color)),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Puerta(),
    );
  }
}

/// Decide qué ve el usuario según su sesión y su iglesia.
class Puerta extends ConsumerStatefulWidget {
  const Puerta({super.key});
  @override
  ConsumerState<Puerta> createState() => _PuertaState();
}

class _PuertaState extends ConsumerState<Puerta> {
  bool _introTerminada = false;

  Widget? _destino() {
    final sesion = ref.watch(sesionProvider);
    if (sesion.isLoading) return null;
    if (sesion.value == null) return const PantallaAcceso();

    final perfil = ref.watch(perfilProvider);
    if (perfil.isLoading && perfil.value == null) return null;
    if (perfil.value == null) return const _CrearPerfil();

    final id = ref.watch(iglesiaIdProvider);
    if (id == null) return const PantallaSinIglesia();

    final yo = ref.watch(yoProvider);
    final iglesia = ref.watch(iglesiaProvider);
    if (yo.hasError || iglesia.hasError) {
      return const PantallaSinAcceso(
        'No se puede abrir esta iglesia. Puede que ya no tengas acceso.',
      );
    }
    if (yo.value == null || iglesia.value == null) {
      if (yo.isLoading || iglesia.isLoading) return null;
      return const PantallaSinAcceso('Ya no formas parte de esta iglesia.');
    }
    if (!yo.value!.activo) {
      return const PantallaSinAcceso(
        'Un administrador desactivó tu acceso a esta iglesia.',
      );
    }
    return const PantallaPrincipal();
  }

  @override
  Widget build(BuildContext context) {
    // Se leen siempre, para que carguen mientras corre la intro.
    final destino = _destino();
    final Widget actual = !_introTerminada
        ? _Arranque(alTerminar: () => setState(() => _introTerminada = true))
        : destino ??
              const Scaffold(body: Center(child: CircularProgressIndicator()));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 1.03, end: 1.0).animate(a),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(actual.runtimeType), child: actual),
    );
  }
}

/// Pantalla de arranque: la línea de vida se dibuja y termina en la cruz.
class _Arranque extends StatefulWidget {
  const _Arranque({required this.alTerminar});
  final VoidCallback alTerminar;
  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) widget.alTerminar();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.principal,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LineaDeVida(alto: 80, grosor: 3.5),
            const SizedBox(height: 26),
            Text('Visitas de Fe', style: titulo(36, color: Colores.blanco)),
            const SizedBox(height: 8),
            Text(
              'Estuve enfermo, y me visitasteis',
              style: TextStyle(
                color: Colores.blanco.withValues(alpha: .8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La primera vez que alguien entra todavía no tiene perfil: se crea aquí.
class _CrearPerfil extends ConsumerStatefulWidget {
  const _CrearPerfil();
  @override
  ConsumerState<_CrearPerfil> createState() => _CrearPerfilState();
}

class _CrearPerfilState extends ConsumerState<_CrearPerfil> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _crear();
  }

  Future<void> _crear() async {
    setState(() => _error = null);
    try {
      await ref.read(repoProvider).asegurarPerfil();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _error == null
        ? const Cargando()
        : Vacio(
            icono: Icons.cloud_off_rounded,
            texto: mensajeDeError(_error!),
            boton: 'Reintentar',
            alTocar: _crear,
          ),
  );
}
