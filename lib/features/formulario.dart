import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'hospitales.dart';

/// Captura (o edición) de los datos de una persona. Funciona sin señal: se
/// guarda en el teléfono y se sube sola al tener internet.
class PantallaFormulario extends ConsumerStatefulWidget {
  const PantallaFormulario({super.key, this.registro, this.hospital});

  /// Si se da, se edita este registro.
  final Registro? registro;

  /// Hospital propuesto para un registro nuevo.
  final Hospital? hospital;

  @override
  ConsumerState<PantallaFormulario> createState() => _PantallaFormularioState();
}

class _PantallaFormularioState extends ConsumerState<PantallaFormulario> {
  final _form = GlobalKey<FormState>();
  final _desplazar = ScrollController();
  late final Registro? _r = widget.registro;

  late final _nombre = TextEditingController(text: _r?.nombre);
  late final _edad = TextEditingController(text: _r?.edad?.toString());
  late final _telefono = TextEditingController(text: _r?.telefono);
  late final _domicilio = TextEditingController(text: _r?.domicilio);
  late final _familiar = TextEditingController(text: _r?.familiarNombre);
  late final _parentesco = TextEditingController(text: _r?.parentesco);
  late final _padecimiento = TextEditingController(text: _r?.padecimiento);
  late final _ubicacion = TextEditingController(text: _r?.ubicacion);
  late final _peticion = TextEditingController(text: _r?.peticion);
  late final _notas = TextEditingController(text: _r?.notas);

  late ParaQuien _paraQuien = _r?.paraQuien ?? ParaQuien.persona;
  late bool _seguimiento = _r?.quiereSeguimiento ?? false;
  late bool _consentimiento = _r?.consentimiento ?? false;
  late DateTime _fecha = _r?.fecha ?? DateTime.now();
  late String? _hospitalId =
      _r?.hospitalId ?? widget.hospital?.id ?? ultimoHospitalId;
  int _guardados = 0;

  bool get _editando => _r != null;

  @override
  void dispose() {
    _desplazar.dispose();
    for (final c in [
      _nombre,
      _edad,
      _telefono,
      _domicilio,
      _familiar,
      _parentesco,
      _padecimiento,
      _ubicacion,
      _peticion,
      _notas,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _fecha = d);
  }

  /// Guarda y, si [otra], deja el formulario listo para la siguiente persona.
  void _guardar({required bool otra}) {
    if (!_form.currentState!.validate()) {
      avisar(context, 'Revisa los datos marcados en rojo.');
      return;
    }
    if (!_consentimiento) {
      avisar(context, 'Confirma que la persona aceptó compartir sus datos.');
      return;
    }
    final hospitales = ref.read(hospitalesProvider).value ?? const [];
    final hospital = hospitales.where((h) => h.id == _hospitalId).firstOrNull;
    if (hospital == null) {
      avisar(context, 'Elige el hospital.');
      return;
    }
    final repo = ref.read(repoProvider);
    final iglesiaId = ref.read(iglesiaIdProvider)!;
    final miNombre = ref.read(miNombreProvider);
    recordarHospital(hospital.id);

    final registro = Registro(
      id: _r?.id ?? '',
      fecha: DateTime(_fecha.year, _fecha.month, _fecha.day, 12),
      hospitalId: hospital.id,
      hospitalNombre: hospital.nombre,
      nombre: _nombre.text,
      edad: int.tryParse(_edad.text.trim()),
      telefono: _telefono.text,
      domicilio: _domicilio.text,
      paraQuien: _paraQuien,
      familiarNombre: _familiar.text,
      parentesco: _parentesco.text,
      padecimiento: _padecimiento.text,
      ubicacion: _ubicacion.text,
      peticion: _peticion.text,
      notas: _notas.text,
      quiereSeguimiento: _seguimiento,
      consentimiento: _consentimiento,
    );
    repo.guardarRegistro(iglesiaId, registro, miNombre);
    HapticFeedback.mediumImpact();

    if (!otra) {
      avisar(
        context,
        _editando
            ? 'Cambios guardados.'
            : 'Registro guardado. Dios le bendiga.',
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _guardados++;
      for (final c in [
        _nombre,
        _edad,
        _telefono,
        _domicilio,
        _familiar,
        _parentesco,
        _padecimiento,
        _ubicacion,
        _peticion,
        _notas,
      ]) {
        c.clear();
      }
      _paraQuien = ParaQuien.persona;
      _seguimiento = false;
      _consentimiento = false;
    });
    _form.currentState!.reset();
    _desplazar.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    avisar(context, 'Guardado. Registra a la siguiente persona.');
  }

  String? _requerido(String? v) =>
      (v ?? '').trim().isEmpty ? 'Este dato hace falta' : null;

  @override
  Widget build(BuildContext context) {
    final hospitales = ref.watch(hospitalesActivosProvider);
    final todos = ref.watch(hospitalesProvider).value ?? const [];
    // Un registro viejo puede ser de un hospital ya desactivado.
    final opciones = [
      ...hospitales,
      ...todos.where((h) => !h.activo && h.id == _hospitalId),
    ];
    final esAdmin = ref.watch(esAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar registro' : 'Registrar persona'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          controller: _desplazar,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (_guardados > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _guardados == 1
                      ? '1 persona registrada en esta tanda'
                      : '$_guardados personas registradas en esta tanda',
                  style: TextStyle(
                    color: context.principal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            // ----------------------------------------------- Dónde y cuándo
            _Bloque(
              icono: Icons.local_hospital_rounded,
              titulo: 'Dónde y cuándo',
              children: [
                if (opciones.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        esAdmin
                            ? 'Primero agrega los hospitales que visitan.'
                            : 'Tu iglesia aún no tiene hospitales. Pide a un '
                                  'administrador que los agregue.',
                      ),
                      if (esAdmin) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => editarHospital(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar hospital'),
                        ),
                      ],
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: opciones.any((h) => h.id == _hospitalId)
                        ? _hospitalId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hospital',
                      prefixIcon: Icon(Icons.local_hospital_rounded),
                    ),
                    items: [
                      for (final h in opciones)
                        DropdownMenuItem(value: h.id, child: Text(h.nombre)),
                    ],
                    onChanged: (v) => setState(() => _hospitalId = v),
                    validator: (v) => v == null ? 'Elige el hospital' : null,
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _elegirFecha,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    child: Text(fechaLarga(_fecha)),
                  ),
                ),
              ],
            ),
            // ----------------------------------------------------- Persona
            _Bloque(
              icono: Icons.person_rounded,
              titulo: 'Persona con la que hablaron',
              children: [
                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                  ),
                  validator: _requerido,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: _edad,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(labelText: 'Edad'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9 +\-()]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        validator: (v) {
                          final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (d.isEmpty) return null;
                          return d.length < 8 ? 'Número incompleto' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _domicilio,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Domicilio',
                    helperText: 'Calle, número, colonia, ciudad',
                    prefixIcon: Icon(Icons.home_rounded),
                  ),
                ),
              ],
            ),
            // -------------------------------------------- Por quién se ora
            _Bloque(
              icono: Icons.front_hand_rounded,
              titulo: '¿Por quién oramos?',
              children: [
                SegmentedButton<ParaQuien>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ParaQuien.persona,
                      icon: Icon(Icons.person_rounded),
                      label: Text('Por la persona'),
                    ),
                    ButtonSegment(
                      value: ParaQuien.familiar,
                      icon: Icon(Icons.family_restroom_rounded),
                      label: Text('Por un familiar'),
                    ),
                  ],
                  selected: {_paraQuien},
                  onSelectionChanged: (s) =>
                      setState(() => _paraQuien = s.first),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _paraQuien == ParaQuien.familiar
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _familiar,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre del familiar *',
                                  helperText: 'Quien está internado o enfermo',
                                ),
                                validator: (v) =>
                                    _paraQuien == ParaQuien.familiar
                                    ? _requerido(v)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _parentesco,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Parentesco',
                                  hintText: 'Mamá, esposo, hijo…',
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _padecimiento,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _paraQuien == ParaQuien.familiar
                        ? '¿De qué padece el familiar?'
                        : '¿De qué padece?',
                    prefixIcon: const Icon(Icons.healing_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ubicacion,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Área, piso, cuarto o cama',
                    prefixIcon: Icon(Icons.bed_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _peticion,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Petición de oración',
                    hintText: 'Lo que la persona pidió que oremos',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            // ------------------------------------------------------- Otros
            _Bloque(
              icono: Icons.more_horiz_rounded,
              titulo: 'Más',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _seguimiento,
                  onChanged: (v) => setState(() => _seguimiento = v),
                  title: const Text(
                    'Quiere que le volvamos a visitar o llamar',
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notas,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    hintText: 'Se le regaló café y pan, aceptó a Cristo…',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consentimiento,
                  onChanged: (v) =>
                      setState(() => _consentimiento = v ?? false),
                  title: const Text(
                    'La persona aceptó que guardemos estos datos para orar '
                    'por ella y darle seguimiento *',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _guardar(otra: false),
              icon: const Icon(Icons.check_rounded),
              label: Text(_editando ? 'Guardar cambios' : 'Guardar'),
            ),
            if (!_editando) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _guardar(otra: true),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Guardar y registrar otra'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sección del formulario con su título.
class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.icono,
    required this.titulo,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: context.principal),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Último hospital en el que registró este teléfono: se propone en el
/// siguiente registro.
String? ultimoHospitalId;

Future<void> cargarUltimoHospital() async {
  try {
    ultimoHospitalId = (await SharedPreferences.getInstance()).getString(
      'ultimoHospital',
    );
  } catch (_) {}
}

void recordarHospital(String id) {
  ultimoHospitalId = id;
  SharedPreferences.getInstance()
      .then((p) => p.setString('ultimoHospital', id))
      .ignore();
}
