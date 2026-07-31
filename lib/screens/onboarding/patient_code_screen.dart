import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';

class PatientCodeScreen extends StatefulWidget {
  final AppUser user;
  final void Function(AppUser updatedUser) onLinked;
  /// Si se indica, se muestra un botón "Más tarde" que permite continuar
  /// sin vincularse ahora mismo. Se omite cuando la pantalla se usa desde
  /// el perfil para añadir/cambiar el código (ahí no tiene sentido "saltar").
  final VoidCallback? onSkip;

  const PatientCodeScreen({
    super.key,
    required this.user,
    required this.onLinked,
    this.onSkip,
  });

  @override
  State<PatientCodeScreen> createState() => _PatientCodeScreenState();
}

class _PatientCodeScreenState extends State<PatientCodeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _vincular() async {
    final codigo = _controller.text.trim().toUpperCase();
    if (codigo.length < 4) {
      setState(() => _error = 'Introduce el código completo.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final svc  = RolesService(widget.user.token);
      await svc.vincularPaciente(codigo);

      final roleInfo = await svc.getRoleInfo();
      final updated  = widget.user.copyWith(
        role:        roleInfo['role']        as String?,
        roleSet:     roleInfo['role_set']    as bool?,
        logopedaId:  roleInfo['logopeda_id'] as String?,
        logopedaName: roleInfo['logopeda_name'] as String?,
      );

      if (!mounted) return;
      // Si esta pantalla se abrió como pantalla obligatoria de onboarding
      // (AppRouter) no hay nada que hacer pop; si se abrió desde el perfil
      // (para vincular o cambiar código) sí hay que cerrarla.
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      widget.onLinked(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Vincular con logopeda'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.link_rounded, color: Color(0xFF185FA5), size: 28),
              ),
              const SizedBox(height: 20),
              Text('Introduce tu código',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Tu logopeda te ha proporcionado un código de 8 caracteres '
                    'con el formato RTV-XXXX. Introdúcelo aquí para vincularte.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _controller,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 4),
                maxLength: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                ],
                decoration: InputDecoration(
                  hintText: 'RTV-XXXX',
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 4, fontSize: 28),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _error != null ? Colors.red : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _error != null ? Colors.red : Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _vincular,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Vincularme', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver a elegir perfil'),
                ),
              ),
              if (widget.onSkip != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : widget.onSkip,
                    child: Text(
                      'Más tarde',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      'Podrás vincularte con tu logopeda cuando quieras desde tu perfil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}