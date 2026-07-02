import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/message_models.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

class OwnerMessagesScreen extends StatefulWidget {
  const OwnerMessagesScreen({super.key});
  @override
  State<OwnerMessagesScreen> createState() => _OwnerMessagesScreenState();
}

class _OwnerMessagesScreenState extends State<OwnerMessagesScreen> {
  int _filter = 0; // 0=Todos 1=Activos 2=Sin leer
  List<ConversationData> _conversations = [];
  int? _myUserId;
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final me = await AuthService.getCurrentUser();
    _myUserId = me?.userId;
    if (_myUserId == null) {
      setState(() { _loading = false; _errorMsg = 'No se pudo identificar tu sesión.'; });
      return;
    }
    try {
      final convs = await MessageService.getUserConversations(_myUserId!);
      convs.sort((a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(a.lastMessageAt ?? a.createdAt));
      if (mounted) setState(() { _conversations = convs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'No se pudieron cargar tus mensajes.'; });
    }
  }

  List<ConversationData> get _filtered {
    if (_filter == 1) return _conversations.where((c) => c.status.toUpperCase() == 'OPEN' || c.status.toUpperCase() == 'ACTIVE').toList();
    if (_filter == 2) return _conversations;
    return _conversations;
  }

  void _openChat(ConversationData c) {
    if (_myUserId == null) return;
    final iAmOwner = c.ownerId == _myUserId;
    context.push('/chat', extra: {
      'name': iAmOwner ? 'Arrendatario #${c.renterId}' : 'Propietario #${c.ownerId}',
      'car': c.subject,
      'isOnline': false,
      'ownerId': c.ownerId,
      'renterId': c.renterId,
      'vehicleId': c.vehicleId,
      'reservationId': c.reservationId,
    });
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
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
                  const Text('Mensajes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _load),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['Todos', 'Activos', 'Sin leer'].asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _filter == e.key ? Colors.black : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(e.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _filter == e.key ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMsg != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMsg!, style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _load, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : _filtered.isEmpty
                          ? Center(child: Text('Aún no tienes conversaciones', style: TextStyle(color: Colors.grey[400])))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                                itemBuilder: (_, i) {
                                  final c = _filtered[i];
                                  final iAmOwner = c.ownerId == _myUserId;
                                  final otherLabel = iAmOwner ? 'Arrendatario #${c.renterId}' : 'Propietario #${c.ownerId}';
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Text(otherLabel[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 18)),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(otherLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black), overflow: TextOverflow.ellipsis)),
                                        Text(_formatTime(c.lastMessageAt ?? c.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (c.subject.isNotEmpty)
                                          Row(children: [
                                            const Icon(Icons.directions_car, size: 11, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(c.subject, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ]),
                                        Text(
                                          c.lastMessagePreview?.isNotEmpty == true ? c.lastMessagePreview! : 'Sin mensajes aún',
                                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    onTap: () => _openChat(c),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}