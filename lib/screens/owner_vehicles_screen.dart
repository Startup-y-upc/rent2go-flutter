import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common_widgets.dart';

class OwnerVehiclesScreen extends StatelessWidget {
  const OwnerVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicles = [
      {'name': 'Tesla Model 3', 'plate': 'ABC-1234', 'status': 'Activo',
       'img': 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=400&q=80'},
      {'name': 'Mini Cooper S', 'plate': 'XYZ-5678', 'status': 'Activo',
       'img': 'https://images.unsplash.com/photo-1510903117032-f1596c327647?w=400&q=80'},
      {'name': 'BMW Serie 3', 'plate': 'DEF-9012', 'status': 'En mantenimiento',
       'img': 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=400&q=80'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mis vehículos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: kCyan, borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.black),
                        SizedBox(width: 4),
                        Text('Añadir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final v = vehicles[i];
                  final active = v['status'] == 'Activo';
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                          child: CachedNetworkImage(imageUrl: v['img']!, width: 90, height: 70, fit: BoxFit.cover),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                                Text(v['plate']!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: active ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(v['status']!, style: TextStyle(color: active ? Colors.green : Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}