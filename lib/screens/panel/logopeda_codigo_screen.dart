import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../services/roles_service.dart';
import '../../widgets/main_app_bar.dart';

class LogopedaCodigoScreen extends StatefulWidget {
  final AppUser user;
  const LogopedaCodigoScreen({super.key, required this.user});

  @override
  State<LogopedaCodigoScreen> createState() => _LogopedaCodigoScreenState();
}

class _LogopedaCodigoScreenState extends State<LogopedaCodigoScreen> {
  String?   _codigo;
  String?   _expiresAt;
  bool      _loading = true;
  bool      _generating = false;

  @override
  void initState() {
    super.initState();
    _loadCodigo();
  }

  Future<void> _loadCodigo() async {
    setState(() => _loading = true);
    try {
      final svc  = RolesService(widget.user.token);
      final data = await svc.getMiCodigo();
      if (mounted) {
        setState(() {
          _codigo    = data?['codigo'];
          _expiresAt = data?['expires_at'];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generarCodigo() async {
    setState(() => _generating = true);
    try {
      final svc  = RolesService(widget.user.token);
      final data = await svc.generarCodigo();
      if (mounted) {
        setState(() {
          _codigo    = data['codigo'];
          _expiresAt = data['expires_at'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _copiar() {
    if (_codigo == null) return;
    Clipboard.setData(ClipboardData(text: _codigo!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles'),
        backgroundColor: Color(0xFF1D9E75),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatExpiry(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return 'Válido hasta el ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Código de vinculación',
        showVozAction: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparte este código con tus pacientes para que '
                    'puedan vincularse a tu panel.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 32),

              if (_codigo != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF5DCAA5), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _codigo!,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Color(0xFF1CE7B2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatExpiry(_expiresAt),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1CE7B2)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copiar,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar código'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade500, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El código puede ser usado por varios pacientes. '
                              'Si lo regeneras, el anterior deja de funcionar.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.link_off_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes ningún código activo.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generarCodigo,
                  icon: _generating
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_codigo != null ? 'Regenerar código' : 'Generar código'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE7B2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}