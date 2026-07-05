import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  int _step = 1;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscurePass = true;
  bool _loading = false;
  String? _errorMsg;
  String? _successMsg;

  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[a-zA-Z]{2,}$');

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await AuthService.requestPasswordReset(email: _emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _loading = false;
          _step = 2;
          _successMsg = 'Te enviamos un código a ${_emailCtrl.text.trim()}';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'No se pudo conectar al servidor. Verifica tu conexión.';
      });
    }
  }

  Future<void> _confirmReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await AuthService.confirmPasswordReset(
        token: _tokenCtrl.text.trim(),
        newPassword: _passCtrl.text,
      );
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente'), backgroundColor: Colors.green),
        );
        context.go('/login');
      }
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'No se pudo conectar al servidor. Verifica tu conexión.';
      });
    }
  }

  void _backToStep1() {
    setState(() {
      _step = 1;
      _errorMsg = null;
      _successMsg = null;
      _tokenCtrl.clear();
      _passCtrl.clear();
      _pass2Ctrl.clear();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _emailFormKey,
      child: ListView(
        children: [
          const SizedBox(height: 32),
          const Rent2GoLogo(),
          const SizedBox(height: 40),
          const Text(
            'Recuperar\ncontraseña',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ingresa tu correo y te enviaremos un código para restablecer tu contraseña.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 32),

          if (_errorMsg != null) ...[
            _ErrorBanner(message: _errorMsg!),
            const SizedBox(height: 16),
          ],

          CustomInput(
            label: 'Correo electrónico',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu correo';
              if (!_emailRegex.hasMatch(v.trim())) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: 32),
          CustomButton(label: 'Enviar código', onPressed: _requestCode, loading: _loading),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Volver a iniciar sesión', style: TextStyle(color: kCyan)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _resetFormKey,
      child: ListView(
        children: [
          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(
                onPressed: _backToStep1,
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
              ),
              const Rent2GoLogo(),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Ingresa el código\ny tu nueva contraseña',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 10),

          if (_successMsg != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: kCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_successMsg!, style: const TextStyle(color: kCyan, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_errorMsg != null) ...[
            _ErrorBanner(message: _errorMsg!),
            const SizedBox(height: 16),
          ],

          CustomInput(
            label: 'Código de verificación',
            controller: _tokenCtrl,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el código que recibiste' : null,
          ),
          const SizedBox(height: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva contraseña', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                  if (v.length < 8) return 'Mínimo 8 caracteres';
                  return null;
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kInputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCyan)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54, size: 20),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          CustomInput(
            label: 'Repetir contraseña',
            controller: _pass2Ctrl,
            obscure: true,
            validator: (v) {
              if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 32),
          CustomButton(label: 'Cambiar contraseña', onPressed: _confirmReset, loading: _loading),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _requestCode,
              child: const Text('¿No recibiste el código? Reenviar', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
      ],
    ),
  );
}