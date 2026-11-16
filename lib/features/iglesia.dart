import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/actualizacion.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';
import 'actualizar.dart';
import 'perfil.dart';
import 'registros.dart';
import 'reportes.dart';
import 'sin_iglesia.dart';

class PantallaIglesia extends ConsumerWidget {
  const PantallaIglesia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iglesia = ref.watch(iglesiaProvider).value;
    final yo = ref.watch(yoProvider).value;
    final esAdmin = ref.watch(esAdminProvider);
    final miembros = ref.watch(miembrosProvider).value ?? const <Miembro>[];
    final registros = ref.watch(registrosProvider).value ?? const [];
    final perfil = ref.watch(perfilProvider).value;
    final version = ref.watch(versionInstaladaProvider).value ?? '';
    final uid = ref.watch(miUidProvider);
    if (iglesia == null) return const Scaffold(body: Cargando());

    return Scaffold(
      appBar: AppBar(title: const Text('Iglesia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Tarjeta de la iglesia.
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: context.principal,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          LogoIglesia(iglesia, lado: 64),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  iglesia.nombre,
                                  style: titulo(21, color: Colores.blanco),
                                ),
                                if (iglesia.ciudad.isNotEmpty)
                                  Text(
                                    iglesia.ciudad,
                                    style: TextStyle(
                                      color: Colores.blanco.withValues(
                                        alpha: .8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      LineaDeVida(
                        alto: 30,
                        grosor: 2,
                        animar: false,
                        color: Colores.blanco.withValues(alpha: .4),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _Mini('${miembros.length}', 'miembros'),
                      _Mini(
                        '${ref.watch(hospitalesActivosProvider).length}',
                        'hospitales',
                      ),
                      _Mini('${registros.length}', 'registros'),
                    ],
                  ),
                ),
                if (esAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          abrir(context, PantallaEditarIglesia(iglesia)),
                      icon: const Icon(Icons.palette_rounded),
                      label: const Text('Personalizar iglesia'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: FotoPersona(yo?.nombre ?? '', yo?.foto),
                  title: Text(
                    yo?.nombre ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(yo?.rol.nombre ?? ''),
                  trailing: const Icon(Icons.edit_rounded),
                  onTap: () => abrir(context, const PantallaMiPerfil()),
                ),
                const Divider(indent: 16, endIndent: 16),
                if (esAdmin)
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded),
                    title: const Text('Reportes en PDF'),
                    subtitle: const Text('Todos los registros en tablas'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => abrir(context, const PantallaReportes()),
                  ),
              ],
            ),
          ),
          TituloSeccion(
            'Miembros',
            accion: TextButton.icon(
              onPressed: () => _invitar(context, ref),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Invitar'),
            ),
          ),
          const _Codigos(),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final m in miembros)
                  ListTile(
                    enabled: true,
                    leading: Opacity(
                      opacity: m.activo ? 1 : .45,
                      child: FotoPersona(m.nombre, m.foto),
                    ),
                    title: Text(
                      m.nombre + (m.uid == uid ? ' (tú)' : ''),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: m.activo ? null : Colores.textoApagado,
                      ),
                    ),
                    subtitle: Text(
                      [
                        m.activo ? m.rol.nombre : 'Sin acceso',
                        '${registros.where((r) => r.registradoPor == m.uid).length} registros',
                      ].join(' · '),
                    ),
                    trailing: m.esAdmin
                        ? Icon(iconoRol(m.rol), color: context.principal)
                        : null,
                    onTap: () => abrir(context, PantallaMiembro(m.uid)),
                  ),
              ],
            ),
          ),
          const TituloSeccion('Cuenta'),
          Card(
            child: Column(
              children: [
                if ((perfil?.iglesias.length ?? 0) > 1)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('Cambiar de iglesia'),
                    onTap: () => _cambiarIglesia(context, ref),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_home_work_rounded),
                  title: const Text('Unirme o registrar otra iglesia'),
                  onTap: () => _otraIglesia(context),
                ),
                ListTile(
                  leading: const Icon(Icons.system_update_rounded),
                  title: const Text('Buscar actualizaciones'),
                  subtitle: Text('Versión $version'),
                  onTap: () => buscarAMano(context, ref),
                ),
                if (!esAdmin || miembros.where((m) => m.esAdmin).length > 1)
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Salir de esta iglesia'),
                    onTap: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Salir de ${iglesia.nombre}',
                        texto:
                            'Dejarás de ver sus registros. Para volver '
                            'necesitarás un código nuevo.',
                        aceptar: 'Salir',
                        peligroso: true,
                      );
                      if (ok && context.mounted) {
                        intentar(
                          context,
                          () => ref
                              .read(repoProvider)
                              .abandonarIglesia(iglesia.id),
                        );
                      }
                    },
                  ),
                if (esAdmin && iglesia.creadoPor == uid)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colores.rojo,
                    ),
                    title: const Text(
                      'Borrar la iglesia',
                      style: TextStyle(color: Colores.rojo),
                    ),
                    onTap: () => _borrarIglesia(context, ref, iglesia),
                  ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new_rounded),
                  title: const Text('Cerrar sesión'),
                  onTap: () => ref.read(repoProvider).salir(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(valor, style: titulo(20)),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 11.5, color: Colores.textoSuave),
        ),
      ],
    ),
  );
}

/// Códigos de invitación vigentes.
class _Codigos extends ConsumerWidget {
  const _Codigos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codigos = ref.watch(invitacionesProvider).value ?? const [];
    if (codigos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colores.coralSuave,
        child: Column(
          children: [
            for (final c in codigos)
              ListTile(
                leading: const Icon(Icons.key_rounded, color: Colores.coral),
                title: Text(
                  c.codigo,
                  style: titulo(20).copyWith(letterSpacing: 4),
                ),
                subtitle: Text(
                  'Para ${c.rol == Rol.admin ? 'administrador' : 'servidor'} · '
                  'vence ${fechaCorta(c.expiraEn)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Compartir',
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => _compartirCodigo(ref, c.codigo),
                    ),
                    IconButton(
                      tooltip: 'Anular',
                      icon: const Icon(Icons.block_rounded),
                      onPressed: () => intentar(
                        context,
                        () => ref.read(repoProvider).anularInvitacion(c.codigo),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _compartirCodigo(WidgetRef ref, String codigo) {
  final nombre = ref.read(iglesiaProvider).value?.nombre ?? 'la iglesia';
  SharePlus.instance.share(
    ShareParams(
      text:
          'Te invito a la app de visitas a hospitales de $nombre.\n\n'
          '1. Instala «Visitas de Fe»: https://github.com/$repositorio/releases/latest\n'
          '2. Inicia sesión y toca «Tengo un código».\n'
          '3. Escribe este código: $codigo',
    ),
  );
}

/// Crea un código. Los servidores invitan servidores; solo un administrador
/// puede invitar a otro administrador.
Future<void> _invitar(BuildContext context, WidgetRef ref) async {
  final esAdmin = ref.read(esAdminProvider);
  final rol = !esAdmin
      ? Rol.miembro
      : await showModalBottomSheet<Rol>(
          context: context,
          builder: (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '¿A quién invitas?',
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                ),
                ListTile(
                  leading: Icon(iconoRol(Rol.miembro)),
                  title: const Text('Servidor'),
                  subtitle: const Text(
                    'Registra a las personas por las que hay que orar.',
                  ),
                  onTap: () => Navigator.pop(c, Rol.miembro),
                ),
                ListTile(
                  leading: Icon(iconoRol(Rol.admin)),
                  title: const Text('Administrador'),
                  subtitle: const Text(
                    'Además da de alta hospitales, administra miembros y '
                    'personaliza la iglesia.',
                  ),
                  onTap: () => Navigator.pop(c, Rol.admin),
                ),
              ],
            ),
          ),
        );
  if (rol == null || !context.mounted) return;
  String? codigo;
  final ok = await intentar(context, () async {
    codigo = await ref
        .read(repoProvider)
        .crearInvitacion(ref.read(iglesiaIdProvider)!, rol);
  });
  if (!ok || codigo == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Código de invitación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Compártelo con la persona. Vale 7 días y entra como '
            '${rol == Rol.admin ? 'administrador' : 'servidor'}.',
          ),
          const SizedBox(height: 18),
          SelectableText(
            codigo!,
            style: titulo(
              40,
              color: context.principal,
            ).copyWith(letterSpacing: 8),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cerrar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(c);
            _compartirCodigo(ref, codigo!);
          },
          child: const Text('Compartir'),
        ),
      ],
    ),
  );
}

Future<void> _cambiarIglesia(BuildContext context, WidgetRef ref) async {
  final ids = ref.read(perfilProvider).value?.iglesias ?? const [];
  final actual = ref.read(iglesiaIdProvider);
  final id = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Consumer(
        builder: (c, ref, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in ids)
              Builder(
                builder: (c) {
                  final i = ref.watch(iglesiaPorIdProvider(id)).value;
                  return ListTile(
                    leading: LogoIglesia(i, lado: 40),
                    title: Text(i?.nombre ?? 'Cargando…'),
                    trailing: id == actual
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(c, id),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
  if (id != null && id != actual && context.mounted) {
    intentar(context, () => ref.read(repoProvider).cambiarIglesia(id));
  }
}

void _otraIglesia(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  builder: (c) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.key_rounded),
          title: const Text('Tengo un código'),
          onTap: () {
            Navigator.pop(c);
            abrir(context, const PantallaCodigo());
          },
        ),
        ListTile(
          leading: const Icon(Icons.church_rounded),
          title: const Text('Registrar otra iglesia'),
          onTap: () {
            Navigator.pop(c);
            abrir(context, const PantallaCrearIglesia());
          },
        ),
      ],
    ),
  ),
);

Future<void> _borrarIglesia(
  BuildContext context,
  WidgetRef ref,
  Iglesia iglesia,
) async {
  final ok = await confirmar(
    context,
    titulo: 'Borrar ${iglesia.nombre}',
    texto:
        'Se borrarán para siempre todos sus hospitales, visitas, registros '
        'y miembros. Esto no se puede deshacer.',
    aceptar: 'Borrar todo',
    peligroso: true,
  );
  if (!ok || !context.mounted) return;
  final seguro = await confirmar(
    context,
    titulo: '¿Seguro?',
    texto: 'Última confirmación: se pierde toda la información.',
    aceptar: 'Sí, borrar',
    peligroso: true,
  );
  if (!seguro || !context.mounted) return;
  intentar(context, () => ref.read(repoProvider).borrarIglesia(iglesia.id));
}

/// Un miembro: lo que ha registrado y a qué visitas fue. El administrador
/// cambia aquí su rol o su acceso.
class PantallaMiembro extends ConsumerWidget {
  const PantallaMiembro(this.uid, {super.key});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miembros = ref.watch(miembrosProvider).value ?? const <Miembro>[];
    final m = miembros.where((m) => m.uid == uid).firstOrNull;
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vacio(
          icono: Icons.person_off_rounded,
          texto: 'Esta persona ya no es miembro.',
        ),
      );
    }
    final esAdmin = ref.watch(esAdminProvider);
    final yo = ref.watch(miUidProvider);
    final iglesiaId = ref.watch(iglesiaIdProvider)!;
    final repo = ref.read(repoProvider);
    final admins = miembros.where((m) => m.esAdmin && m.activo).length;
    final registros =
        ref
            .watch(registrosDondeProvider((campo: 'registradoPor', valor: uid)))
            .value ??
        const [];
    // Que nunca se quede la iglesia sin administrador.
    final unicoAdmin = m.esAdmin && admins <= 1;

    return Scaffold(
      appBar: AppBar(title: Text(m.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Center(child: FotoPersona(m.nombre, m.foto, radio: 48)),
          const SizedBox(height: 12),
          Center(child: Text(m.nombre, style: titulo(24))),
          Center(
            child: Text(
              [
                m.activo ? m.rol.nombre : 'Sin acceso',
                if (m.desde != null) 'desde ${fechaCorta(m.desde!)}',
              ].join(' · '),
              style: const TextStyle(color: Colores.textoSuave),
            ),
          ),
          const SizedBox(height: 16),
          Cifra(
            valor: '${registros.length}',
            etiqueta: 'Personas registradas',
            icono: Icons.assignment_ind_rounded,
          ),
          if (esAdmin && m.uid != yo) ...[
            const TituloSeccion('Administrar'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(iconoRol(Rol.admin)),
                    title: const Text('Administrador'),
                    subtitle: const Text(
                      'Puede dar de alta hospitales, administrar miembros y '
                      'personalizar la iglesia.',
                    ),
                    value: m.esAdmin,
                    onChanged: unicoAdmin
                        ? null
                        : (v) => intentar(
                            context,
                            () => repo.cambiarMiembro(
                              iglesiaId,
                              m.uid,
                              rol: v ? Rol.admin : Rol.miembro,
                            ),
                          ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_open_rounded),
                    title: const Text('Tiene acceso'),
                    subtitle: const Text(
                      'Si lo apagas, ya no podrá abrir la iglesia.',
                    ),
                    value: m.activo,
                    onChanged: unicoAdmin
                        ? null
                        : (v) => intentar(
                            context,
                            () => repo.cambiarMiembro(
                              iglesiaId,
                              m.uid,
                              activo: v,
                            ),
                          ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.person_remove_rounded,
                      color: Colores.rojo,
                    ),
                    title: const Text(
                      'Quitar de la iglesia',
                      style: TextStyle(color: Colores.rojo),
                    ),
                    enabled: !unicoAdmin,
                    onTap: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Quitar a ${m.nombre}',
                        texto:
                            'Sus registros se conservan. Para volver '
                            'necesitará un código nuevo.',
                        aceptar: 'Quitar',
                        peligroso: true,
                      );
                      if (!ok || !context.mounted) return;
                      final hecho = await intentar(
                        context,
                        () => repo.quitarMiembro(iglesiaId, m.uid),
                      );
                      if (hecho && context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
          const TituloSeccion('Registró'),
          if (registros.isEmpty)
            const Text(
              'Todavía no ha registrado a nadie.',
              style: TextStyle(color: Colores.textoSuave),
            ),
          for (final r in registros)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRegistro(r),
            ),
        ],
      ),
    );
  }
}

/// El administrador cambia nombre, logo, color y lema de la iglesia.
class PantallaEditarIglesia extends ConsumerStatefulWidget {
  const PantallaEditarIglesia(this.iglesia, {super.key});
  final Iglesia iglesia;
  @override
  ConsumerState<PantallaEditarIglesia> createState() =>
      _PantallaEditarIglesiaState();
}

class _PantallaEditarIglesiaState extends ConsumerState<PantallaEditarIglesia> {
  late final _nombre = TextEditingController(text: widget.iglesia.nombre);
  late final _ciudad = TextEditingController(text: widget.iglesia.ciudad);
  late final _lema = TextEditingController(text: widget.iglesia.lema);
  late int _color = widget.iglesia.color;
  late Uint8List? _logo = widget.iglesia.logo;
  bool _logoCambiado = false;

  @override
  void dispose() {
    _nombre.dispose();
    _ciudad.dispose();
    _lema.dispose();
    super.dispose();
  }

  Future<void> _elegirLogo() async {
    final f = await elegirFoto(context);
    if (f == null) return;
    final logo = await prepararLogo(f);
    if (mounted) {
      setState(() {
        _logo = logo;
        _logoCambiado = true;
      });
    }
  }

  void _guardar() {
    if (_nombre.text.trim().isEmpty) {
      avisar(context, 'Escribe el nombre de la iglesia.');
      return;
    }
    ref
        .read(repoProvider)
        .editarIglesia(
          widget.iglesia.id,
          nombre: _nombre.text,
          ciudad: _ciudad.text,
          lema: _lema.text,
          color: _color,
          logo: _logoCambiado ? _logo : null,
          quitarLogo: _logoCambiado && _logo == null,
        );
    avisar(context, 'Iglesia actualizada.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: temaPara(Color(_color)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Personalizar iglesia')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            EditorLogo(
              logo: _logo,
              color: _color,
              alElegir: _elegirLogo,
              alQuitar: () => setState(() {
                _logo = null;
                _logoCambiado = true;
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre de la iglesia',
                prefixIcon: Icon(Icons.church_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ciudad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                prefixIcon: Icon(Icons.location_city_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
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
            const SizedBox(height: 28),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ],
        ),
      ),
    ),
  );
}
