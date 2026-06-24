import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class ValidateAccountScreen extends StatefulWidget {
  const ValidateAccountScreen({super.key});
  @override
  State<ValidateAccountScreen> createState() => _ValidateAccountScreenState();
}

class _ValidateAccountScreenState extends State<ValidateAccountScreen> {
  Uint8List? _licenciaBytes, _dniAnvBytes, _dniRevBytes;
  bool _loading = false;
  String? _errorMsg;
  final _picker = ImagePicker();
  late Box _docsBox;

  @override
  void initState() {
    super.initState();
    _docsBox = Hive.box('user_docs');
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
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final draft = Hive.box('register_draft');
      final name = draft.get('name',  defaultValue: '');
      final email = draft.get('email', defaultValue: '');
      final phone = draft.get('phone', defaultValue: '');
      final password = draft.get('password', defaultValue: '');
      final accountType = draft.get('accountType', defaultValue: 'RENTER');

      await AuthService.register(
        email: email,
        password: password,
        username: email.split('@').first,
        fullName: name,
        phone: phone,
        accountType: accountType,
      );

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

  void _cancel() {
    context.go('/register');
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
              StepIndicator(
                current: 3,
                total: 3,
                labels: const ['Datos', 'Tipo cuenta', 'Validación'],
              ),
              const SizedBox(height: 32),
              const Text('Valida tu cuenta',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Sube una foto clara de tu DNI y de tu licencia de conducir.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),

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
                const SizedBox(height: 12),
              ],

              Expanded(
                child: ListView(children: [
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
              const SizedBox(height: 16),
              CustomButton(label: 'Continuar', onPressed: _allUploaded ? _submit : null, loading: _loading),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancelar y volver al registro',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
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
        border: Border.all(color: uploaded ? kCyan.withOpacity(0.5) : Colors.white12),
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