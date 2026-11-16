import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'formulario.dart';
import 'registros.dart';

class PantallaHospitales extends ConsumerWidget {
  const PantallaHospitales({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(hospitalesProvider);
    final hospitales = asincrono.value ?? const <Hospital>[];
    final registros = ref.watch(registrosProvider).value ?? const [];
    final esAdmin = ref.watch(esAdminProvider);
    final activos = hospitales.where((h) => h.activo).toList();
    final inactivos = hospitales.where((h) => !h.activo).toList();

    Widget tarjeta(int i, Hospital h) {
      final n = registros.where((r) => r.hospitalId == h.id).length;
      final ultima = registros.where((r) => r.hospitalId == h.id).firstOrNull;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Entrada(
          orden: i,
          child: _TarjetaHospital(
            hospital: h,
            registros: n,
            ultimoRegistro: ultima?.fecha,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hospitales')),
      floatingActionButton: esAdmin
          ? FloatingActionButton.extended(
              heroTag: 'nuevo-hospital',
              onPressed: () => editarHospital(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Hospital'),
            )
          : null,
      body: asincrono.isLoading && hospitales.isEmpty
          ? const Cargando()
          : hospitales.isEmpty
          ? Vacio(
              icono: Icons.local_hospital_rounded,
              texto: esAdmin
                  ? 'Agrega los hospitales que visita tu iglesia.'
                  : 'Un administrador todavía no agrega los hospitales que '
                        'visitan.',
              boton: esAdmin ? 'Agregar hospital' : null,
              alTocar: esAdmin ? () => editarHospital(context, ref) : null,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                for (final (i, h) in activos.indexed) tarjeta(i, h),
                if (inactivos.isNotEmpty) ...[
                  const TituloSeccion('Ya no se visitan'),
                  for (final (i, h) in inactivos.indexed) tarjeta(i, h),
                ],
              ],
            ),
    );
  }
}

class _TarjetaHospital extends StatelessWidget {
  const _TarjetaHospital({
    required this.hospital,
    required this.registros,
    required this.ultimoRegistro,
  });

  final Hospital hospital;
  final int registros;
  final DateTime? ultimoRegistro;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => abrir(context, PantallaHospital(hospital.id)),
      child: Opacity(
        opacity: hospital.activo ? 1 : .6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: suave(context.principal, .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: context.principal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (hospital.direccion.isNotEmpty ||
                        hospital.ciudad.isNotEmpty)
                      Text(
                        [
                          hospital.direccion,
                          hospital.ciudad,
                        ].where((s) => s.isNotEmpty).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colores.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '$registros ${registros == 1 ? 'registro' : 'registros'}'
                      '${ultimoRegistro == null ? '' : ' · el último ${fechaRelativa(ultimoRegistro!).toLowerCase()}'}',
                      style: TextStyle(
                        color: oscuro(context.principal, .1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colores.textoApagado,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Alta o edición de un hospital (solo administradores).
Future<void> editarHospital(
  BuildContext context,
  WidgetRef ref, [
  Hospital? h,
]) async {
  final nombre = TextEditingController(text: h?.nombre);
  final direccion = TextEditingController(text: h?.direccion);
  final ciudad = TextEditingController(
    text: h?.ciudad ?? ref.read(iglesiaProvider).value?.ciudad,
  );
  final telefono = TextEditingController(text: h?.telefono);
  final notas = TextEditingController(text: h?.notas);
  var activo = h?.activo ?? true;
  final form = GlobalKey<FormState>();

  final guardar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, actualizar) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(c).bottom,
        ),
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  h == null ? 'Nuevo hospital' : 'Editar hospital',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nombre,
                  autofocus: h == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Hospital General, IMSS Clínica 1…',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: direccion,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ciudad,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: telefono,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notas,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Notas para los servidores',
                    hintText:
                        'Horario de visita, entrada, a quién pedir permiso',
                  ),
                ),
                if (h != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: activo,
                    onChanged: (v) => actualizar(() => activo = v),
                    title: const Text('Se sigue visitando'),
                    subtitle: const Text(
                      'Si lo apagas, ya no aparece al registrar, pero se '
                      'conservan sus registros.',
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (form.currentState!.validate()) Navigator.pop(c, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (guardar != true) return;
  ref
      .read(repoProvider)
      .guardarHospital(
        ref.read(iglesiaIdProvider)!,
        Hospital(
          id: h?.id ?? '',
          nombre: nombre.text,
          direccion: direccion.text,
          ciudad: ciudad.text,
          telefono: telefono.text,
          notas: notas.text,
          activo: activo,
        ),
      );
}

/// Un hospital: sus datos, sus visitas y las personas registradas ahí.
class PantallaHospital extends ConsumerWidget {
  const PantallaHospital(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = (ref.watch(hospitalesProvider).value ?? const [])
        .where((h) => h.id == id)
        .firstOrNull;
    if (h == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vacio(
          icono: Icons.local_hospital_rounded,
          texto: 'Este hospital ya no existe.',
        ),
      );
    }
    final esAdmin = ref.watch(esAdminProvider);
    final registros =
        ref
            .watch(registrosDondeProvider((campo: 'hospitalId', valor: id)))
            .value ??
        const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(h.nombre),
        actions: [
          if (esAdmin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'editar') {
                  editarHospital(context, ref, h);
                } else if (v == 'borrar') {
                  if (registros.isNotEmpty) {
                    avisar(
                      context,
                      'Tiene registros: mejor desactívalo desde Editar para '
                      'conservarlos.',
                    );
                    return;
                  }
                  final ok = await confirmar(
                    context,
                    titulo: 'Borrar hospital',
                    texto: '¿Borrar ${h.nombre}?',
                    aceptar: 'Borrar',
                    peligroso: true,
                  );
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  ref
                      .read(repoProvider)
                      .borrarHospital(ref.read(iglesiaIdProvider)!, h.id)
                      .ignore();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'borrar', child: Text('Borrar')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            child: Column(
              children: [
                if (h.direccion.isNotEmpty || h.ciudad.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.place_rounded),
                    title: Text(
                      [
                        h.direccion,
                        h.ciudad,
                      ].where((s) => s.isNotEmpty).join(', '),
                    ),
                    trailing: const Icon(Icons.map_rounded),
                    onTap: () => abrirMapa(
                      [
                        h.nombre,
                        h.direccion,
                        h.ciudad,
                      ].where((s) => s.isNotEmpty).join(', '),
                    ),
                  ),
                if (h.telefono.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.phone_rounded),
                    title: Text(h.telefono),
                    trailing: const Icon(Icons.call_rounded),
                    onTap: () => llamar(h.telefono),
                  ),
                if (h.notas.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.info_rounded),
                    title: Text(h.notas),
                  ),
                if (h.direccion.isEmpty &&
                    h.ciudad.isEmpty &&
                    h.telefono.isEmpty &&
                    h.notas.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(
                      esAdmin
                          ? 'Agrega dirección, teléfono u horario de visita'
                          : 'Sin datos de contacto.',
                    ),
                    trailing: esAdmin ? const Icon(Icons.edit_rounded) : null,
                    onTap: esAdmin
                        ? () => editarHospital(context, ref, h)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (h.activo)
            FilledButton.icon(
              onPressed: () => abrir(context, PantallaFormulario(hospital: h)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Registrar persona aquí'),
            ),
          TituloSeccion(
            registros.isEmpty
                ? 'Personas registradas'
                : '${registros.length} ${registros.length == 1 ? 'persona registrada' : 'personas registradas'}',
          ),
          if (registros.isEmpty)
            const Text(
              'Aún no hay personas registradas en este hospital.',
              style: TextStyle(color: Colores.textoSuave),
            ),
          for (final r in registros)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRegistro(r, mostrarHospital: false),
            ),
        ],
      ),
    );
  }
}
