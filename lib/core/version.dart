/// Compara dos versiones del tipo «1.2.0» (con o sin «v» al inicio y con o
/// sin «+compilación»). Devuelve si [candidata] es más nueva que [instalada].
bool esMasNueva(String candidata, String instalada) {
  final a = _partes(candidata);
  final b = _partes(instalada);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int> _partes(String version) {
  final limpia = version.trim().replaceFirst(RegExp('^[vV]'), '').split('+')[0];
  final numeros = limpia
      .split('.')
      .map((p) => int.tryParse(RegExp(r'^\d+').stringMatch(p) ?? '') ?? 0)
      .toList();
  while (numeros.length < 3) {
    numeros.add(0);
  }
  return numeros;
}
