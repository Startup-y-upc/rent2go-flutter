import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';

class OwnerProfileScreen extends StatelessWidget {
  final VoidCallback onNavigateToEarnings;

  const OwnerProfileScreen({
    super.key,
    required this.onNavigateToEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVerificationSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'Mi negocio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBusinessSection(),
                  const SizedBox(height: 24),
                  _buildEarningsButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diego Sánchez',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Anfitrión desde 2023',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('3', 'Vehículos'),
                _buildStatItem('64', 'Viajes'),
                _buildStatItem('4.49', 'Rating'),
                _buildStatItem('100%', 'Respuesta'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Verificación de cuenta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildCheckItem('DNI', true),
          const Divider(height: 1, indent: 48),
          _buildCheckItem('Email', true),
          const Divider(height: 1, indent: 48),
          _buildCheckItem('Teléfono', true),
          const Divider(height: 1, indent: 48),
          _buildCheckItem('Cuenta bancaria', true),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: checked ? Colors.black : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBusinessSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildBusinessItem('Tesla Model 3', '3 publicados', 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=200&q=80'),
          const Divider(height: 1),
          _buildBusinessItem('Mini Cooper S', '1 publicados', 'https://images.unsplash.com/photo-1510903117032-f1596c327647?w=600&q=80'),
          const Divider(height: 1),
          _buildBusinessItem('Volkswagen Golf', '5 publicados', 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=200&q=80'),
        ],
      ),
    );
  }

  Widget _buildBusinessItem(String title, String subtitle, String imageUrl) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(imageUrl, width: 48, height: 36, fit: BoxFit.cover),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {},
    );
  }

  Widget _buildEarningsButton() {
    return GestureDetector(
      onTap: onNavigateToEarnings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text(
              'Ganancias',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
