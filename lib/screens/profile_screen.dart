import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1B2A),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          child: const Icon(Icons.person,
                              size: 44, color: Colors.white70),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Diego Sánchez',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Miembro desde 2023',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(value: '18', label: 'Viajes'),
                        _divider(),
                        _StatItem(value: '4.92', label: 'Valoración'),
                        _divider(),
                        _StatItem(value: '100%', label: 'Aceptación'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Confianza y verificación',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black)),
                        const Spacer(),
                        Text('3 / 4',
                            style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _VerifyRow(label: 'Identidad (DNI)', verified: true),
                    _VerifyRow(label: 'Carnet de conducir', verified: true),
                    _VerifyRow(label: 'Email y teléfono', verified: true),
                    _VerifyRow(
                        label: 'Foto de perfil',
                        verified: false,
                        action: 'Verificar'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Editar datos personales',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black)),
                    const SizedBox(height: 16),
                    _EditField(label: 'Nombre completo', value: 'Diego Sánchez'),
                    _EditField(
                        label: 'Correo electrónico',
                        value: 'diego@email.com'),
                    _EditField(label: 'Teléfono', value: '+34 612 345 678'),
                    _EditField(label: 'Ciudad', value: 'Madrid, España'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _SectionCard(
                child: Column(
                  children: [
                    _OptionRow(
                        icon: Icons.swap_horiz,
                        label: 'Modo Propietario',
                        onTap: () => context.go('/owner')),
                    const Divider(height: 1),
                    _OptionRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notificaciones'),
                    const Divider(height: 1),
                    _OptionRow(
                        icon: Icons.lock_outline, label: 'Privacidad'),
                    const Divider(height: 1),
                    _OptionRow(
                        icon: Icons.help_outline, label: 'Ayuda'),
                    const Divider(height: 1),
                    _OptionRow(
                      icon: Icons.logout,
                      label: 'Cerrar sesión',
                      color: Colors.red,
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
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          if (i == 0) context.go('/home');
          if (i == 1) context.go('/bookings');
          if (i == 2) context.go('/messages');
        },
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 36, color: Colors.white24);
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold)),
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );
}

class _VerifyRow extends StatelessWidget {
  final String label;
  final bool verified;
  final String? action;
  const _VerifyRow(
      {required this.label, required this.verified, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          verified ? Icons.check_box : Icons.check_box_outline_blank,
          color: verified ? Colors.black : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black)),
        const Spacer(),
        if (action != null)
          Text(action!,
              style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _EditField extends StatelessWidget {
  final String label, value;
  const _EditField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.black)),
        ),
      ],
    ),
  );
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _OptionRow(
      {required this.icon, required this.label, this.color, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? Colors.black, size: 22),
    title: Text(label,
        style: TextStyle(
            color: color ?? Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    onTap: onTap ?? () {},
  );
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.explore_outlined, 'Explorar'),
      (Icons.calendar_today_outlined, 'Reservas'),
      (Icons.chat_bubble_outline, 'Mensajes'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: items.asMap().entries.map((e) {
            final active = e.key == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(e.key),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.value.$1,
                          color: active ? Colors.black : Colors.grey,
                          size: 22),
                      const SizedBox(height: 4),
                      Text(e.value.$2,
                          style: TextStyle(
                              fontSize: 11,
                              color: active ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}