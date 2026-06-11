import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  late Box _draft;

  @override
  void initState() {
    super.initState();
    _draft = Hive.box('register_draft');
    _loadDraft();
  }

  void _loadDraft() {
    _nameCtrl.text  = _draft.get('name',  defaultValue: '');
    _emailCtrl.text = _draft.get('email', defaultValue: '');
    _phoneCtrl.text = _draft.get('phone', defaultValue: '');
    final savedStep = _draft.get('step',  defaultValue: 1);
    setState(() => _step = savedStep);
  }

  void _saveDraft() {
    _draft.put('name',  _nameCtrl.text);
    _draft.put('email', _emailCtrl.text);
    _draft.put('phone', _phoneCtrl.text);
    _draft.put('step',  _step);
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step++);
    _saveDraft();
    if (_step == 2) context.push('/account-type');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
                const SizedBox(height: 24),
                const Text(
                  'Crea tu cuenta\nen Rent2Go.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Empezamos con tus datos básicos. Después elegirás cómo usar la app.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                StepIndicator(
                  current: _step,
                  total: 3,
                  labels: const ['Datos', 'Tipo cuenta', 'Validación'],
                ),
                const SizedBox(height: 32),
                CustomInput(
                  label: 'Nombre completo',
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),
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
                  label: 'Teléfono',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ingresa tu teléfono' : null,
                ),
                const SizedBox(height: 16),
                CustomInput(
                  label: 'Contraseña',
                  controller: _passCtrl,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const Spacer(),
                CustomButton(label: 'Continuar', onPressed: _nextStep),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: TextStyle(color: Colors.white54)),
                        TextSpan(
                            text: 'Iniciar sesión',
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
