import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/proveedores.dart';

import 'actualizar.dart';
import 'hospitales.dart';
import 'iglesia.dart';
import 'inicio.dart';
import 'registros.dart';

/// Pantalla con la barra inferior: Inicio, Registros, Hospitales, Iglesia.
class PantallaPrincipal extends ConsumerStatefulWidget {
  const PantallaPrincipal({super.key});
  @override
  ConsumerState<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends ConsumerState<PantallaPrincipal> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _completarDatos();
  }

  /// Arreglo de datos de versiones anteriores, una vez por iglesia.
  Future<void> _completarDatos() async {
    final id = ref.read(iglesiaIdProvider);
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final clave = 'archivado-completo-$id';
      if (prefs.getBool(clave) ?? false) return;
      await ref.read(repoProvider).completarArchivado(id);
      await prefs.setBool(clave, true);
    } catch (_) {
      // Sin conexión: se intenta la próxima vez.
    }
  }

  void _ir(int i) {
    if (i == _indice) return;
    HapticFeedback.selectionClick();
    setState(() => _indice = i);
  }

  @override
  Widget build(BuildContext context) => VigilanteDeActualizaciones(
    child: Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(_indice),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)),
            child: child,
          ),
        ),
        child: IndexedStack(
          index: _indice,
          children: [
            PantallaInicio(alIr: _ir),
            const PantallaRegistros(),
            const PantallaHospitales(),
            const PantallaIglesia(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Registros',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital_rounded),
            label: 'Hospitales',
          ),
          NavigationDestination(
            icon: Icon(Icons.church_outlined),
            selectedIcon: Icon(Icons.church_rounded),
            label: 'Iglesia',
          ),
        ],
      ),
    ),
  );
}
