import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Colores de la app. El color principal lo puede cambiar cada iglesia;
/// el resto (fondos, texto, coral de acento) se mantiene para que todo
/// combine con cualquier color elegido.
abstract final class Colores {
  /// Verde quirófano: color principal por omisión.
  static const verde = Color(0xFF0F6E64);

  /// Coral: el acento cálido (la cruz, el corazón, los botones flotantes).
  static const coral = Color(0xFFF2644A);
  static const coralSuave = Color(0xFFFDE7E1);

  static const blanco = Colors.white;

  /// Fondo general, apenas verdoso como pared de hospital.
  static const fondo = Color(0xFFF5F9F8);

  static const tinta = Color(0xFF11302C);
  static const textoSuave = Color(0xFF4E6663);
  static const textoApagado = Color(0xFF8DA19E);
  static const borde = Color(0xFFD6E4E1);
  static const nube = Color(0xFFE8F1EF);

  static const ok = Color(0xFF1C8A4E);
  static const ambar = Color(0xFFB26A00);
  static const rojo = Color(0xFFC63A2B);
}

/// Colores que puede elegir una iglesia para su app.
const coloresIglesia = <Color>[
  Color(0xFF0F6E64), // verde quirófano
  Color(0xFF1D5FA8), // azul
  Color(0xFF16336B), // azul marino
  Color(0xFF6A3FA0), // morado
  Color(0xFF8E2343), // vino
  Color(0xFF2F7A2F), // verde
  Color(0xFFB4530F), // naranja tostado
  Color(0xFF3D4B5C), // pizarra
];

abstract final class Fuentes {
  static const titulos = 'Bricolage';
  static const texto = 'Figtree';
}

/// Estilo para títulos y cifras grandes.
TextStyle titulo(double tamano, {Color color = Colores.tinta}) => TextStyle(
  fontFamily: Fuentes.titulos,
  fontSize: tamano,
  fontWeight: FontWeight.w800,
  height: 1.08,
  letterSpacing: -0.02 * tamano,
  color: color,
);

const _negrita = TextStyle(
  fontFamily: Fuentes.texto,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);

/// Versión clara del color principal, para fondos de chips y tarjetas.
Color suave(Color c, [double cantidad = .12]) =>
    Color.alphaBlend(c.withValues(alpha: cantidad), Colores.blanco);

/// Versión oscura del color principal, para texto sobre fondos claros.
Color oscuro(Color c, [double cantidad = .25]) =>
    Color.lerp(c, Colors.black, cantidad)!;

/// Tema completo a partir del color de la iglesia.
ThemeData temaPara(Color principal) {
  final esquema = ColorScheme.fromSeed(
    seedColor: principal,
    primary: principal,
    onPrimary: Colores.blanco,
    secondary: Colores.coral,
    onSecondary: Colores.blanco,
    surface: Colores.fondo,
    onSurface: Colores.tinta,
    onSurfaceVariant: Colores.textoSuave,
    outline: Colores.borde,
    outlineVariant: Colores.borde,
    error: Colores.rojo,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: Fuentes.texto,
  );
  final texto = base.textTheme.apply(
    bodyColor: Colores.tinta,
    displayColor: Colores.tinta,
    letterSpacingFactor: 0,
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return base.copyWith(
    scaffoldBackgroundColor: Colores.fondo,
    canvasColor: Colores.fondo,
    textTheme: texto.copyWith(
      headlineMedium: titulo(30),
      headlineSmall: titulo(25),
      titleLarge: titulo(21),
      titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: texto.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
      bodyMedium: texto.bodyMedium?.copyWith(fontSize: 14.5, height: 1.4),
      bodySmall: texto.bodySmall?.copyWith(color: Colores.textoSuave),
    ),
    iconTheme: IconThemeData(color: principal),
    appBarTheme: AppBarTheme(
      backgroundColor: principal,
      foregroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colores.blanco),
      actionsIconTheme: const IconThemeData(color: Colores.blanco),
      titleTextStyle: titulo(21, color: Colores.blanco),
    ),
    cardTheme: CardThemeData(
      color: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: oscuro(principal, .5).withValues(alpha: .18),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: suave(principal, .08), width: 1),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: principal,
      textColor: Colores.tinta,
      subtitleTextStyle: const TextStyle(
        fontFamily: Fuentes.texto,
        fontSize: 13.5,
        color: Colores.textoSuave,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: principal,
        foregroundColor: Colores.blanco,
        disabledBackgroundColor: Colores.nube,
        disabledForegroundColor: Colores.textoApagado,
        minimumSize: const Size.fromHeight(54),
        shape: forma,
        textStyle: _negrita,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: principal,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: principal, width: 1.5),
        shape: forma,
        textStyle: _negrita,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: principal,
        textStyle: _negrita.copyWith(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colores.blanco,
      labelStyle: const TextStyle(color: Colores.textoSuave),
      floatingLabelStyle: TextStyle(color: principal),
      hintStyle: const TextStyle(color: Colores.textoApagado),
      helperStyle: const TextStyle(color: Colores.textoSuave),
      prefixIconColor: Colores.textoSuave,
      suffixIconColor: principal,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colores.borde, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: principal, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: principal,
      selectionColor: principal.withValues(alpha: .3),
      selectionHandleColor: principal,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colores.blanco,
      selectedColor: principal,
      checkmarkColor: Colores.blanco,
      side: const BorderSide(color: Colores.borde, width: 1.2),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: Fuentes.texto,
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (e) =>
              e.contains(WidgetState.selected) ? Colores.blanco : Colores.tinta,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: principal,
        selectedForegroundColor: Colores.blanco,
        side: const BorderSide(color: Colores.borde, width: 1.2),
        textStyle: _negrita.copyWith(fontSize: 14),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Colores.blanco
            : Colores.textoSuave,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected) ? principal : Colores.nube,
      ),
      // Apagado también se distingue: borde y bolita grises.
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Colors.transparent
            : Colores.textoApagado,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: Colores.textoSuave, width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colores.coral,
      foregroundColor: Colores.blanco,
      elevation: 3,
      highlightElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: _negrita.copyWith(fontSize: 15),
    ),
    dividerTheme: const DividerThemeData(color: Colores.borde, space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colores.borde),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colores.tinta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: _negrita.copyWith(
        fontSize: 14.5,
        color: Colores.blanco,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: titulo(22),
      contentTextStyle: const TextStyle(
        fontFamily: Fuentes.texto,
        fontSize: 15,
        height: 1.4,
        color: Colores.textoSuave,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colores.blanco,
      surfaceTintColor: Colors.transparent,
      indicatorColor: suave(principal, .16),
      height: 70,
      iconTheme: WidgetStateProperty.resolveWith(
        (e) => IconThemeData(
          color: e.contains(WidgetState.selected)
              ? principal
              : Colores.textoApagado,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (e) => TextStyle(
          fontFamily: Fuentes.texto,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: e.contains(WidgetState.selected)
              ? principal
              : Colores.textoSuave,
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: principal),
  );
}

extension ColorDelTema on BuildContext {
  /// Color principal de la iglesia abierta.
  Color get principal => Theme.of(this).colorScheme.primary;
}
