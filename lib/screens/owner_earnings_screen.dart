import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class OwnerEarningsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const OwnerEarningsScreen({
    super.key,
    required this.onBack,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChartSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'Por vehículo · mayo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildVehiclesEarnings(),
                  const SizedBox(height: 100),
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
      padding: const EdgeInsets.fromLTRB(20, 60, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: onBack,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ganancias',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Saldo disponible',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '2.847,30',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '€',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Text(
            'Próximo ingreso · vie 16 May',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Retirar', true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton('Facturas', false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos 7 meses',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Text(
            '6.024,80 €',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          // Mock chart
          Container(
            height: 150,
            width: double.infinity,
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(40, 'Nov'),
                _buildBar(60, 'Dic'),
                _buildBar(45, 'Ene'),
                _buildBar(80, 'Feb'),
                _buildBar(90, 'Mar'),
                _buildBar(70, 'Abr'),
                _buildBar(100, 'May', isActive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor, String label, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: heightFactor,
          decoration: BoxDecoration(
            color: isActive ? kCyan : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.black : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildVehiclesEarnings() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildVehicleRow('Tesla Model 3', '748 €', '12 viajes', 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=200&q=80'),
          const Divider(height: 1),
          _buildVehicleRow('Mini Cooper S', '412 €', '9 viajes', 'https://images.unsplash.com/photo-1510903117032-f1596c327647?w=600&q=80'),
          const Divider(height: 1),
          _buildVehicleRow('Volkswagen Golf', '124 €', '10 viajes', 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=200&q=80'),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(String name, String amount, String trips, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(imageUrl, width: 64, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                Text(trips, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
