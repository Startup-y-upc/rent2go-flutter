import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'explore_screen.dart' show BottomNavBar;
import 'validate_account_screen.dart';

const kCyan = Color(0xFF00E5FF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _errorMsg;
  bool _resendingVerification = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Uint8List? _newImageBytes;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final cached = await AuthService.getCurrentUser();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _loading = false;
        _syncControllers();
      });
    }

    final fresh = await AuthService.fetchCurrentUser();
    if (fresh != null && mounted) {
      setState(() {
        _user = fresh;
        _loading = false;
        _syncControllers();
      });
    } else if (cached == null && mounted) {
      setState(() => _loading = false);
    }
  }

  void _syncControllers() {
    _nameCtrl.text = _user?.fullName ?? '';
    _phoneCtrl.text = _user?.phone ?? '';
  }

  void _goToBottomNav(int i) {
    switch (i) {
      case 0: context.go('/home'); break;
      case 1: context.go('/bookings'); break;
      case 2: context.go('/messages'); break;
      case 3: context.go('/profile'); break;
    }
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _newImageBytes = bytes);
  }

  /// Wires the previously dead "Foto de perfil / Verificar" stub to the same
  /// pick+upload flow already used by the avatar tap in edit mode (Phase 0
  /// parity finding: Kotlin's equivalent row already triggers an upload;
  /// Flutter's showed a "Verificar" label with no action).
  Future<void> _pickAndUploadProfilePhoto() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _saving = true);
    try {
      final updated = await AuthService.updateProfile(
        fullName: _user?.fullName ?? '',
        phone: _user?.phone ?? '',
        profileImageBytes: bytes,
        imageFilename: 'profile.jpg',
      );
      if (mounted) {
        setState(() {
          _user = updated;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Colors.green),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar al servidor.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// Combined re-verification action for BOTH the email row and the phone row.
  /// email_verified is a real backend flag with an actionable resend flow
  /// (POST /auth/verify/resend). phone_verified, per User.java's
  /// computePhoneVerified(), is a computed rule-based flag (Peru mobile format
  /// 9XXXXXXXX) with NO OTP/SMS action — it just reflects the phone value
  /// already on file. So "re-verify both" here means: (a) trigger the real
  /// email resend, and (b) refresh /auth/me so both badges — email and the
  /// computed phone flag — reflect the latest true state. There is no second
  /// backend call for phone; refreshing IS its "reverification". The feedback
  /// message intentionally avoids implying an SMS/OTP was sent for phone.
  Future<void> _reverifyEmailAndPhone() async {
    setState(() => _resendingVerification = true);
    try {
      await AuthService.resendVerificationEmail();
      final fresh = await AuthService.fetchCurrentUser();
      if (mounted) {
        setState(() {
          if (fresh != null) _user = fresh;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reenviando verificación de correo y actualizando estado...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar al servidor.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _resendingVerification = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'El nombre no puede estar vacío');
      return;
    }
    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      final updated = await AuthService.updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        profileImageBytes: _newImageBytes,
        imageFilename: 'profile.jpg',
      );
      if (mounted) {
        setState(() {
          _user = updated;
          _saving = false;
          _editing = false;
          _newImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _saving = false;
        _errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMsg = 'No se pudo conectar al servidor.';
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _newImageBytes = null;
      _errorMsg = null;
      _syncControllers();
    });
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F8),
        body: Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    final user = _user;
    final displayName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Usuario';
    final email = user?.email ?? '';
    final accountType = user?.accountType ?? '';
    final emailVerified = user?.emailVerified ?? false;
    final phoneVerified = user?.phoneVerified ?? false;
    // F4: KYC (DNI/Carnet) refleja el campo real kyc_verified del backend,
    // ya no un valor hardcodeado en true.
    final kycVerified = user?.kycVerified ?? false;
    final verifiedCount = (emailVerified ? 1 : 0) + (phoneVerified ? 1 : 0) + (kycVerified ? 2 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUser,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _editing ? _pickImage : null,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              backgroundImage: _newImageBytes != null
                                  ? MemoryImage(_newImageBytes!)
                                  : (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                                      ? NetworkImage(user.profileImageUrl!) as ImageProvider
                                      : null,
                              child: (_newImageBytes == null && (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty))
                                  ? Text(_initials(displayName), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 26, height: 26,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        accountType == 'OWNER' ? 'Propietario' : (accountType == 'RENTER' ? 'Arrendatario' : 'Usuario Rent2Go'),
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Confianza y verificación (diseño mejorado) ───────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: verifiedCount == 4 ? kCyan : Colors.grey, size: 22),
                          const SizedBox(width: 8),
                          const Text('Confianza y verificación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                          const Spacer(),
                          Text('$verifiedCount / 4', style: TextStyle(color: verifiedCount == 4 ? kCyan : Colors.grey[500], fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: verifiedCount / 4,
                        backgroundColor: Colors.grey.shade100,
                        color: kCyan,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 14),
                      _VerifyRow(
                        label: 'Identidad (DNI y licencia)',
                        verified: kycVerified,
                        action: kycVerified ? null : 'Verificar',
                        onAction: () => context.push('/verify-identity'),
                      ),
                      // Two separate rows (matches Kotlin's ProfileScreen.kt VerificationItem
                      // pattern). Tapping EITHER row re-verifies both at once: resends the
                      // email verification link AND refreshes /auth/me so both badges reflect
                      // the current true state. Phone has no independent OTP/SMS action — its
                      // badge is purely recomputed from the refreshed phone value on file.
                      _VerifyRow(
                        label: 'Correo verificado',
                        verified: emailVerified,
                        action: _resendingVerification ? 'Enviando...' : 'Reverificar',
                        onAction: _resendingVerification ? null : _reverifyEmailAndPhone,
                      ),
                      _VerifyRow(
                        label: 'Teléfono verificado',
                        verified: phoneVerified,
                        action: _resendingVerification ? 'Enviando...' : 'Reverificar',
                        onAction: _resendingVerification ? null : _reverifyEmailAndPhone,
                      ),
                      _VerifyRow(
                        label: 'Foto de perfil',
                        verified: user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty,
                        action: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) ? null : 'Verificar',
                        onAction: _pickAndUploadProfilePhoto,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Mis datos (editable) ──────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Mis datos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                          const Spacer(),
                          if (!_editing)
                            TextButton.icon(
                              onPressed: () => setState(() => _editing = true),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                              style: TextButton.styleFrom(foregroundColor: kCyan, padding: EdgeInsets.zero),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_errorMsg != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],

                      _editing
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _EditableField(label: 'Nombre completo', controller: _nameCtrl),
                                const SizedBox(height: 12),
                                _EditableField(
                                  label: 'Teléfono',
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _StaticField(label: 'Correo electrónico', value: email.isNotEmpty ? email : '—'),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _saving ? null : _cancelEdit,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade300),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _saving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kCyan,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: _saving
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                            : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StaticField(label: 'Nombre completo', value: displayName),
                                _StaticField(label: 'Correo electrónico', value: email.isNotEmpty ? email : '—'),
                                _StaticField(label: 'Teléfono', value: user?.phone.isNotEmpty == true ? user!.phone : '—'),
                                _StaticField(label: 'Usuario', value: user?.username.isNotEmpty == true ? user!.username : '—'),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _SectionCard(
                  child: Column(
                    children: [
                      _OptionRow(icon: Icons.notifications_outlined, label: 'Notificaciones'),
                      const Divider(height: 1),
                      _OptionRow(icon: Icons.lock_outline, label: 'Privacidad'),
                      const Divider(height: 1),
                      _OptionRow(
                        icon: Icons.description_outlined,
                        label: 'Términos y Condiciones',
                        onTap: () => context.push('/terms'),
                      ),
                      const Divider(height: 1),
                      _OptionRow(icon: Icons.help_outline, label: 'Ayuda'),
                      const Divider(height: 1),
                      _OptionRow(
                        icon: Icons.logout, label: 'Cerrar sesión', color: Colors.red,
                        onTap: () async {
                          await AuthService.logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(current: 3, onTap: _goToBottomNav),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
    child: child,
  );
}

class _VerifyRow extends StatelessWidget {
  final String label;
  final bool verified;
  final String? action;
  final VoidCallback? onAction;
  const _VerifyRow({required this.label, required this.verified, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(verified ? Icons.check_box : Icons.check_box_outline_blank, color: verified ? Colors.black : Colors.grey, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black)),
        const Spacer(),
        Text(verified ? 'Verificado' : 'Pendiente', style: TextStyle(color: verified ? Colors.green : Colors.orange[700], fontSize: 12, fontWeight: FontWeight.w500)),
        // Action stays tappable even when already verified (e.g. "Reverificar")
        // so re-verification/refresh flows aren't limited to the unverified state.
        if (action != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: TextStyle(color: Colors.blue[600], fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    ),
  );
}

class _StaticField extends StatelessWidget {
  final String label, value;
  const _StaticField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black)),
        ),
      ],
    ),
  );
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCyan)),
        ),
      ),
    ],
  );
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _OptionRow({required this.icon, required this.label, this.color, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? Colors.black, size: 22),
    title: Text(label, style: TextStyle(color: color ?? Colors.black, fontSize: 14, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    onTap: onTap ?? () {},
  );
}