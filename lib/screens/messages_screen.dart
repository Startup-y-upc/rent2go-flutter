import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _tab = 2;
  int _filter = 0; // 0=Todos 1=Activos 2=Sin leer

  final _chats = [
    _Chat(
      name: 'Lucía M.',
      car: 'Tesla Model 3',
      lastMsg: 'Perfecto, te espero a las 10h en Goya 24 ✓',
      time: '14:22',
      unread: 0,
      isOnline: true,
    ),
    _Chat(
      name: 'Andrés R.',
      car: 'Mini Cooper',
      lastMsg: 'Tú: Gracias por todo, gran coche!',
      time: '11:05',
      unread: 0,
      isOnline: false,
    ),
    _Chat(
      name: 'Soporte Rent2Go',
      car: '',
      lastMsg: 'Hemos actualizado tu cobertura.',
      time: 'Ayer',
      unread: 1,
      isOnline: false,
    ),
    _Chat(
      name: 'Carla V.',
      car: 'BMW Serie 1',
      lastMsg: '¿Te viene bien recogerlo a las 9?',
      time: 'Ayer',
      unread: 2,
      isOnline: false,
    ),
    _Chat(
      name: 'Marco T.',
      car: 'VW Golf',
      lastMsg: '¡Buen viaje!',
      time: 'Lun',
      unread: 0,
      isOnline: false,
    ),
  ];

  List<_Chat> get _filtered {
    if (_filter == 1) return _chats.where((c) => c.isOnline).toList();
    if (_filter == 2) return _chats.where((c) => c.unread > 0).toList();
    return _chats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mensajes',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const Spacer(),
                  const Icon(Icons.search, color: Colors.black),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['Todos', 'Activos', 'Sin leer']
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _filter == e.key
                                    ? Colors.black
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _filter == e.key
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (_, i) {
                  final chat = _filtered[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            chat.name[0],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                                fontSize: 18),
                          ),
                        ),
                        if (chat.isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(chat.name,
                            style: TextStyle(
                                fontWeight: chat.unread > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black)),
                        const Spacer(),
                        Text(chat.time,
                            style: TextStyle(
                                fontSize: 12,
                                color: chat.unread > 0
                                    ? Colors.black
                                    : Colors.grey)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (chat.car.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.directions_car,
                                size: 11, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(chat.car,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ]),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.lastMsg,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: chat.unread > 0
                                        ? Colors.black87
                                        : Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.unread > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    chat.unread.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => context.push('/chat', extra: {'name': chat.name, 'car': chat.car, 'isOnline': chat.isOnline}),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
          current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

class _Chat {
  final String name, car, lastMsg, time;
  final int unread;
  final bool isOnline;
  const _Chat({
    required this.name,
    required this.car,
    required this.lastMsg,
    required this.time,
    required this.unread,
    required this.isOnline,
  });
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
                          color: active ? Colors.black : Colors.grey, size: 22),
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