import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/modelos.dart';

typedef Col = CollectionReference<Map<String, dynamic>>;
typedef Ref = DocumentReference<Map<String, dynamic>>;

/// Perfil del usuario: su nombre, su foto y las iglesias a las que pertenece.
class Perfil {
  const Perfil({
    required this.uid,
    required this.nombre,
    required this.iglesias,
    required this.iglesiaActual,
    this.foto,
  });

  final String uid;
  final String nombre;
  final Uint8List? foto;
  final List<String> iglesias;
  final String? iglesiaActual;

  factory Perfil.desde(Doc d) {
    final m = d.data() ?? {};
    return Perfil(
      uid: d.id,
      nombre: m['nombre'] ?? '',
      iglesias: List<String>.from(m['iglesias'] as List? ?? const []),
      iglesiaActual: m['iglesiaActual'],
      foto: m['foto'] is Blob ? (m['foto'] as Blob).bytes : null,
    );
  }
}

/// Error con un mensaje que se le puede mostrar tal cual al usuario.
class ErrorDeUso implements Exception {
  const ErrorDeUso(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Lanza una escritura sin esperar al servidor: sin señal queda guardada en
/// el teléfono y Firestore la sube sola al volver la conexión.
void _enCola(Future<void> escritura) => unawaited(escritura.catchError((_) {}));

/// Acceso a Firebase. Todo (logos y fotos incluidos, ya reducidos) vive en
/// Firestore para no depender de servicios de pago.
class Repo {
  Repo(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser!.uid;
  String get miCorreo => _auth.currentUser?.email ?? '';

  Ref get _usuario => _db.collection('usuarios').doc(uid);
  Ref _igl(String id) => _db.collection('iglesias').doc(id);
  Col _sub(String iglesiaId, String nombre) =>
      _igl(iglesiaId).collection(nombre);

  // ---------------------------------------------------------------- Sesión

  Future<void> entrarConGoogle() =>
      _auth.signInWithProvider(GoogleAuthProvider());

  Future<void> entrarConCorreo(String correo, String clave) =>
      _auth.signInWithEmailAndPassword(email: correo.trim(), password: clave);

  String? _nombrePendiente;

  Future<void> registrarConCorreo(
    String nombre,
    String correo,
    String clave,
  ) async {
    _nombrePendiente = nombre.trim();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
    await cred.user?.updateDisplayName(nombre.trim());
  }

  Future<void> recuperarClave(String correo) =>
      _auth.sendPasswordResetEmail(email: correo.trim());

  Future<void> salir() => _auth.signOut();

  /// Crea el perfil la primera vez que alguien entra.
  Future<void> asegurarPerfil() async {
    final u = _auth.currentUser!;
    final doc = await _usuario.get();
    if (doc.exists && (doc.data()?['nombre'] ?? '') != '') return;
    await _usuario.set({
      'nombre':
          _nombrePendiente ??
          u.displayName ??
          u.email?.split('@').first ??
          'Servidor',
      'correo': u.email,
      if (!doc.exists) 'iglesias': <String>[],
    }, SetOptions(merge: true));
  }

  Stream<Perfil?> perfil(String uid) => _db
      .collection('usuarios')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Perfil.desde(d) : null);

  Future<void> cambiarIglesia(String id) =>
      _usuario.update({'iglesiaActual': id});

  /// Cambia el nombre y la foto del usuario, y los copia a su ficha en cada
  /// iglesia para que los demás lo vean.
  void guardarMiPerfil({
    required String nombre,
    Uint8List? foto,
    required List<String> iglesias,
  }) {
    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
      if (foto != null) 'foto': Blob(foto),
    };
    _enCola(_usuario.set(datos, SetOptions(merge: true)));
    _enCola(
      _auth.currentUser?.updateDisplayName(nombre.trim()) ?? Future.value(),
    );
    for (final id in iglesias) {
      _enCola(_sub(id, 'miembros').doc(uid).update(datos));
    }
  }

  Future<void> olvidarIglesia(String id) => _usuario.update({
    'iglesias': FieldValue.arrayRemove([id]),
    'iglesiaActual': FieldValue.delete(),
  });

  Future<void> abandonarIglesia(String id) async {
    await _exigirConexion();
    await _sub(id, 'miembros').doc(uid).delete();
    await olvidarIglesia(id);
  }

  /// Lo que no debe quedarse en cola y ocurrir más tarde por sorpresa
  /// (salirse, borrar, unirse) exige conexión.
  Future<void> _exigirConexion() async {
    try {
      await _usuario
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const ErrorDeUso('Necesitas conexión a internet para hacer esto.');
    }
  }

  // --------------------------------------------------------------- Iglesias

  /// Crea la iglesia; quien la crea queda como administrador. Los hospitales
  /// iniciales se pueden dar de alta de una vez.
  Future<void> crearIglesia({
    required String miNombre,
    required String nombre,
    required String ciudad,
    required String lema,
    required int color,
    Uint8List? logo,
    List<String> hospitales = const [],
  }) async {
    await _exigirConexion();
    final ref = _db.collection('iglesias').doc();
    final lote = _db.batch()
      ..set(ref, {
        'nombre': nombre.trim(),
        'ciudad': ciudad.trim(),
        'lema': lema.trim(),
        'color': color,
        'logo': ?(logo == null ? null : Blob(logo)),
        'creadoPor': uid,
        'creadoEn': FieldValue.serverTimestamp(),
      })
      ..set(ref.collection('miembros').doc(uid), {
        'nombre': miNombre,
        'rol': Rol.admin.id,
        'activo': true,
        'desde': FieldValue.serverTimestamp(),
      })
      ..set(_usuario, {
        'iglesias': FieldValue.arrayUnion([ref.id]),
        'iglesiaActual': ref.id,
      }, SetOptions(merge: true));
    await lote.commit();
    // Los hospitales van después: la regla pide que ya sea administrador.
    for (final h in hospitales.where((h) => h.trim().isNotEmpty)) {
      _enCola(
        ref
            .collection('hospitales')
            .doc()
            .set(Hospital(id: '', nombre: h).aMapa()),
      );
    }
  }

  /// Entra a una iglesia con un código de invitación.
  Future<void> unirseConCodigo(String codigo, String miNombre) async {
    final limpio = codigo.trim().toUpperCase();
    if (limpio.isEmpty) throw const ErrorDeUso('Escribe el código.');
    await _exigirConexion();
    final doc = await _db.collection('invitaciones').doc(limpio).get();
    if (!doc.exists) throw const ErrorDeUso('Ese código no existe.');
    final inv = Invitacion.desde(doc);
    if (!inv.vigente) {
      throw const ErrorDeUso(
        'Ese código ya venció. Pide uno nuevo a tu administrador.',
      );
    }
    final miembro = _sub(inv.iglesiaId, 'miembros').doc(uid);
    final ya = await miembro.get().then((d) => d.exists, onError: (_) => false);
    if (!ya) {
      final perfil = await _usuario.get();
      final foto = perfil.data()?['foto'];
      await miembro.set({
        'nombre': miNombre,
        'rol': inv.rol.id,
        'activo': true,
        'codigoUsado': limpio,
        'foto': ?(foto is Blob ? foto : null),
        'desde': FieldValue.serverTimestamp(),
      });
    }
    await _usuario.set({
      'iglesias': FieldValue.arrayUnion([inv.iglesiaId]),
      'iglesiaActual': inv.iglesiaId,
    }, SetOptions(merge: true));
  }

  Stream<Iglesia?> iglesia(String id) =>
      _igl(id).snapshots().map((d) => d.exists ? Iglesia.desde(d) : null);

  void editarIglesia(
    String id, {
    required String nombre,
    required String ciudad,
    required String lema,
    required int color,
    Uint8List? logo,
    bool quitarLogo = false,
  }) {
    _enCola(
      _igl(id).update({
        'nombre': nombre.trim(),
        'ciudad': ciudad.trim(),
        'lema': lema.trim(),
        'color': color,
        if (logo != null) 'logo': Blob(logo),
        if (quitarLogo && logo == null) 'logo': FieldValue.delete(),
      }),
    );
  }

  /// Borra la iglesia completa con todo su contenido.
  Future<void> borrarIglesia(String id) async {
    await _exigirConexion();
    final refs = <Ref>[];
    for (final nombre in const ['registros', 'hospitales', 'cortes']) {
      final docs = await _sub(id, nombre).get();
      refs.addAll(docs.docs.map((d) => d.reference));
    }
    final codigos = await _db
        .collection('invitaciones')
        .where('iglesiaId', isEqualTo: id)
        .get();
    refs.addAll(codigos.docs.map((d) => d.reference));
    final miembros = await _sub(id, 'miembros').get();
    refs.addAll(
      miembros.docs.where((d) => d.id != uid).map((d) => d.reference),
    );
    for (var i = 0; i < refs.length; i += 400) {
      final lote = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        lote.delete(r);
      }
      await lote.commit();
    }
    await (_db.batch()
          ..delete(_sub(id, 'miembros').doc(uid))
          ..delete(_igl(id)))
        .commit();
    await olvidarIglesia(id);
  }

  // --------------------------------------------------------------- Miembros

  Stream<Miembro?> miembro(String iglesiaId, String uid) => _sub(
    iglesiaId,
    'miembros',
  ).doc(uid).snapshots().map((d) => d.exists ? Miembro.desde(d) : null);

  Stream<List<Miembro>> miembros(String iglesiaId) =>
      _sub(iglesiaId, 'miembros').snapshots().map(
        (s) => s.docs.map(Miembro.desde).toList()
          ..sort((a, b) {
            if (a.esAdmin != b.esAdmin) return a.esAdmin ? -1 : 1;
            return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
          }),
      );

  Future<void> cambiarMiembro(
    String iglesiaId,
    String uid, {
    Rol? rol,
    bool? activo,
  }) => _sub(
    iglesiaId,
    'miembros',
  ).doc(uid).update({'rol': ?rol?.id, 'activo': ?activo});

  Future<void> quitarMiembro(String iglesiaId, String uid) async {
    await _exigirConexion();
    await _sub(iglesiaId, 'miembros').doc(uid).delete();
  }

  static const _letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Genera un código de 6 caracteres válido por [dias] días.
  Future<String> crearInvitacion(
    String iglesiaId,
    Rol rol, {
    int dias = 7,
  }) async {
    await _exigirConexion();
    final azar = Random.secure();
    final codigo = List.generate(
      6,
      (_) => _letras[azar.nextInt(_letras.length)],
    ).join();
    await _db.collection('invitaciones').doc(codigo).set({
      'iglesiaId': iglesiaId,
      'rol': rol.id,
      'activa': true,
      'creadaPor': uid,
      'creadaEn': FieldValue.serverTimestamp(),
      'expiraEn': Timestamp.fromDate(DateTime.now().add(Duration(days: dias))),
    });
    return codigo;
  }

  Stream<List<Invitacion>> invitaciones(String iglesiaId) => _db
      .collection('invitaciones')
      .where('iglesiaId', isEqualTo: iglesiaId)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Invitacion.desde).where((i) => i.vigente).toList()
              ..sort((a, b) => b.expiraEn.compareTo(a.expiraEn)),
      );

  Future<void> anularInvitacion(String codigo) =>
      _db.collection('invitaciones').doc(codigo).update({'activa': false});

  // ------------------------------------------------------------- Hospitales

  Stream<List<Hospital>> hospitales(String iglesiaId) =>
      _sub(iglesiaId, 'hospitales').snapshots().map(
        (s) => s.docs.map(Hospital.desde).toList()
          ..sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          ),
      );

  void guardarHospital(String iglesiaId, Hospital h) {
    final col = _sub(iglesiaId, 'hospitales');
    _enCola((h.id.isEmpty ? col.doc() : col.doc(h.id)).set(h.aMapa()));
  }

  Future<void> borrarHospital(String iglesiaId, String id) =>
      _sub(iglesiaId, 'hospitales').doc(id).delete();

  // -------------------------------------------------------------- Registros

  /// Registros que todavía no salen en una lista archivada (los de la
  /// lista actual). Se incluyen los cambios locales para marcar los que aún
  /// no se suben.
  Stream<List<Registro>> registrosActivos(String iglesiaId) =>
      _sub(iglesiaId, 'registros')
          .where('archivado', isEqualTo: false)
          .snapshots(includeMetadataChanges: true)
          .map(
            (s) => s.docs.map(Registro.desde).toList()
              ..sort((a, b) {
                final f = b.fecha.compareTo(a.fecha);
                if (f != 0) return f;
                return (b.creadoEn ?? DateTime(3000)).compareTo(
                  a.creadoEn ?? DateTime(3000),
                );
              }),
          );

  /// Registros con un campo igual a un valor (de un hospital o de un
  /// servidor). Se ordenan aquí para no requerir índices compuestos.
  Stream<List<Registro>> registrosDonde(
    String iglesiaId,
    String campo,
    String valor,
  ) => _sub(iglesiaId, 'registros')
      .where(campo, isEqualTo: valor)
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) =>
            s.docs.map(Registro.desde).toList()
              ..sort((a, b) => b.fecha.compareTo(a.fecha)),
      );

  Stream<Registro?> registro(String iglesiaId, String id) =>
      _sub(iglesiaId, 'registros')
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .map((d) => d.exists ? Registro.desde(d) : null);

  /// Guarda un registro nuevo o editado y devuelve su id. No espera al
  /// servidor.
  String guardarRegistro(String iglesiaId, Registro r, String miNombre) {
    final col = _sub(iglesiaId, 'registros');
    if (r.id.isEmpty) {
      final ref = col.doc();
      _enCola(
        ref.set({
          ...r.datosCapturados(),
          'estado': Estado.pendiente.id,
          'testimonio': '',
          'oraron': <String, String>{},
          'archivado': false,
          'corteId': '',
          'registradoPor': uid,
          'registradoPorNombre': miNombre,
          'creadoEn': FieldValue.serverTimestamp(),
        }),
      );
      return ref.id;
    }
    _enCola(
      col.doc(r.id).update({
        ...r.datosCapturados(),
        'editadoPor': uid,
        'editadoEn': FieldValue.serverTimestamp(),
      }),
    );
    return r.id;
  }

  void cambiarEstado(
    String iglesiaId,
    String id,
    Estado estado, {
    String? testimonio,
  }) {
    _enCola(
      _sub(iglesiaId, 'registros').doc(id).update({
        'estado': estado.id,
        'testimonio': ?testimonio?.trim(),
      }),
    );
  }

  /// Anota (o quita) que el usuario ya oró por esta petición.
  void marcarOre(String iglesiaId, String id, bool ore, String miNombre) {
    _enCola(
      _sub(iglesiaId, 'registros').doc(id).set({
        'oraron': {uid: ore ? miNombre : FieldValue.delete()},
      }, SetOptions(merge: true)),
    );
  }

  Future<void> borrarRegistro(String iglesiaId, String id) =>
      _sub(iglesiaId, 'registros').doc(id).delete();

  /// Los registros de la versión 1.0.0 no tienen el campo «archivado» y no
  /// saldrían en la lista actual. Se completa una sola vez por iglesia.
  Future<void> completarArchivado(String iglesiaId) async {
    final docs = await _sub(iglesiaId, 'registros').get();
    final faltan = docs.docs
        .where((d) => !d.data().containsKey('archivado'))
        .map((d) => d.id);
    await _actualizarEnLotes(iglesiaId, faltan, {
      'archivado': false,
      'corteId': '',
    });
  }

  // ------------------------------------------------------ Listas archivadas

  Stream<List<Corte>> cortes(String iglesiaId) => _sub(iglesiaId, 'cortes')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Corte.desde).toList());

  /// Archiva [registros]: salen en esta lista y ya no en la siguiente.
  Future<String> archivar(
    String iglesiaId,
    List<Registro> registros, {
    required String miNombre,
    String hospitalNombre = '',
  }) async {
    await _exigirConexion();
    final corte = _sub(iglesiaId, 'cortes').doc();
    await corte.set({
      'fecha': FieldValue.serverTimestamp(),
      'total': registros.length,
      'hechoPor': uid,
      'hechoPorNombre': miNombre,
      'hospitalNombre': hospitalNombre,
    });
    await _actualizarEnLotes(iglesiaId, registros.map((r) => r.id), {
      'archivado': true,
      'corteId': corte.id,
    });
    return corte.id;
  }

  /// Deshace una lista archivada: sus registros vuelven a la lista actual.
  Future<void> desarchivar(String iglesiaId, String corteId) async {
    await _exigirConexion();
    final docs = await _sub(
      iglesiaId,
      'registros',
    ).where('corteId', isEqualTo: corteId).get();
    await _actualizarEnLotes(iglesiaId, docs.docs.map((d) => d.id), {
      'archivado': false,
      'corteId': '',
    });
    await _sub(iglesiaId, 'cortes').doc(corteId).delete();
  }

  Future<void> _actualizarEnLotes(
    String iglesiaId,
    Iterable<String> ids,
    Map<String, dynamic> datos,
  ) async {
    final lista = ids.toList();
    for (var i = 0; i < lista.length; i += 400) {
      final lote = _db.batch();
      for (final id in lista.skip(i).take(400)) {
        lote.update(_sub(iglesiaId, 'registros').doc(id), datos);
      }
      await lote.commit();
    }
  }
}
