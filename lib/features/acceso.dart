import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/tema.dart';
import '../services/proveedores.dart';
import '../widgets/comunes.dart';

/// Bienvenida e inicio de sesión (Google o correo).
class PantallaAcceso extends ConsumerStatefulWidget {
  const PantallaAcceso({super.key});
  @override
  ConsumerState<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends ConsumerState<PantallaAcceso> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _registrando = false;
  bool _ocupado = false;
  bool _verClave = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    await intentar(context, accion);
    if (mounted) setState(() => _ocupado = false);
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(repoProvider);
    _hacer(
      () => _registrando
          ? repo.registrarConCorreo(_nombre.text, _correo.text, _clave.text)
          : repo.entrarConCorreo(_correo.text, _clave.text),
    );
  }

  Future<void> _recuperar() async {
    if (!_correo.text.contains('@')) {
      avisar(context, 'Escribe tu correo arriba y vuelve a tocar aquí.');
      return;
    }
    final ok = await intentar(
      context,
      () => ref.read(repoProvider).recuperarClave(_correo.text),
    );
    if (ok && mounted) {
      avisar(context, 'Te enviamos un correo para cambiar tu contraseña.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final principal = context.principal;
    return Scaffold(
      backgroundColor: principal,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, medidas) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: medidas.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LineaDeVida(alto: 64),
                        const SizedBox(height: 22),
                        Text(
                          'Visitas de Fe',
                          style: titulo(38, color: Colores.blanco),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '«Estuve enfermo, y me visitasteis»\nMateo 25:36',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Colores.blanco.withValues(alpha: .82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Entrada(
                    orden: 2,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colores.fondo,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        30,
                        24,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _formulario(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _registrando ? 'Crea tu cuenta' : 'Inicia sesión',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'Registra a las personas por las que oras, aunque no tengas señal.',
          style: TextStyle(color: Colores.textoSuave),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _hacer(ref.read(repoProvider).entrarConGoogle),
          icon: const Text(
            'G',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          label: const Text('Continuar con Google'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o con tu correo',
                  style: TextStyle(color: Colores.textoSuave),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _registrando
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Escribe tu nombre'
                        : null,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        TextFormField(
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
          validator: (v) =>
              (v ?? '').contains('@') ? null : 'Escribe un correo válido',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _clave,
          obscureText: !_verClave,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              tooltip: _verClave ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _verClave
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: () => setState(() => _verClave = !_verClave),
            ),
          ),
          validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
          onFieldSubmitted: (_) => _enviar(),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _ocupado ? null : _enviar,
          child: Text(_registrando ? 'Crear cuenta' : 'Entrar'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() => _registrando = !_registrando),
          child: Text(
            _registrando ? 'Ya tengo cuenta' : 'No tengo cuenta: registrarme',
          ),
        ),
        if (!_registrando)
          TextButton(
            onPressed: _recuperar,
            child: const Text('Olvidé mi contraseña'),
          ),
      ],
    ),
  );
}
