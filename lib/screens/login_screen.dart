import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _remember   = false;
  bool _loading    = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final saved = await AuthService.getSavedEmail();
    if (saved != null && mounted) {
      setState(() {
        _emailCtrl.text = saved;
        _remember = true;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 1));

    await AuthService.saveSession(
      token: 'TOKEN_DEMO',
      email: _emailCtrl.text.trim(),
      remember: _remember,
    );

    if (mounted) {
      setState(() => _loading = false);
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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
                  'Bienvenido\nde vuelta.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Inicia sesión para gestionar tus alquileres en Rent2Go.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 36),
                CustomInput(
                  label: 'Correo electrónico',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu correo';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'Contraseña',
                  controller: _passCtrl,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v!),
                      activeColor: kCyan,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    const Text('Recuérdame',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/recover'),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: kCyan, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                CustomButton(
                  label: 'Iniciar sesión',
                  onPressed: _login,
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
