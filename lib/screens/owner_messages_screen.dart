import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';

class OwnerMessagesScreen extends StatefulWidget {
  const OwnerMessagesScreen({super.key});

  @override
  State<OwnerMessagesScreen> createState() => _OwnerMessagesScreenState();
}

class _OwnerMessagesScreenState extends State<OwnerMessagesScreen> {
  String _selectedFilter = 'Todos';
  final List<String> _filters = ['Todos', 'Activos', 'Sin leer'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mensajes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildChatTile(
                  context,
                  name: 'Lucia M.',
                  car: 'Tesla Model 3',
                  lastMsg: 'Perfecto, te espero a las 10h en Goya 24',
                  time: '14:22',
                  isRead: true,
                  isOnline: true,
                  avatar: 'https://i.pravatar.cc/150?u=lucia',
                ),
                _buildChatTile(
                  context,
                  name: 'Andres R.',
                  car: 'Mini Cooper',
                  lastMsg: 'TÚ: Gracias por todo, ¡gran coche!',
                  time: 'Ayer',
                  isRead: true,
                  isOnline: false,
                  avatar: 'https://i.pravatar.cc/150?u=andres',
                ),
                _buildChatTile(
                  context,
                  name: 'Soporte Rent2Go',
                  car: 'Atención al cliente',
                  lastMsg: 'Hemos actualizado tu cobertura de seguro.',
                  time: 'Hace 2 días',
                  isRead: false,
                  isOnline: false,
                  avatar: '',
                  isSupport: true,
                ),
                _buildChatTile(
                  context,
                  name: 'Carla V.',
                  car: 'BMW Serie 3',
                  lastMsg: '¿Te viene bien recogerlo a las 9:00?',
                  time: 'Hace 3 días',
                  isRead: true,
                  isOnline: false,
                  avatar: 'https://i.pravatar.cc/150?u=carla',
                ),
                _buildChatTile(
                  context,
                  name: 'Marco T.',
                  car: 'VW Golf',
                  lastMsg: '¡Buen viaje!',
                  time: 'Hace 1 semana',
                  isRead: true,
                  isOnline: false,
                  avatar: 'https://i.pravatar.cc/150?u=marco',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar mensajes', style: TextStyle(color: Colors.black)),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Escribe el nombre del cliente...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: UnderlineInputBorder(borderSide: BorderSide(color: kCyan)),
          ),
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? Colors.black : Colors.grey.shade300),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  color: active ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context, {
    required String name,
    required String car,
    required String lastMsg,
    required String time,
    required bool isRead,
    required bool isOnline,
    required String avatar,
    bool isSupport = false,
  }) {
    if (_selectedFilter == 'Sin leer' && isRead) return const SizedBox.shrink();

    return ListTile(
      onTap: () {
        context.push('/chat', extra: {
          'name': name,
          'car': car,
          'isOnline': isOnline,
        });
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Icon(isSupport ? Icons.headset_mic : Icons.person, color: Colors.grey)
                : null,
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF0F4F8), width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                ),
                Text(
                  car,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
            )
          else
            Text(time, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isRead ? Colors.grey.shade600 : Colors.black,
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (isRead && lastMsg.startsWith('TÚ:'))
              const Icon(Icons.done_all, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
