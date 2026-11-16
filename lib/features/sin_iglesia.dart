import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/fotos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';

/// Lo que ve quien todavía no pertenece a ninguna iglesia.
class PantallaSinIglesia extends ConsumerWidget {
  const PantallaSinIglesia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(perfilProvider).value?.nombre ?? '';
    return Scaffold(
      backgroundColor: context.principal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LineaDeVida(alto: 60),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenido${nombre.isEmpty ? '' : ', ${nombre.split(' ').first}'}',
                    style: titulo(32, color: Colores.blanco),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Si alguien de tu iglesia te mandó un código, úsalo para '
                    'entrar. Si tú coordinas las visitas, registra tu iglesia.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: Colores.blanco.withValues(alpha: .85),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Entrada(
                    orden: 1,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colores.blanco,
                        foregroundColor: oscuro(context.principal),
                      ),
                      onPressed: () => abrir(context, const PantallaCodigo()),
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Tengo un código'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrada(
                    orden: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colores.blanco,
                        side: const BorderSide(
                          color: Colores.blanco,
                          width: 1.5,
                        ),
                      ),
                      onPressed: () =>
                          abrir(context, const PantallaCrearIglesia()),
                      icon: const Icon(Icons.church_rounded),
                      label: const Text('Registrar mi iglesia'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colores.blanco,
                    ),
                    onPressed: () => ref.read(repoProvider).salir(),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso cuando la iglesia abierta ya no está disponible para el usuario.
class PantallaSinAcceso extends ConsumerWidget {
  const PantallaSinAcceso(this.motivo, {super.key});
  final String motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_rounded, size: 56, color: context.principal),
            const SizedBox(height: 12),
            Text(
              motivo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => abrir(context, const PantallaCodigo()),
              child: const Text('Entrar con otro código'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => abrir(context, const PantallaCrearIglesia()),
              child: const Text('Registrar una iglesia'),
            ),
            if (ref.watch(iglesiaIdProvider) != null)
              TextButton(
                onPressed: () => intentar(
                  context,
                  () => ref
                      .read(repoProvider)
                      .olvidarIglesia(ref.read(iglesiaIdProvider)!),
                ),
                child: const Text('Quitar esta iglesia de mi lista'),
              ),
            TextButton(
              onPressed: () => ref.read(repoProvider).salir(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PantallaCodigo extends ConsumerStatefulWidget {
  const PantallaCodigo({super.key});
  @override
  ConsumerState<PantallaCodigo> createState() => _PantallaCodigoState();
}

class _PantallaCodigoState extends ConsumerState<PantallaCodigo> {
  final _codigo = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _ocupado = true);
    final nombre = ref.read(perfilProvider).value?.nombre ?? 'Servidor';
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).unirseConCodigo(_codigo.text, nombre),
    );
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Código de invitación')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Escribe el código de 6 caracteres que te compartieron. '
          'Necesitas internet solo para este paso.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codigo,
          autofocus: true,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          style: titulo(32).copyWith(letterSpacing: 10),
          decoration: const InputDecoration(hintText: '······'),
          onSubmitted: (_) => _entrar(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _ocupado ? null : _entrar,
          child: Text(_ocupado ? 'Entrando…' : 'Entrar a la iglesia'),
        ),
      ],
    ),
  );
}

/// Reduce una imagen a un logo cuadrado pequeño que cabe en Firestore.
Future<Uint8List> prepararLogo(File archivo) async =>
    (await prepararFoto(archivo, lado: 320, ladoMini: 320)).miniatura;

/// Fila de círculos de color para elegir el color de la iglesia.
class SelectorColor extends StatelessWidget {
  const SelectorColor({
    super.key,
    required this.valor,
    required this.alCambiar,
  });

  final int valor;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final c in coloresIglesia)
        Semantics(
          button: true,
          selected: c.toARGB32() == valor,
          label: 'Color',
          child: GestureDetector(
            onTap: () => alCambiar(c.toARGB32()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.toARGB32() == valor
                      ? Colores.tinta
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: c.toARGB32() == valor
                  ? const Icon(Icons.check_rounded, color: Colores.blanco)
                  : null,
            ),
          ),
        ),
    ],
  );
}

/// Cuadro para elegir o cambiar el logo.
class EditorLogo extends StatelessWidget {
  const EditorLogo({
    super.key,
    required this.logo,
    required this.color,
    required this.alElegir,
    this.alQuitar,
  });

  final Uint8List? logo;
  final int color;
  final VoidCallback alElegir;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: alElegir,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: suave(Color(color), .14),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colores.borde, width: 1.4),
              ),
              clipBehavior: Clip.antiAlias,
              child: logo == null
                  ? Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 34,
                      color: Color(color),
                    )
                  : Image.memory(logo!, fit: BoxFit.cover),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colores.coral,
                child: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Colores.blanco,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logo de la iglesia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aparece en el inicio de la app de todos los miembros.',
              style: TextStyle(fontSize: 13, color: Colores.textoSuave),
            ),
            if (logo != null && alQuitar != null)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: Colores.rojo,
                ),
                onPressed: alQuitar,
                child: const Text('Quitar logo'),
              ),
          ],
        ),
      ),
    ],
  );
}

class PantallaCrearIglesia extends ConsumerStatefulWidget {
  const PantallaCrearIglesia({super.key});
  @override
  ConsumerState<PantallaCrearIglesia> createState() =>
      _PantallaCrearIglesiaState();
}

class _PantallaCrearIglesiaState extends ConsumerState<PantallaCrearIglesia> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _ciudad = TextEditingController();
  final _lema = TextEditingController(
    text: 'Estuve enfermo, y me visitasteis. Mateo 25:36',
  );
  final _hospital = TextEditingController();
  final _hospitales = <String>[];
  int _color = Colores.verde.toARGB32();
  Uint8List? _logo;
  bool _ocupado = false;

  @override
  void dispose() {
    for (final c in [_nombre, _ciudad, _lema, _hospital]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirLogo() async {
    final f = await elegirFoto(context);
    if (f == null) return;
    final logo = await prepararLogo(f);
    if (mounted) setState(() => _logo = logo);
  }

  void _agregarHospital() {
    final h = _hospital.text.trim();
    if (h.isEmpty) return;
    setState(() {
      _hospitales.add(h);
      _hospital.clear();
    });
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    _agregarHospital();
    setState(() => _ocupado = true);
    final ok = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .crearIglesia(
            miNombre: ref.read(perfilProvider).value?.nombre ?? 'Admin',
            nombre: _nombre.text,
            ciudad: _ciudad.text,
            lema: _lema.text,
            color: _color,
            logo: _logo,
            hospitales: _hospitales,
          ),
    );
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => Theme(
    // Vista previa: el formulario ya se pinta con el color elegido.
    data: temaPara(Color(_color)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Registrar iglesia')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Quedarás como administrador: podrás dar de alta los '
                'hospitales, invitar servidores y nombrar a otros '
                'administradores.',
              ),
              const SizedBox(height: 20),
              EditorLogo(
                logo: _logo,
                color: _color,
                alElegir: _elegirLogo,
                alQuitar: () => setState(() => _logo = null),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la iglesia',
                  prefixIcon: Icon(Icons.church_rounded),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Este dato hace falta' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lema,
                maxLines: 2,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Versículo o lema',
                  prefixIcon: Icon(Icons.format_quote_rounded),
                ),
              ),
              const TituloSeccion('Color de la app'),
              SelectorColor(
                valor: _color,
                alCambiar: (c) => setState(() => _color = c),
              ),
              const TituloSeccion('Hospitales que visitan'),
              const Text(
                'Puedes agregarlos ahora o después desde la pestaña '
                'Hospitales.',
                style: TextStyle(color: Colores.textoSuave),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hospital,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del hospital',
                        prefixIcon: Icon(Icons.local_hospital_rounded),
                      ),
                      onSubmitted: (_) => _agregarHospital(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: context.principal,
                      foregroundColor: Colores.blanco,
                      minimumSize: const Size(52, 52),
                    ),
                    tooltip: 'Agregar hospital',
                    onPressed: _agregarHospital,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, h) in _hospitales.indexed)
                    InputChip(
                      avatar: const Icon(
                        Icons.local_hospital_rounded,
                        size: 18,
                      ),
                      label: Text(h),
                      onDeleted: () => setState(() => _hospitales.removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _ocupado ? null : _crear,
                child: Text(_ocupado ? 'Creando…' : 'Crear iglesia'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Necesitas internet para crear la iglesia. Después, todo lo '
                'demás funciona también sin señal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colores.textoSuave),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ícono del rol para listas de miembros.
IconData iconoRol(Rol r) => r == Rol.admin
    ? Icons.admin_panel_settings_rounded
    : Icons.volunteer_activism_rounded;
