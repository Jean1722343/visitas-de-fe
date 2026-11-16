import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../services/fotos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'sin_iglesia.dart';

/// Perfil del usuario: su nombre y su foto, que ve el resto del equipo.
class PantallaMiPerfil extends ConsumerStatefulWidget {
  const PantallaMiPerfil({super.key});
  @override
  ConsumerState<PantallaMiPerfil> createState() => _PantallaMiPerfilState();
}

class _PantallaMiPerfilState extends ConsumerState<PantallaMiPerfil> {
  late final _nombre = TextEditingController(text: ref.read(miNombreProvider));
  File? _foto;
  bool _ocupado = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      avisar(context, 'Escribe tu nombre.');
      return;
    }
    setState(() => _ocupado = true);
    final ok = await intentar(context, () async {
      // Foto pequeña: cabe dentro de la ficha de cada iglesia.
      final foto = _foto == null
          ? null
          : (await prepararFoto(_foto!, lado: 256, ladoMini: 256)).miniatura;
      ref
          .read(repoProvider)
          .guardarMiPerfil(
            nombre: nombre,
            foto: foto,
            iglesias: ref.read(perfilProvider).value?.iglesias ?? const [],
          );
    });
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) {
      avisar(context, 'Perfil guardado.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider).value;
    final yo = ref.watch(yoProvider).value;
    final iglesia = ref.watch(iglesiaProvider).value;
    final correo = ref.read(repoProvider).miCorreo;
    final fotoActual = yo?.foto ?? perfil?.foto;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: 'Cambiar mi foto',
              child: GestureDetector(
                onTap: () async {
                  final f = await elegirFoto(context);
                  if (f != null) setState(() => _foto = f);
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (_foto != null)
                      CircleAvatar(
                        radius: 56,
                        backgroundImage: FileImage(_foto!),
                      )
                    else
                      FotoPersona(_nombre.text, fotoActual, radio: 56),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colores.coral,
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 18,
                        color: Colores.blanco,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Toca la foto para cambiarla',
              style: TextStyle(fontSize: 12.5, color: Colores.textoSuave),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Tu nombre',
              helperText:
                  'Así te ven los demás y aparece en los registros que hagas',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (correo.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.alternate_email_rounded),
                    title: const Text('Correo'),
                    subtitle: Text(correo),
                  ),
                if (yo != null)
                  ListTile(
                    leading: Icon(iconoRol(yo.rol)),
                    title: Text(yo.rol.nombre),
                    subtitle: Text('En ${iglesia?.nombre ?? 'esta iglesia'}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _ocupado ? null : _guardar,
            child: Text(_ocupado ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
