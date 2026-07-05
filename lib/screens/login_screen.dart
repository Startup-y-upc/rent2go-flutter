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
  bool _remember     = false;
  bool _loading       = false;
  bool _obscurePass   = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final saved = await AuthService.getSavedEmail();
    final remembered = await AuthService.getRememberMe();
    if (saved != null && mounted) {
      setState(() {
        _emailCtrl.text = saved;
        _remember = remembered;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final user = await AuthService.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        rememberMe: _remember,
      );

      if (mounted) {
        setState(() => _loading = false);
        if (user.accountType == 'OWNER') {
          context.go('/owner');
        } else {
          context.go('/home');
        }
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Inicia sesión para gestionar tus alquileres en Rent2Go.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 36),

                      if (_errorMsg != null) ...[
                        Container(
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
                              Expanded(
                                child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

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

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contraseña', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            style: const TextStyle(color: Colors.white),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                              if (v.length < 6) return 'Mínimo 6 caracteres';
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

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: (v) => setState(() => _remember = v!),
                            activeColor: kCyan,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          const Text('Recuérdame', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push('/recover'),
                            child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: kCyan, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(label: 'Iniciar sesión', onPressed: _login, loading: _loading),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/register'),
                          child: const Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '¿No tienes cuenta? ', style: TextStyle(color: Colors.white54)),
                              TextSpan(text: 'Crear cuenta', style: TextStyle(color: kCyan)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
