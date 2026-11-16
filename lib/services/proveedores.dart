import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelos.dart';
import 'repo.dart';

final repoProvider = Provider<Repo>(
  (ref) => Repo(FirebaseFirestore.instance, FirebaseAuth.instance),
);

final sesionProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final perfilProvider = StreamProvider<Perfil?>((ref) {
  final u = ref.watch(sesionProvider).value;
  if (u == null) return Stream.value(null);
  return ref.watch(repoProvider).perfil(u.uid);
});

final miUidProvider = Provider<String?>(
  (ref) => ref.watch(sesionProvider).value?.uid,
);

/// Iglesia que el usuario tiene abierta.
final iglesiaIdProvider = Provider<String?>((ref) {
  final p = ref.watch(perfilProvider).value;
  if (p == null) return null;
  if (p.iglesiaActual != null && p.iglesias.contains(p.iglesiaActual)) {
    return p.iglesiaActual;
  }
  return p.iglesias.isEmpty ? null : p.iglesias.first;
});

final iglesiaProvider = StreamProvider<Iglesia?>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(repoProvider).iglesia(id);
});

/// Datos de cualquier iglesia del usuario, para el selector de iglesias.
final iglesiaPorIdProvider = StreamProvider.family<Iglesia?, String>(
  (ref, id) => ref.watch(repoProvider).iglesia(id),
);

final yoProvider = StreamProvider<Miembro?>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  final uid = ref.watch(miUidProvider);
  if (id == null || uid == null) return Stream.value(null);
  return ref.watch(repoProvider).miembro(id, uid);
});

final esAdminProvider = Provider<bool>(
  (ref) => ref.watch(yoProvider).value?.esAdmin ?? false,
);

final miNombreProvider = Provider<String>(
  (ref) =>
      ref.watch(yoProvider).value?.nombre ??
      ref.watch(perfilProvider).value?.nombre ??
      '',
);

final miembrosProvider = StreamProvider<List<Miembro>>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).miembros(id);
});

final invitacionesProvider = StreamProvider<List<Invitacion>>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).invitaciones(id);
});

final hospitalesProvider = StreamProvider<List<Hospital>>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).hospitales(id);
});

final hospitalesActivosProvider = Provider<List<Hospital>>(
  (ref) => (ref.watch(hospitalesProvider).value ?? const [])
      .where((h) => h.activo)
      .toList(),
);

/// Registros de la lista actual (los que no se han archivado).
final registrosProvider = StreamProvider<List<Registro>>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).registrosActivos(id);
});

/// Listas archivadas, de la más reciente a la más antigua.
final cortesProvider = StreamProvider<List<Corte>>((ref) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).cortes(id);
});

final registroProvider = StreamProvider.family<Registro?, String>((ref, rid) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(repoProvider).registro(id, rid);
});

typedef Filtro = ({String campo, String valor});

/// Registros de un hospital, de un servidor o de una lista archivada.
final registrosDondeProvider = StreamProvider.family<List<Registro>, Filtro>((
  ref,
  f,
) {
  final id = ref.watch(iglesiaIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(repoProvider).registrosDonde(id, f.campo, f.valor);
});

/// Cuántos registros siguen guardados solo en el teléfono.
final pendientesDeSubirProvider = Provider<int>(
  (ref) => (ref.watch(registrosProvider).value ?? const [])
      .where((r) => r.pendienteDeSubir)
      .length,
);
