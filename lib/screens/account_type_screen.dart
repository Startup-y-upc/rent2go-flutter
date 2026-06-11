import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  String? _selected;

  Future<void> _continue() async {
    if (_selected == null) return;
    await AuthService.setAccountType(_selected!);
    if (mounted) context.push('/validate');
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
              const Rent2GoLogo(),
              const SizedBox(height: 24),
              StepIndicator(
                current: 2,
                total: 3,
                labels: const ['Datos', 'Tipo cuenta', 'Validación'],
              ),
              const SizedBox(height: 32),
              const Text(
                '¿Cómo vas a usar\nRent2Go?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes cambiarlo cuando quieras desde tu perfil.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              _TypeCard(
                title: 'ARRENDATARIO',
                subtitle: 'Quiero alquilar',
                description: 'Encuentra el coche perfecto cerca de ti. Resérvalo por horas o días.',
                perks: const [
                  'Buscar y reservar coches',
                  'Pagar de forma segura',
                  'Mensajes con propietarios',
                ],
                icon: Icons.directions_car_outlined,
                selected: _selected == 'arrendatario',
                onTap: () => setState(() => _selected = 'arrendatario'),
              ),
              const SizedBox(height: 16),
              _TypeCard(
                title: 'PROPIETARIO',
                subtitle: 'Quiero rentar mi auto',
                description: 'Convierte tu coche en ingresos. Tú decides precio y disponibilidad.',
                perks: const [
                  'Publicar tu vehículo',
                  'Gestionar reservas',
                  'Cobrar mensualmente',
                ],
                icon: Icons.car_rental_outlined,
                selected: _selected == 'propietario',
                onTap: () => setState(() => _selected = 'propietario'),
              ),
              const Spacer(),
              CustomButton(
                label: _selected == 'propietario'
                    ? 'Continuar como propietario'
                    : 'Continuar como arrendatario',
                onPressed: _selected != null ? _continue : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final List<String> perks;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.perks,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kCyan : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? kCyan.withOpacity(0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? kCyan : Colors.white54, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle,
                      style: TextStyle(
                          color: selected ? kCyan : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  ...perks.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_box_outlined,
                                size: 14,
                                color: selected ? kCyan : Colors.white38),
                            const SizedBox(width: 6),
                            Text(p,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            Radio<String>(
              value: title.toLowerCase(),
              groupValue: selected ? title.toLowerCase() : null,
              onChanged: (_) => onTap(),
              activeColor: kCyan,
            ),
          ],
        ),
      ),
    );
  }
}
