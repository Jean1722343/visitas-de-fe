import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/exportar.dart';
import '../services/proveedores.dart';
import '../services/reporte_pdf.dart';
import '../widgets/comunes.dart';

/// Reportes del administrador. La lista nueva trae todo lo que no ha salido
/// en una lista anterior; al archivarla, esos registros ya no cuentan para
/// la siguiente.
class PantallaReportes extends ConsumerWidget {
  const PantallaReportes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cortes = ref.watch(cortesProvider).value ?? const [];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listas de oración'),
          bottom: TabBar(
            indicatorColor: Colores.blanco,
            indicatorWeight: 3,
            labelColor: Colores.blanco,
            unselectedLabelColor: Colores.blanco.withValues(alpha: .7),
            labelStyle: const TextStyle(
              fontFamily: Fuentes.texto,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            tabs: [
              const Tab(text: 'Lista nueva'),
              Tab(
                text: cortes.isEmpty
                    ? 'Archivadas'
                    : 'Archivadas (${cortes.length})',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [_ListaNueva(), _Archivadas()],
        ),
      ),
    );
  }
}

/// Lo que todavía no sale en ninguna lista.
class _ListaNueva extends ConsumerStatefulWidget {
  const _ListaNueva();
  @override
  ConsumerState<_ListaNueva> createState() => _ListaNuevaState();
}

class _ListaNuevaState extends ConsumerState<_ListaNueva> {
  String? _hospitalId;
  bool _archivando = false;

  Future<void> _archivar(List<Registro> lista, Hospital? hospital) async {
    final pendientes = lista.where((r) => r.pendienteDeSubir).length;
    final ok = await confirmar(
      context,
      titulo: 'Archivar ${lista.length} registros',
      texto:
          'Esta lista queda guardada en «Archivadas» y estos registros ya no '
          'salen en la siguiente lista ni en la pestaña Registros. '
          'Primero comparte o imprime el PDF.'
          '${pendientes > 0 ? '\n\nOjo: $pendientes aún no se suben desde algún teléfono.' : ''}',
      aceptar: 'Archivar',
    );
    if (!ok || !mounted) return;
    setState(() => _archivando = true);
    final hecho = await intentar(
      context,
      () => ref
          .read(repoProvider)
          .archivar(
            ref.read(iglesiaIdProvider)!,
            lista,
            miNombre: ref.read(miNombreProvider),
            hospitalNombre: hospital?.nombre ?? '',
          ),
    );
    if (!mounted) return;
    setState(() => _archivando = false);
    if (hecho) {
      avisar(context, 'Lista archivada. La siguiente empieza en cero.');
      DefaultTabController.of(context).animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(registrosProvider).value ?? const <Registro>[];
    final hospitales = ref.watch(hospitalesProvider).value ?? const [];
    final iglesia = ref.watch(iglesiaProvider).value;
    final hospital = hospitales.where((h) => h.id == _hospitalId).firstOrNull;
    final filtro = FiltroReporte(titulo: 'Lista actual', hospital: hospital);
    final lista = filtro.aplicar(todos);

    return Column(
      children: [
        Container(
          color: Colores.blanco,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _hospitalId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hospital',
                    isDense: true,
                    prefixIcon: Icon(Icons.local_hospital_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final h in hospitales)
                      DropdownMenuItem(value: h.id, child: Text(h.nombre)),
                  ],
                  onChanged: (v) => setState(() => _hospitalId = v),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Bajar en Excel',
                icon: const Icon(Icons.table_view_rounded),
                onPressed: lista.isEmpty
                    ? null
                    : () => intentar(
                        context,
                        () => compartirExcel(
                          iglesia: iglesia?.nombre ?? '',
                          desde: lista.first.fecha,
                          hasta: lista.last.fecha,
                          registros: lista,
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: iglesia == null
              ? const Cargando()
              : lista.isEmpty
              ? const Vacio(
                  icono: Icons.inventory_2_rounded,
                  texto:
                      'No hay registros nuevos.\nLos que se registren a partir '
                      'de ahora saldrán en la siguiente lista.',
                )
              : _VistaPdf(iglesia: iglesia, filtro: filtro, registros: lista),
        ),
        if (lista.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              color: Colores.blanco,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colores.coral),
                onPressed: _archivando
                    ? null
                    : () => _archivar(lista, hospital),
                icon: const Icon(Icons.inventory_2_rounded),
                label: Text(
                  _archivando
                      ? 'Archivando…'
                      : 'Archivar estos ${lista.length} registros',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Listas ya archivadas.
class _Archivadas extends ConsumerWidget {
  const _Archivadas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cortes = ref.watch(cortesProvider);
    final lista = cortes.value ?? const <Corte>[];
    if (cortes.isLoading && lista.isEmpty) return const Cargando();
    if (lista.isEmpty) {
      return const Vacio(
        icono: Icons.inventory_2_rounded,
        texto:
            'Aún no hay listas archivadas. Cuando archives la lista nueva, '
            'aparecerá aquí para volver a descargarla.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = lista[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: suave(context.principal, .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: context.principal,
              ),
            ),
            title: Text(
              'Lista del ${fechaCorta(c.fecha)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              [
                '${c.total} ${c.total == 1 ? 'registro' : 'registros'}',
                if (c.hospitalNombre.isNotEmpty) c.hospitalNombre,
                'por ${c.hechoPorNombre}',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => abrir(context, _PantallaCorte(c)),
          ),
        );
      },
    );
  }
}

class _PantallaCorte extends ConsumerWidget {
  const _PantallaCorte(this.corte);
  final Corte corte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(
      registrosDondeProvider((campo: 'corteId', valor: corte.id)),
    );
    final registros = asincrono.value ?? const <Registro>[];
    final iglesia = ref.watch(iglesiaProvider).value;
    final filtro = FiltroReporte(
      titulo: 'Lista del ${fechaCorta(corte.fecha)}',
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista del ${fechaCorta(corte.fecha)}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) async {
              final ok = await confirmar(
                context,
                titulo: 'Regresar a la lista nueva',
                texto:
                    'Estos ${corte.total} registros vuelven a la lista nueva '
                    'y esta lista archivada se quita.',
                aceptar: 'Regresar',
              );
              if (!ok || !context.mounted) return;
              final hecho = await intentar(
                context,
                () => ref
                    .read(repoProvider)
                    .desarchivar(ref.read(iglesiaIdProvider)!, corte.id),
              );
              if (hecho && context.mounted) Navigator.pop(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'deshacer',
                child: Text('Deshacer: regresar a la lista nueva'),
              ),
            ],
          ),
        ],
      ),
      body: iglesia == null || (asincrono.isLoading && registros.isEmpty)
          ? const Cargando()
          : _VistaPdf(
              iglesia: iglesia,
              filtro: filtro,
              registros: filtro.aplicar(registros),
            ),
    );
  }
}

/// Vista previa del PDF con botones para imprimir y compartir.
class _VistaPdf extends StatelessWidget {
  const _VistaPdf({
    required this.iglesia,
    required this.filtro,
    required this.registros,
  });

  final Iglesia iglesia;
  final FiltroReporte filtro;
  final List<Registro> registros;

  @override
  Widget build(BuildContext context) => PdfPreview(
    key: ValueKey(
      Object.hash(filtro.titulo, filtro.hospital?.id, registros.length),
    ),
    build: (_) => generarReportePdf(
      iglesia: iglesia,
      filtro: filtro,
      registros: registros,
    ),
    pdfFileName: '${filtro.titulo} ${iglesia.nombre}.pdf'
        .replaceAll(RegExp(r'[^\w\-. ]'), '')
        .replaceAll(' ', '_'),
    canChangePageFormat: false,
    canChangeOrientation: false,
    canDebug: false,
    scrollViewDecoration: const BoxDecoration(color: Colores.fondo),
    actionBarTheme: PdfActionBarTheme(
      backgroundColor: context.principal,
      iconColor: Colores.blanco,
    ),
    loadingWidget: const Cargando(),
  );
}
