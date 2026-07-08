import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class ValidateAccountScreen extends StatefulWidget {
  /// Cuando es true, la pantalla se abre desde un perfil ya autenticado
  /// (re-verificación, F8) en vez de desde el flujo de registro: se omite
  /// AuthService.register() y se envían los documentos directamente para el
  /// usuario de la sesión activa.
  final bool reVerifyMode;
  const ValidateAccountScreen({super.key, this.reVerifyMode = false});
  @override
  State<ValidateAccountScreen> createState() => _ValidateAccountScreenState();
}

class _ValidateAccountScreenState extends State<ValidateAccountScreen> {
  Uint8List? _licenciaBytes, _dniAnvBytes, _dniRevBytes;
  bool _loading = false;
  String? _errorMsg;
  final _picker = ImagePicker();
  late Box _docsBox;
  final _formKey = GlobalKey<FormState>();
  final _idNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _docsBox = Hive.box('user_docs');
    _idNumberCtrl.text = _docsBox.get('idNumber', defaultValue: '');
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    super.dispose();
  }

  String? _validateIdNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu número de documento';
    if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return 'Solo se permiten números';
    if (v.trim().length < 8 || v.trim().length > 12) {
      return 'Debe tener entre 8 y 12 dígitos';
    }
    return null;
  }

  Future<void> _pick(String key) async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!kIsWeb) await _docsBox.put('${key}_path', img.path);
    setState(() {
      switch (key) {
        case 'licencia': _licenciaBytes = bytes;
        case 'dni_anv':  _dniAnvBytes = bytes;
        case 'dni_rev':  _dniRevBytes = bytes;
      }
    });
  }

  void _delete(String key) {
    if (!kIsWeb) _docsBox.delete('${key}_path');
    setState(() {
      switch (key) {
        case 'licencia': _licenciaBytes = null;
        case 'dni_anv':  _dniAnvBytes = null;
        case 'dni_rev':  _dniRevBytes = null;
      }
    });
  }

  bool get _allUploaded =>
      _licenciaBytes != null && _dniAnvBytes != null && _dniRevBytes != null;

  Future<void> _submit() async {
    if (!_allUploaded) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    if (widget.reVerifyMode) {
      await _submitReVerify();
      return;
    }

    try {
      final draft = Hive.box('register_draft');
      final name = draft.get('name',  defaultValue: '');
      final email = draft.get('email', defaultValue: '');
      final phone = draft.get('phone', defaultValue: '');
      final password = draft.get('password', defaultValue: '');
      final accountType = draft.get('accountType', defaultValue: 'RENTER');
      final idNumber = _idNumberCtrl.text.trim();
      await _docsBox.put('idNumber', idNumber);

      final user = await AuthService.register(
        email: email,
        password: password,
        username: email.split('@').first,
        fullName: name,
        phone: phone,
        accountType: accountType,
      );

      // US07: envía los documentos de verificación capturados en esta pantalla
      // al backend (POST /auth/kyc/multipart) ahora que ya existe una sesión
      // (register() inicia sesión internamente). El número de documento (DNI)
      // ahora se captura con un campo real en este mismo paso -- ya no se usa
      // el teléfono como valor provisional (ver decision_history.json).
      try {
        await AuthService.submitKycMultipart(
          userId: user.userId,
          fullName: name,
          idNumber: idNumber,
          dniFrontBytes: _dniAnvBytes!,
          dniBackBytes: _dniRevBytes!,
          driverLicenseBytes: _licenciaBytes,
        );
      } catch (kycError) {
        // No revertir el registro si falla el envío de KYC: la cuenta ya existe
        // y el usuario puede reintentar la verificación después. Se informa sin
        // bloquear la navegación.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu cuenta fue creada, pero no se pudieron enviar los documentos de verificación. Podrás reintentarlo más tarde.'),
            ),
          );
        }
      }

      Hive.box('register_draft').clear();
      _docsBox.clear();

      if (mounted) {
        setState(() => _loading = false);
        if (accountType == 'OWNER') {
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

  /// F8: re-envío de documentos KYC para un usuario ya autenticado (no pasa
  /// por register()). Usa el mismo endpoint POST /auth/kyc/multipart.
  Future<void> _submitReVerify() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        setState(() {
          _loading = false;
          _errorMsg = 'No hay sesión activa.';
        });
        return;
      }
      final idNumber = _idNumberCtrl.text.trim();
      await AuthService.submitKycMultipart(
        userId: user.userId,
        fullName: user.fullName,
        idNumber: idNumber,
        dniFrontBytes: _dniAnvBytes!,
        dniBackBytes: _dniRevBytes!,
        driverLicenseBytes: _licenciaBytes,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documentos enviados para revisión'), backgroundColor: Colors.green),
      );
      context.pop();
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'No se pudieron enviar los documentos. Intenta nuevamente.';
      });
    }
  }

  void _cancel() {
    if (widget.reVerifyMode) {
      context.pop();
    } else {
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Row(
                children: [
                  const Rent2GoLogo(),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!widget.reVerifyMode)
                const StepIndicator(
                  current: 3,
                  total: 3,
                  labels: ['Datos', 'Tipo cuenta', 'Validación'],
                ),
              const SizedBox(height: 32),
              Text(widget.reVerifyMode ? 'Verifica tu identidad' : 'Valida tu cuenta',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Sube una foto clara de tu DNI y de tu licencia de conducir.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),

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
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(children: [
                  const Text('Número de documento (DNI)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('id_number_field'),
                    controller: _idNumberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: _validateIdNumber,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '12345678',
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
                  const SizedBox(height: 18),
                  _DocCard(label: 'Licencia de conducir', subtitle: 'Vigente, en color y completa',
                      bytes: _licenciaBytes, onPick: () => _pick('licencia'), onDelete: () => _delete('licencia')),
                  const SizedBox(height: 14),
                  _DocCard(label: 'DNI · Anverso',
                      bytes: _dniAnvBytes, onPick: () => _pick('dni_anv'), onDelete: () => _delete('dni_anv')),
                  const SizedBox(height: 14),
                  _DocCard(label: 'DNI · Reverso',
                      bytes: _dniRevBytes, onPick: () => _pick('dni_rev'), onDelete: () => _delete('dni_rev')),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(label: 'Continuar', onPressed: _allUploaded ? _submit : null, loading: _loading),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cancel,
                  child: Text(widget.reVerifyMode ? 'Cancelar' : 'Cancelar y volver al registro',
                      style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Uint8List? bytes;
  final VoidCallback onPick, onDelete;
  const _DocCard({required this.label, this.subtitle, required this.bytes,
      required this.onPick, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final uploaded = bytes != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: uploaded ? kCyan.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const Spacer(),
          if (uploaded) ...[
            const Icon(Icons.check_circle, color: kCyan, size: 14),
            const SizedBox(width: 4),
            const Text('subido', style: TextStyle(color: kCyan, fontSize: 11)),
          ],
        ]),
        const SizedBox(height: 12),
        uploaded
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes!, height: 100, width: double.infinity, fit: BoxFit.cover))
            : Container(
                height: 80,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.image_outlined, color: Colors.white38, size: 32))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_outlined, size: 16, color: Colors.white70),
              label: const Text('Subir foto', style: TextStyle(color: Colors.white70, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: uploaded ? onDelete : null,
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            label: const Text('Borrar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12)),
          ),
        ]),
      ]),
    );
  }
}