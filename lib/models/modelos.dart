import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

DateTime? _fecha(dynamic v) => v is Timestamp ? v.toDate() : null;
Uint8List? _bytes(dynamic v) => v is Blob ? v.bytes : null;
String _texto(dynamic v) => v is String ? v : '';

enum Rol {
  admin('admin', 'Administrador'),
  miembro('miembro', 'Servidor');

  const Rol(this.id, this.nombre);
  final String id;
  final String nombre;

  static Rol desdeId(String? id) => id == 'admin' ? Rol.admin : Rol.miembro;
}

/// Una iglesia: su nombre, su logo y su color. Cada iglesia tiene sus
/// propios miembros, hospitales, visitas y registros.
class Iglesia {
  const Iglesia({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.lema,
    required this.color,
    required this.creadoPor,
    this.logo,
  });

  final String id;
  final String nombre;
  final String ciudad;

  /// Versículo o frase que aparece en el inicio.
  final String lema;

  /// Color principal elegido (ARGB).
  final int color;
  final String creadoPor;
  final Uint8List? logo;

  factory Iglesia.desde(Doc d) {
    final m = d.data() ?? {};
    return Iglesia(
      id: d.id,
      nombre: _texto(m['nombre']),
      ciudad: _texto(m['ciudad']),
      lema: _texto(m['lema']),
      color: (m['color'] as num?)?.toInt() ?? 0xFF0F6E64,
      creadoPor: _texto(m['creadoPor']),
      logo: _bytes(m['logo']),
    );
  }
}

class Miembro {
  const Miembro({
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.activo,
    this.foto,
    this.desde,
  });

  final String uid;
  final String nombre;
  final Rol rol;
  final bool activo;
  final Uint8List? foto;
  final DateTime? desde;

  bool get esAdmin => rol == Rol.admin;

  factory Miembro.desde(Doc d) {
    final m = d.data() ?? {};
    return Miembro(
      uid: d.id,
      nombre: _texto(m['nombre']),
      rol: Rol.desdeId(m['rol']),
      activo: m['activo'] == true,
      foto: _bytes(m['foto']),
      desde: _fecha(m['desde']),
    );
  }
}

class Invitacion {
  const Invitacion({
    required this.codigo,
    required this.iglesiaId,
    required this.rol,
    required this.expiraEn,
    required this.activa,
  });

  final String codigo;
  final String iglesiaId;
  final Rol rol;
  final DateTime expiraEn;
  final bool activa;

  bool get vigente => activa && expiraEn.isAfter(DateTime.now());

  factory Invitacion.desde(Doc d) {
    final m = d.data() ?? {};
    return Invitacion(
      codigo: d.id,
      iglesiaId: _texto(m['iglesiaId']),
      rol: Rol.desdeId(m['rol']),
      expiraEn: _fecha(m['expiraEn']) ?? DateTime(2000),
      activa: m['activa'] == true,
    );
  }
}

/// Un hospital que visita la iglesia. Solo los administradores los dan de
/// alta; los servidores eligen de esta lista al registrar.
class Hospital {
  const Hospital({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.ciudad = '',
    this.telefono = '',
    this.notas = '',
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String direccion;
  final String ciudad;
  final String telefono;

  /// Por ejemplo: horario de visita, a quién pedir permiso, en qué entrada.
  final String notas;
  final bool activo;

  factory Hospital.desde(Doc d) {
    final m = d.data() ?? {};
    return Hospital(
      id: d.id,
      nombre: _texto(m['nombre']),
      direccion: _texto(m['direccion']),
      ciudad: _texto(m['ciudad']),
      telefono: _texto(m['telefono']),
      notas: _texto(m['notas']),
      activo: m['activo'] != false,
    );
  }

  Map<String, dynamic> aMapa() => {
    'nombre': nombre.trim(),
    'direccion': direccion.trim(),
    'ciudad': ciudad.trim(),
    'telefono': telefono.trim(),
    'notas': notas.trim(),
    'activo': activo,
  };
}

/// Una lista que el administrador sacó en PDF. Sus registros quedan
/// archivados y ya no salen en la siguiente.
class Corte {
  const Corte({
    required this.id,
    required this.fecha,
    required this.total,
    required this.hechoPorNombre,
    this.hospitalNombre = '',
  });

  final String id;
  final DateTime fecha;
  final int total;
  final String hechoPorNombre;

  /// Si la lista fue de un solo hospital.
  final String hospitalNombre;

  factory Corte.desde(Doc d) {
    final m = d.data() ?? {};
    return Corte(
      id: d.id,
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
      total: (m['total'] as num?)?.toInt() ?? 0,
      hechoPorNombre: _texto(m['hechoPorNombre']),
      hospitalNombre: _texto(m['hospitalNombre']),
    );
  }
}

/// En qué va la petición de oración.
enum Estado {
  pendiente('pendiente', 'Por orar'),
  orando('orando', 'En oración'),
  respondida('respondida', 'Respondida');

  const Estado(this.id, this.nombre);
  final String id;
  final String nombre;

  static Estado desdeId(String? id) => Estado.values.firstWhere(
    (e) => e.id == id,
    orElse: () => Estado.pendiente,
  );
}

/// Por quién se pide oración.
enum ParaQuien {
  persona('persona', 'Por la persona'),
  familiar('familiar', 'Por un familiar');

  const ParaQuien(this.id, this.nombre);
  final String id;
  final String nombre;

  static ParaQuien desdeId(String? id) =>
      id == 'familiar' ? ParaQuien.familiar : ParaQuien.persona;
}

/// Lo que se anota de cada persona con la que se habla en el hospital.
class Registro {
  const Registro({
    required this.id,
    required this.fecha,
    required this.hospitalId,
    required this.hospitalNombre,
    required this.nombre,
    this.edad,
    this.telefono = '',
    this.domicilio = '',
    this.paraQuien = ParaQuien.persona,
    this.familiarNombre = '',
    this.parentesco = '',
    this.padecimiento = '',
    this.ubicacion = '',
    this.peticion = '',
    this.notas = '',
    this.quiereSeguimiento = false,
    this.consentimiento = false,
    this.estado = Estado.pendiente,
    this.testimonio = '',
    this.oraron = const {},
    this.registradoPor = '',
    this.registradoPorNombre = '',
    this.creadoEn,
    this.pendienteDeSubir = false,
    this.archivado = false,
    this.corteId = '',
  });

  final String id;
  final DateTime fecha;
  final String hospitalId;
  final String hospitalNombre;

  /// La persona con la que se habló.
  final String nombre;
  final int? edad;
  final String telefono;
  final String domicilio;

  final ParaQuien paraQuien;

  /// Si se ora por un familiar internado.
  final String familiarNombre;
  final String parentesco;

  /// De qué padece quien está enfermo.
  final String padecimiento;

  /// Área, piso, cuarto o cama.
  final String ubicacion;
  final String peticion;
  final String notas;

  /// Si quiere que lo vuelvan a visitar o le llamen.
  final bool quiereSeguimiento;

  /// La persona aceptó que se guardaran sus datos.
  final bool consentimiento;
  final Estado estado;

  /// Cómo respondió Dios, cuando la petición se marca como respondida.
  final String testimonio;

  /// Quiénes ya oraron por esta petición: uid → nombre.
  final Map<String, String> oraron;

  final String registradoPor;
  final String registradoPorNombre;
  final DateTime? creadoEn;

  /// Se guardó en el teléfono pero todavía no llega al servidor.
  final bool pendienteDeSubir;

  /// Ya salió en una lista en PDF: no se cuenta en la siguiente.
  final bool archivado;

  /// Lista archivada en la que salió.
  final String corteId;

  /// A quién se ve en las listas: el enfermo por quien se ora.
  String get porQuienSeOra =>
      paraQuien == ParaQuien.familiar && familiarNombre.isNotEmpty
      ? familiarNombre
      : nombre;

  factory Registro.desde(Doc d) {
    final m = d.data() ?? {};
    final o = m['oraron'];
    return Registro(
      id: d.id,
      fecha: _fecha(m['fecha']) ?? DateTime.now(),
      hospitalId: _texto(m['hospitalId']),
      hospitalNombre: _texto(m['hospitalNombre']),
      nombre: _texto(m['nombre']),
      edad: (m['edad'] as num?)?.toInt(),
      telefono: _texto(m['telefono']),
      domicilio: _texto(m['domicilio']),
      paraQuien: ParaQuien.desdeId(m['paraQuien']),
      familiarNombre: _texto(m['familiarNombre']),
      parentesco: _texto(m['parentesco']),
      padecimiento: _texto(m['padecimiento']),
      ubicacion: _texto(m['ubicacion']),
      peticion: _texto(m['peticion']),
      notas: _texto(m['notas']),
      quiereSeguimiento: m['quiereSeguimiento'] == true,
      consentimiento: m['consentimiento'] == true,
      estado: Estado.desdeId(m['estado']),
      testimonio: _texto(m['testimonio']),
      oraron: o is Map
          ? {for (final e in o.entries) '${e.key}': '${e.value}'}
          : const {},
      registradoPor: _texto(m['registradoPor']),
      registradoPorNombre: _texto(m['registradoPorNombre']),
      creadoEn: _fecha(m['creadoEn']),
      pendienteDeSubir: d.metadata.hasPendingWrites,
      archivado: m['archivado'] == true,
      corteId: _texto(m['corteId']),
    );
  }

  /// Datos que se capturan en el formulario (sin los de control).
  Map<String, dynamic> datosCapturados() => {
    'fecha': Timestamp.fromDate(fecha),
    'hospitalId': hospitalId,
    'hospitalNombre': hospitalNombre,
    'nombre': nombre.trim(),
    'edad': edad,
    'telefono': telefono.trim(),
    'domicilio': domicilio.trim(),
    'paraQuien': paraQuien.id,
    'familiarNombre': paraQuien == ParaQuien.familiar
        ? familiarNombre.trim()
        : '',
    'parentesco': paraQuien == ParaQuien.familiar ? parentesco.trim() : '',
    'padecimiento': padecimiento.trim(),
    'ubicacion': ubicacion.trim(),
    'peticion': peticion.trim(),
    'notas': notas.trim(),
    'quiereSeguimiento': quiereSeguimiento,
    'consentimiento': consentimiento,
  };

  /// Texto en el que se busca (sin acentos, en minúsculas).
  String get textoBuscable => sinAcentos(
    [
      nombre,
      familiarNombre,
      padecimiento,
      hospitalNombre,
      telefono,
      domicilio,
      peticion,
      registradoPorNombre,
    ].join(' '),
  );
}

String sinAcentos(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : a[i]);
  }
  return b.toString().toLowerCase();
}
