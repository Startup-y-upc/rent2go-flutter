import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

class OwnerEarningsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const OwnerEarningsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: onBack),
                  const Text('Mis ganancias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF1B1B2F), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Este mes', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    const SizedBox(height: 6),
                    const Text('1,284.50 €', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _earningRow('Tesla Model 3 · Lucía M.', '12 May', '98,00 €'),
                  _earningRow('Mini Cooper S · Carlos R.', '8 May', '76,00 €'),
                  _earningRow('BMW Serie 3 · Marta L.', '2 May', '195,00 €'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningRow(String title, String date, String amount) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black)),
              Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      ],
    ),
  );
}