import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'formulario.dart';
import 'reportes.dart';

/// Aviso de registros que siguen guardados solo en el teléfono.
class AvisoSinSubir extends ConsumerWidget {
  const AvisoSinSubir({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendientesDeSubirProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: n == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colores.coralSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      color: Colores.coral,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        n == 1
                            ? '1 registro está guardado en tu teléfono. Se '
                                  'subirá solo cuando tengas internet.'
                            : '$n registros están guardados en tu teléfono. '
                                  'Se subirán solos cuando tengas internet.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colores.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Fila de un registro en las listas.
class TarjetaRegistro extends StatelessWidget {
  const TarjetaRegistro(this.r, {super.key, this.mostrarHospital = true});

  final Registro r;
  final bool mostrarHospital;

  @override
  Widget build(BuildContext context) {
    final detalle = [
      if (r.paraQuien == ParaQuien.familiar && r.familiarNombre.isNotEmpty)
        'Contacto: ${r.nombre}${r.parentesco.isEmpty ? '' : ' (${r.parentesco})'}',
      if (r.padecimiento.isNotEmpty) r.padecimiento,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => abrir(context, PantallaRegistro(r.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FotoPersona(r.porQuienSeOra, null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.porQuienSeOra,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        if (r.pendienteDeSubir)
                          const Tooltip(
                            message: 'Guardado en el teléfono, falta subirlo',
                            child: Icon(
                              Icons.cloud_off_rounded,
                              size: 18,
                              color: Colores.coral,
                            ),
                          ),
                      ],
                    ),
                    if (detalle.isNotEmpty)
                      Text(
                        detalle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colores.textoSuave,
                          fontSize: 13.5,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChipEstado(r.estado),
                        if (r.archivado)
                          const Icon(
                            Icons.inventory_2_rounded,
                            size: 16,
                            color: Colores.textoApagado,
                            semanticLabel: 'Archivado',
                          ),
                        if (r.quiereSeguimiento)
                          const Icon(
                            Icons.event_repeat_rounded,
                            size: 17,
                            color: Colores.textoSuave,
                          ),
                        Text(
                          [
                            fechaRelativa(r.fecha),
                            if (mostrarHospital) r.hospitalNombre,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colores.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La «tabla» de registros: búsqueda y filtros.
class PantallaRegistros extends ConsumerStatefulWidget {
  const PantallaRegistros({super.key});
  @override
  ConsumerState<PantallaRegistros> createState() => _PantallaRegistrosState();
}

class _PantallaRegistrosState extends ConsumerState<PantallaRegistros> {
  final _buscar = TextEditingController();
  String _texto = '';
  Estado? _estado;
  String? _hospitalId;
  bool _soloMios = false;
  bool _conSeguimiento = false;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asincrono = ref.watch(registrosProvider);
    final todos = asincrono.value ?? const <Registro>[];
    final hospitales = ref.watch(hospitalesProvider).value ?? const [];
    final uid = ref.watch(miUidProvider);
    final esAdmin = ref.watch(esAdminProvider);
    final buscado = sinAcentos(_texto.trim());

    final lista = todos.where((r) {
      if (_estado != null && r.estado != _estado) return false;
      if (_hospitalId != null && r.hospitalId != _hospitalId) return false;
      if (_soloMios && r.registradoPor != uid) return false;
      if (_conSeguimiento && !r.quiereSeguimiento) return false;
      if (buscado.isNotEmpty && !r.textoBuscable.contains(buscado)) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros'),
        actions: [
          if (esAdmin)
            IconButton(
              tooltip: 'Reporte en PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => abrir(context, const PantallaReportes()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'registrar-lista',
        tooltip: 'Registrar persona',
        onPressed: () => abrir(context, const PantallaFormulario()),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _buscar,
              onChanged: (v) => setState(() => _texto = v),
              decoration: InputDecoration(
                hintText: 'Buscar nombre, padecimiento, teléfono…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _texto.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _buscar.clear();
                          _texto = '';
                        }),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in Estado.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e.nombre),
                      selected: _estado == e,
                      onSelected: (s) => setState(() => _estado = s ? e : null),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Míos'),
                    selected: _soloMios,
                    onSelected: (s) => setState(() => _soloMios = s),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Con seguimiento'),
                    selected: _conSeguimiento,
                    onSelected: (s) => setState(() => _conSeguimiento = s),
                  ),
                ),
              ],
            ),
          ),
          if (hospitales.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final h in hospitales)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          Icons.local_hospital_rounded,
                          size: 16,
                          color: _hospitalId == h.id
                              ? Colores.blanco
                              : context.principal,
                        ),
                        label: Text(h.nombre),
                        selected: _hospitalId == h.id,
                        onSelected: (s) =>
                            setState(() => _hospitalId = s ? h.id : null),
                      ),
                    ),
                ],
              ),
            ),
          const AvisoSinSubir(),
          Expanded(
            child: asincrono.isLoading && todos.isEmpty
                ? const Cargando()
                : lista.isEmpty
                ? Vacio(
                    icono: Icons.assignment_rounded,
                    texto: todos.isEmpty
                        ? 'Todavía no hay registros.'
                        : 'Ningún registro coincide con la búsqueda.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                    itemCount: lista.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == lista.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            lista.length == todos.length
                                ? '${todos.length} en la lista actual'
                                : '${lista.length} de ${todos.length} en la '
                                      'lista actual',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colores.textoSuave,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      }
                      return TarjetaRegistro(lista[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Todo lo que se sabe de una persona y de su petición.
class PantallaRegistro extends ConsumerWidget {
  const PantallaRegistro(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(registroProvider(id));
    final r = asincrono.value;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: asincrono.isLoading
            ? const Cargando()
            : const Vacio(
                icono: Icons.search_off_rounded,
                texto: 'Este registro ya no existe.',
              ),
      );
    }
    final uid = ref.watch(miUidProvider);
    final esAdmin = ref.watch(esAdminProvider);
    final iglesiaId = ref.watch(iglesiaIdProvider)!;
    final repo = ref.read(repoProvider);
    final yaOre = r.oraron.containsKey(uid);
    final puedeBorrar = esAdmin || r.registradoPor == uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => abrir(context, PantallaFormulario(registro: r)),
          ),
          if (puedeBorrar)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await confirmar(
                  context,
                  titulo: 'Borrar registro',
                  texto:
                      'Se borrarán los datos de ${r.nombre}. Esto no se '
                      'puede deshacer.',
                  aceptar: 'Borrar',
                  peligroso: true,
                );
                if (!ok || !context.mounted) return;
                Navigator.pop(context);
                repo.borrarRegistro(iglesiaId, r.id).ignore();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Encabezado: por quién se ora.
          Card(
            color: suave(context.principal, .07),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FotoPersona(r.porQuienSeOra, null, radio: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.porQuienSeOra, style: titulo(22)),
                            const SizedBox(height: 4),
                            Text(
                              r.paraQuien == ParaQuien.familiar
                                  ? 'Familiar de ${r.nombre}'
                                        '${r.parentesco.isEmpty ? '' : ' (${r.parentesco})'}'
                                  : r.edad == null
                                  ? 'Oración por la persona'
                                  : '${r.edad} años',
                              style: const TextStyle(color: Colores.textoSuave),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChipEstado(r.estado),
                      _Etiqueta(Icons.local_hospital_rounded, r.hospitalNombre),
                      _Etiqueta(Icons.event_rounded, fechaCorta(r.fecha)),
                      if (r.quiereSeguimiento)
                        const _Etiqueta(
                          Icons.event_repeat_rounded,
                          'Quiere seguimiento',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Oré.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (yaOre)
                    OutlinedButton.icon(
                      onPressed: () => repo.marcarOre(
                        iglesiaId,
                        r.id,
                        false,
                        ref.read(miNombreProvider),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Ya oraste por esta petición'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colores.coral,
                      ),
                      onPressed: () => repo.marcarOre(
                        iglesiaId,
                        r.id,
                        true,
                        ref.read(miNombreProvider),
                      ),
                      icon: const Icon(Icons.front_hand_rounded),
                      label: const Text('Oré por esta petición'),
                    ),
                  if (r.oraron.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      r.oraron.length == 1
                          ? 'Ha orado: ${r.oraron.values.first}'
                          : '${r.oraron.length} personas han orado: '
                                '${r.oraron.values.join(', ')}',
                      style: const TextStyle(
                        color: Colores.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (r.peticion.isNotEmpty || r.padecimiento.isNotEmpty) ...[
            const TituloSeccion('Petición'),
            Card(
              child: Column(
                children: [
                  if (r.padecimiento.isNotEmpty)
                    _Dato(
                      Icons.healing_rounded,
                      'Padecimiento',
                      r.padecimiento,
                    ),
                  if (r.ubicacion.isNotEmpty)
                    _Dato(
                      Icons.bed_rounded,
                      'Área / cuarto / cama',
                      r.ubicacion,
                    ),
                  if (r.peticion.isNotEmpty)
                    _Dato(
                      Icons.format_quote_rounded,
                      'Pide oración por',
                      r.peticion,
                    ),
                ],
              ),
            ),
          ],
          const TituloSeccion('Contacto'),
          Card(
            child: Column(
              children: [
                _Dato(
                  Icons.person_rounded,
                  'Nombre completo',
                  r.nombre +
                      (r.edad != null && r.paraQuien == ParaQuien.familiar
                          ? ' · ${r.edad} años'
                          : ''),
                ),
                if (r.telefono.isNotEmpty)
                  _Dato(
                    Icons.phone_rounded,
                    'Teléfono',
                    r.telefono,
                    acciones: [
                      IconButton(
                        tooltip: 'Llamar',
                        icon: const Icon(Icons.call_rounded),
                        onPressed: () => llamar(r.telefono),
                      ),
                      IconButton(
                        tooltip: 'WhatsApp',
                        icon: const Icon(Icons.chat_rounded),
                        onPressed: () => whatsapp(
                          r.telefono,
                          texto:
                              'Hola ${r.nombre.split(' ').first}, te saludamos '
                              'de ${ref.read(iglesiaProvider).value?.nombre ?? 'la iglesia'}. '
                              'Seguimos orando por ${r.porQuienSeOra}.',
                        ),
                      ),
                    ],
                  ),
                if (r.domicilio.isNotEmpty)
                  _Dato(
                    Icons.home_rounded,
                    'Domicilio',
                    r.domicilio,
                    acciones: [
                      IconButton(
                        tooltip: 'Ver en el mapa',
                        icon: const Icon(Icons.map_rounded),
                        onPressed: () => abrirMapa(r.domicilio),
                      ),
                    ],
                  ),
                if (r.notas.isNotEmpty)
                  _Dato(Icons.sticky_note_2_rounded, 'Notas', r.notas),
              ],
            ),
          ),
          const TituloSeccion('Seguimiento'),
          SegmentedButton<Estado>(
            showSelectedIcon: false,
            segments: [
              for (final e in Estado.values)
                ButtonSegment(
                  value: e,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(e.nombre, maxLines: 1),
                  ),
                ),
            ],
            selected: {r.estado},
            onSelectionChanged: (s) async {
              final e = s.first;
              if (e == Estado.respondida) {
                final t = await _pedirTestimonio(context, r.testimonio);
                if (t == null) return;
                repo.cambiarEstado(iglesiaId, r.id, e, testimonio: t);
              } else {
                repo.cambiarEstado(iglesiaId, r.id, e);
              }
            },
          ),
          if (r.testimonio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Colores.ok.withValues(alpha: .08),
              child: _Dato(
                Icons.favorite_rounded,
                'Testimonio',
                r.testimonio,
                color: Colores.ok,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Registró ${r.registradoPorNombre.isEmpty ? 'alguien' : r.registradoPorNombre}'
                '${r.creadoEn == null ? '' : ' el ${fechaCorta(r.creadoEn!)} a las ${hora(r.creadoEn!)}'}'
                '${r.pendienteDeSubir ? ' · guardado en el teléfono, falta subirlo' : ''}'
                '${r.consentimiento ? ' · con permiso de la persona' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colores.textoSuave,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _pedirTestimonio(BuildContext context, String actual) {
  final c = TextEditingController(text: actual);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('¡Gloria a Dios!'),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: '¿Cómo respondió Dios? (opcional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, c.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colores.blanco,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colores.borde),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: context.principal),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato(
    this.icono,
    this.etiqueta,
    this.valor, {
    this.acciones = const [],
    this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final List<Widget> acciones;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icono, size: 20, color: color ?? context.principal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colores.textoSuave,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(valor, style: const TextStyle(fontSize: 15.5)),
            ],
          ),
        ),
        ...acciones,
      ],
    ),
  );
}
