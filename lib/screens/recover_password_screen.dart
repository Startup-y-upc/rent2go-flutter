import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
    }
  }

  @override
  void dispose() {
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                const Rent2GoLogo(),
                const SizedBox(height: 40),
                const Text(
                  'Recuperar\ncontraseña',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                CustomInput(
                  label: 'Nueva contraseña',
                  controller: _passCtrl,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
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
                const Spacer(),
                CustomButton(
                  label: 'Cambiar contraseña',
                  onPressed: _submit,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: TextStyle(color: Colors.white54)),
                        TextSpan(
                            text: 'Crear cuenta',
                            style: TextStyle(color: kCyan)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
