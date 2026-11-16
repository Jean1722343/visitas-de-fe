import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../services/actualizacion.dart';
import '../widgets/comunes.dart';

/// Vigila si hay versión nueva: al abrir la app y cada vez que se vuelve a
/// ella. Si la hay, la descarga sola y abre el instalador de Android. Si la
/// persona cancela la instalación, se le vuelve a ofrecer al regresar.
class VigilanteDeActualizaciones extends ConsumerStatefulWidget {
  const VigilanteDeActualizaciones({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<VigilanteDeActualizaciones> createState() => _VigilanteState();
}

class _VigilanteState extends ConsumerState<VigilanteDeActualizaciones>
    with WidgetsBindingObserver {
  DateTime? _ultimaRevision;
  bool _dialogoAbierto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _revisar();
  }

  Future<void> _revisar() async {
    if (_dialogoAbierto) return;
    // Al volver a la app se revisa como mucho cada 2 minutos.
    final ahora = DateTime.now();
    if (_ultimaRevision != null &&
        ahora.difference(_ultimaRevision!) < const Duration(minutes: 2)) {
      return;
    }
    _ultimaRevision = ahora;
    final instalada = await ref.read(versionInstaladaProvider.future);
    final a = await buscarActualizacion(instalada);
    if (a == null || !mounted || _dialogoAbierto) return;
    _dialogoAbierto = true;
    await mostrarActualizacion(context, a);
    _dialogoAbierto = false;
    // Si se cerró sin instalar, al volver a la app se ofrece de nuevo.
    _ultimaRevision = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Diálogo que descarga la versión nueva en cuanto aparece.
Future<void> mostrarActualizacion(BuildContext context, Actualizacion a) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Dialogo(a),
    );

class _Dialogo extends StatefulWidget {
  const _Dialogo(this.a);
  final Actualizacion a;
  @override
  State<_Dialogo> createState() => _DialogoState();
}

enum _Fase { descargando, instalando, sinPermiso, error }

class _DialogoState extends State<_Dialogo> with WidgetsBindingObserver {
  _Fase _fase = _Fase.descargando;
  double? _avance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actualizar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver de dar el permiso, se reintenta solo.
    if (estado == AppLifecycleState.resumed && _fase == _Fase.sinPermiso) {
      _actualizar();
    }
  }

  Future<void> _actualizar() async {
    setState(() {
      _fase = _Fase.descargando;
      _avance = null;
    });
    try {
      await descargarEInstalar(
        widget.a,
        alAvanzar: (v) {
          if (mounted) setState(() => _avance = v);
        },
      );
      if (mounted) setState(() => _fase = _Fase.instalando);
    } on PermisoInstalacion {
      if (mounted) setState(() => _fase = _Fase.sinPermiso);
    } catch (_) {
      if (mounted) setState(() => _fase = _Fase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mb = widget.a.tamano > 0
        ? '${(widget.a.tamano / 1048576).toStringAsFixed(0)} MB'
        : '';
    final (titulo, texto) = switch (_fase) {
      _Fase.descargando => (
        'Actualizando',
        'Descargando la versión ${widget.a.version}${mb.isEmpty ? '' : ' ($mb)'}. '
            'No se pierde nada: tu sesión y los registros se quedan.',
      ),
      _Fase.instalando => (
        'Toca «Actualizar»',
        'Android te pide confirmar. Toca «Actualizar» o «Instalar» en la '
            'ventana que apareció y la app se abrirá con la versión nueva.',
      ),
      _Fase.sinPermiso => (
        'Falta un permiso',
        'En la pantalla que se abrió, activa «Permitir de esta fuente» y '
            'regresa: la actualización sigue sola.',
      ),
      _Fase.error => (
        'No se pudo descargar',
        'Revisa tu conexión. La app sigue funcionando y lo intentará de '
            'nuevo más tarde.',
      ),
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(
          _fase == _Fase.error
              ? Icons.cloud_off_rounded
              : Icons.system_update_rounded,
          size: 42,
          color: _fase == _Fase.error ? Colores.rojo : context.principal,
        ),
        title: Text(titulo, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(texto, textAlign: TextAlign.center),
              if (widget.a.notas.isNotEmpty && _fase == _Fase.descargando) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: suave(context.principal, .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.a.notas,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colores.tinta,
                    ),
                  ),
                ),
              ],
              if (_fase == _Fase.descargando) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: _avance, minHeight: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _avance == null
                      ? 'Conectando…'
                      : '${(_avance! * 100).round()} %',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_fase == _Fase.error || _fase == _Fase.instalando)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
          if (_fase == _Fase.error || _fase == _Fase.instalando)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(130, 46)),
              onPressed: _actualizar,
              child: Text(
                _fase == _Fase.error ? 'Reintentar' : 'Abrir instalador',
              ),
            ),
          if (_fase == _Fase.sinPermiso)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(130, 46)),
              onPressed: _actualizar,
              child: const Text('Ya di el permiso'),
            ),
        ],
      ),
    );
  }
}

/// Botón para buscar actualizaciones a mano (en la pestaña Iglesia).
Future<void> buscarAMano(BuildContext context, WidgetRef ref) async {
  avisar(context, 'Buscando actualizaciones…');
  final instalada = await ref.read(versionInstaladaProvider.future);
  final a = await buscarActualizacion(instalada);
  if (!context.mounted) return;
  if (a == null) {
    avisar(context, 'Ya tienes la versión más reciente ($instalada).');
  } else {
    mostrarActualizacion(context, a);
  }
}
