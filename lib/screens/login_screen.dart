import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/api_service.dart';

// ── Google Sign-In global ──────────────────────────────
final GoogleSignIn _googleAuth = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: '932911621543-3mndq09ncvdge2q541tsvmidovp01mei.apps.googleusercontent.com',
);

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onLogin;
  final Future<void> Function(String idToken) onGoogleLogin;
  final VoidCallback onGoRegister;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.onGoRegister,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _trySilentLogin();
    _loadRememberedEmail();
  }

  // ── Rellena el email recordado del último login ─────
  Future<void> _loadRememberedEmail() async {
    final email = await AuthService().loadRememberedEmail();
    if (email != null && mounted) {
      setState(() => _emailCtrl.text = email);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Manejo de errores ────────────────────────────────
  String _parseError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network')) return 'Sin conexión a internet';
    if (msg.contains('401')) return 'Credenciales inválidas';
    if (msg.contains('cancelled')) return 'Login cancelado';
    return 'Error: ${e.toString()}';
  }

  // ── Login normal ─────────────────────────────────────
  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Rellena todos los campos');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final email = _emailCtrl.text.trim();
      await widget.onLogin(email, _passCtrl.text);
      // Login correcto: recordamos el email para la próxima vez y avisamos
      // al gestor de contraseñas del sistema (Keychain/Google/etc.) de que
      // puede ofrecer guardar la contraseña.
      await AuthService().saveRememberedEmail(email);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = _parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Login silent login ───────────────────────
  Future<void> _trySilentLogin() async {
    try {
      final savedUser = await AuthService().loadUser();
      if (savedUser == null) {
        await _googleAuth.signOut();
        return;
      }

      final account = await _googleAuth.signInSilently();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken != null) {
        await widget.onGoogleLogin(idToken);
      }
    } catch (_) {}
  }

  // ── Google Login ─────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() { _loading = true; _error = null; });

    try {
      final account = await _googleAuth.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return; // usuario canceló
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw ApiException('No se pudo obtener el token de Google');
      }

      await widget.onGoogleLogin(idToken);

    } catch (e) {
      print('GOOGLE LOGIN ERROR: $e');
      if (mounted) setState(() => _error = _parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                Center(
                  child: Image.asset('assets/icon.png', width: 64, height: 64),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Recupera tu voz',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(
                      color: c.textDim,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Campos email/contraseña ─────────────────────
                // AutofillGroup: le dice al gestor de contraseñas del
                // sistema (Keychain en iOS/Mac, gestor de Google en
                // Android/Chrome) que estos campos van juntos, para que
                // pueda ofrecer autocompletar y guardar el login.
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthField(
                        ctrl: _emailCtrl,
                        label: 'Email',
                        hint: 'tu@email.com',
                        type: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        ctrl: _passCtrl,
                        label: 'Contraseña',
                        hint: '••••••••',
                        obscure: true,
                        onSubmit: _submit,
                        autofillHints: const [AutofillHints.password],
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: c.warn, fontSize: 13)),
                ],

                const SizedBox(height: 24),
                AuthButton(label: 'Entrar', loading: _loading, onTap: _submit),
                const SizedBox(height: 16),

                // ── Divider ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: c.textDim.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o', style: TextStyle(color: c.textDim, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: c.textDim.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Google Button ───────────────────────────────
                _GoogleButton(loading: _loading, onTap: _handleGoogleSignIn),

                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: widget.onGoRegister,
                    child: Text(
                      '¿No tienes cuenta? Regístrate',
                      style: TextStyle(color: c.accent, fontSize: 14),
                    ),
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

// ── Botón Google animado ─────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: loading ? 0.6 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.textDim.withOpacity(0.3)),
            backgroundColor: c.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/google_logo.png', width: 20),
              const SizedBox(width: 12),
              loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                'Continuar con Google',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}