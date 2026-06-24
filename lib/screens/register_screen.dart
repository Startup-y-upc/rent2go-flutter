import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  String? _errorMsg;
  late Box _draft;

  static final _emailRegex =
      RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[a-zA-Z]{2,}$');

  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasDigit = RegExp(r'[0-9]');
  static final _hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/~`+=;]');

  @override
  void initState() {
    super.initState();
    _draft = Hive.box('register_draft');
    _loadDraft();
  }

  void _loadDraft() {
    _nameCtrl.text = _draft.get('name', defaultValue: '');
    _emailCtrl.text = _draft.get('email', defaultValue: '');
    _phoneCtrl.text = _draft.get('phone', defaultValue: '');
  }

  void _saveDraft() {
    _draft.put('name',  _nameCtrl.text.trim());
    _draft.put('email', _emailCtrl.text.trim());
    _draft.put('phone', _phoneCtrl.text.trim());
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu correo';
    if (!_emailRegex.hasMatch(v.trim())) return 'Correo no válido (ej: nombre@dominio.com)';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu teléfono';
    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Solo se permiten números';
    if (v.length < 7) return 'Teléfono demasiado corto';
    if (v.length > 9) return 'Teléfono demasiado largo';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!_hasUpper.hasMatch(v)) return 'Debe incluir al menos 1 mayúscula';
    if (!_hasLower.hasMatch(v)) return 'Debe incluir al menos 1 minúscula';
    if (!_hasDigit.hasMatch(v)) return 'Debe incluir al menos 1 número';
    if (!_hasSpecial.hasMatch(v)) return 'Debe incluir al menos 1 carácter especial (!@#\$%...)';
    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      _saveDraft();
      _draft.put('password', _passCtrl.text);

      if (mounted) {
        setState(() => _loading = false);
        context.push('/account-type');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Ocurrió un error. Intenta de nuevo.';
      });
    }
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
        child: Form(
          key: _formKey,
          
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                current: 1,
                total: 3,
                labels: const ['Datos', 'Tipo cuenta', 'Validación'],
              ),
              const SizedBox(height: 32),

              if (_errorMsg != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              CustomInput(
                label: 'Nombre completo',
                controller: _nameCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 16),

              CustomInput(
                label: 'Correo electrónico',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teléfono',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: _validatePhone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '987654321',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: kInputBg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kCyan),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contraseña',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: const TextStyle(color: Colors.white),
                    validator: _validatePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kInputBg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kCyan),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PasswordRules(password: _passCtrl.text),
                ],
              ),

              const SizedBox(height: 32),
              CustomButton(
                label: 'Continuar',
                onPressed: _continue,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '¿Ya tienes cuenta? ',
                          style: TextStyle(color: Colors.white54)),
                      TextSpan(text: 'Iniciar sesión', style: TextStyle(color: kCyan)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  final String password;
  const _PasswordRules({required this.password});

  bool get _hasLen => password.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(password);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(password);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(password);
  bool get _hasSpecial => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/~`+=;]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _RuleChip(label: '8+ caracteres', met: _hasLen),
        _RuleChip(label: 'Mayúscula', met: _hasUpper),
        _RuleChip(label: 'Minúscula', met: _hasLower),
        _RuleChip(label: 'Número', met: _hasDigit),
        _RuleChip(label: 'Carácter especial', met: _hasSpecial),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool met;
  const _RuleChip({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 13,
          color: met ? kCyan : Colors.white30,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: met ? kCyan : Colors.white30,
          ),
        ),
      ],
    );
  }
}