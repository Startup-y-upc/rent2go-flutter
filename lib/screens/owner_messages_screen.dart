import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OwnerMessagesScreen extends StatelessWidget {
  const OwnerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [
      {'name': 'Marta L.', 'car': 'Tesla Model 3', 'msg': '¡Hola Diego! ¿Confirmamos la recogida?', 'time': '14:18', 'online': true},
      {'name': 'Carlos R.', 'car': 'Mini Cooper S', 'msg': 'Gracias por la rápida respuesta', 'time': 'Ayer', 'online': false},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Text('Mensajes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                itemBuilder: (_, i) {
                  final c = chats[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade200,
                      child: Text((c['name'] as String)[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    ),
                    title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    subtitle: Text(c['msg'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    trailing: Text(c['time'] as String, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    onTap: () => context.push('/chat', extra: {'name': c['name'], 'car': c['car'], 'isOnline': c['online']}),
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