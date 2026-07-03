import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// US50/US51/US52: bandeja de notificaciones in-app. Orden cronológico
/// (el backend ya devuelve más reciente primero), estado leído/no leído
/// visible con ícono + texto (no solo color, WCAG AA), y marcar-como-leída
/// al tocar cada elemento.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationData> _notifications = [];
  int? _userId;
  final Set<int> _markingRead = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }
    _userId = user.userId;
    try {
      final paged = await NotificationService.getMyNotifications(userId: user.userId);
      if (!mounted) return;
      setState(() {
        _notifications = paged.content;
        _loading = false;
      });
    } on NotificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar tus notificaciones.';
      });
    }
  }

  Future<void> _markAsRead(NotificationData notification) async {
    if (notification.isRead || _userId == null) return;
    setState(() => _markingRead.add(notification.id));
    try {
      final updated = await NotificationService.markAsRead(
        notificationId: notification.id,
        userId: _userId!,
      );
      if (!mounted) return;
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) _notifications[index] = updated;
        _markingRead.remove(notification.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingRead.remove(notification.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo marcar como leída.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B2F),
        elevation: 0,
        leading: IconButton(
          key: const Key('notifications_back_button'),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(key: Key('notifications_loading'), child: CircularProgressIndicator(color: kCyan));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            key: const Key('notifications_error'),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }
    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Center(
            key: Key('notifications_empty'),
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.notifications_none_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tienes notificaciones por ahora', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const Key('notifications_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final n = _notifications[index];
        final isMarking = _markingRead.contains(n.id);
        return GestureDetector(
          key: Key('notification_row_${n.id}'),
          onTap: isMarking ? null : () => _markAsRead(n),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: n.isRead ? Colors.white : kCyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: n.isRead ? Colors.grey.shade200 : kCyan.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono + texto para distinguir leído/no-leído — no solo color (WCAG AA).
                Icon(
                  n.isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                  color: n.isRead ? Colors.grey : kCyan,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.message,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isMarking)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (n.createdAt != null)
                            Text(n.createdAt!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(
                            n.isRead ? 'Leída' : 'No leída',
                            style: TextStyle(
                              color: n.isRead ? Colors.grey.shade500 : kCyan,
                              fontSize: 11,
                              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
