import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class RegisterScreen extends StatefulWidget {
  final Future<void> Function(String name, String email, String password) onRegister;
  final VoidCallback onGoLogin;
  const RegisterScreen({super.key, required this.onRegister, required this.onGoLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  AdaptiveColors get c => AdaptiveColors.of(context);

  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Rellena todos los campos');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onRegister(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
      // Cuenta creada: avisamos al gestor de contraseñas del sistema para
      // que pueda ofrecer guardar el email/contraseña recién creados.
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Icon(Icons.person_add_outlined,
                    size: 64, color: c.accent)),
                const SizedBox(height: 16),
                Center(child: Text('Crear cuenta',
                    style: TextStyle(color: c.textPrimary,
                        fontSize: 26, fontWeight: FontWeight.w700))),
                const SizedBox(height: 6),
                Center(child: Text('Es gratis y solo toma un momento',
                    style: TextStyle(color: c.textDim, fontSize: 14))),
                const SizedBox(height: 40),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthField(ctrl: _nameCtrl, label: 'Nombre', hint: 'Tu nombre',
                          autofillHints: const [AutofillHints.name]),
                      const SizedBox(height: 14),
                      AuthField(ctrl: _emailCtrl, label: 'Email',
                          hint: 'tu@email.com', type: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email]),
                      const SizedBox(height: 14),
                      AuthField(ctrl: _passCtrl, label: 'Contraseña',
                          hint: 'Mínimo 6 caracteres', obscure: true, onSubmit: _submit,
                          autofillHints: const [AutofillHints.newPassword]),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: c.warn, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                AuthButton(label: 'Crear cuenta', loading: _loading, onTap: _submit),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: widget.onGoLogin,
                    child: Text('¿Ya tienes cuenta? Inicia sesión',
                        style: TextStyle(color: c.accent, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}