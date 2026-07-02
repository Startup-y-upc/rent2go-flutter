import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_models.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String car;
  final bool isOnline;
  final int ownerId;
  final int renterId;
  final int? vehicleId;
  final int? reservationId;

  const ChatScreen({
    super.key,
    required this.name,
    required this.car,
    required this.isOnline,
    required this.ownerId,
    required this.renterId,
    this.vehicleId,
    this.reservationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MessageData> _messages = [];
  int? _conversationId;
  int? _myUserId;
  bool _loading = true;
  bool _sending = false;
  String? _errorMsg;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await AuthService.getCurrentUser();
    _myUserId = user?.userId;

    try {
      final convId = await MessageService.getOrCreateConversation(
        ownerId: widget.ownerId,
        renterId: widget.renterId,
        vehicleId: widget.vehicleId,
        reservationId: widget.reservationId,
        subject: widget.car,
      );
      _conversationId = convId;
      await _loadMessages();

      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'No se pudo iniciar la conversación.';
        });
      }
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_conversationId == null) return;
    try {
      final msgs = await MessageService.getMessages(_conversationId!);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
          _errorMsg = null;
        });
        if (!silent) _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _errorMsg = 'No se pudieron cargar los mensajes.';
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _conversationId == null || _myUserId == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      await MessageService.sendMessage(
        conversationId: _conversationId!,
        senderId: _myUserId!,
        content: text,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(widget.name.isNotEmpty ? widget.name[0] : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                Text(
                  widget.isOnline ? 'En línea' : widget.car,
                  style: TextStyle(fontSize: 12, color: widget.isOnline ? Colors.green : Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.grey[400], size: 40),
                              const SizedBox(height: 12),
                              Text(_errorMsg!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              TextButton(onPressed: _init, child: const Text('Reintentar')),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text('Aún no hay mensajes. ¡Escribe el primero!',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final msg = _messages[i];
                              final isMe = msg.senderId == _myUserId;
                              return _BubbleMsg(
                                text: msg.content,
                                isMe: isMe,
                                time: _formatTime(msg.createdAt),
                              );
                            },
                          ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.image),
                              title: const Text('Enviar imagen'),
                              onTap: () => Navigator.pop(context),
                            ),
                            ListTile(
                              leading: const Icon(Icons.location_on),
                              title: const Text('Compartir ubicación'),
                              onTap: () => Navigator.pop(context),
                            ),
                            ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: const Text('Enviar documento'),
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.add, color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    enabled: !_sending && _conversationId != null,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black)),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _sending ? Colors.grey : Colors.black, shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleMsg extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  const _BubbleMsg({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? Colors.black : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time, style: TextStyle(color: isMe ? Colors.white54 : Colors.grey[400], fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}