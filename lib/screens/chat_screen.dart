import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String car;
  final bool isOnline;
  const ChatScreen({
    super.key,
    required this.name,
    required this.car,
    required this.isOnline,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_Message> _messages = [
    _Message(
      text: 'Tesla Model 3\n12 May 10:00 → 14 May 18:00',
      isMe: false,
      time: '',
      isBookingCard: true,
      status: 'Confirmada',
    ),
    _Message(
      text: '¡Hola Diego! ¿Confirmamos la recogida en Goya 24 a las 10:00?',
      isMe: false,
      time: '14:18',
    ),
    _Message(
      text: '¡Hola Lucía! Sí, perfecto. Voy a ir en metro hasta Goya.',
      isMe: true,
      time: '14:19',
    ),
    _Message(
      text: 'Genial. Te dejo el coche con carga completa (498 km).',
      isMe: false,
      time: '14:20',
    ),
    _Message(
      text: 'Perfecto, te espero a las 10h en Goya 24',
      isMe: false,
      time: '14:22',
    ),
  ];

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(
        text: text,
        isMe: true,
        time: _nowTime(),
      ));
      _msgCtrl.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
                  child: Text(
                    widget.name[0],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black)),
                Text(
                  widget.isOnline ? 'En línea' : widget.car,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                // Separador de fecha
                final showDate = i == 0 ||
                    (i == _messages.length - 1 && msg.time.isNotEmpty);
                return Column(
                  children: [
                    if (i == 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('HOY · 14:18',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12)),
                      ),
                    msg.isBookingCard
                        ? _BookingMsgCard(message: msg)
                        : _BubbleMsg(message: msg),
                  ],
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, color: Colors.grey, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 16),
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
  final _Message message;
  const _BubbleMsg({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.black : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMe ? 16 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: message.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                  color: message.isMe ? Colors.white : Colors.black87,
                  fontSize: 14),
            ),
            if (message.time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.time,
                style: TextStyle(
                    color: message.isMe
                        ? Colors.white54
                        : Colors.grey[400],
                    fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingMsgCard extends StatelessWidget {
  final _Message message;
  const _BookingMsgCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=200&q=80',
              width: 60,
              height: 44,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                  width: 60,
                  height: 44,
                  color: Colors.grey[200],
                  child: const Icon(Icons.directions_car, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tesla Model 3',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black)),
                const Text('12 May 10:00 → 14 May 18:00',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(message.status ?? '',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isMe;
  final String time;
  final bool isBookingCard;
  final String? status;
  const _Message({
    required this.text,
    required this.isMe,
    required this.time,
    this.isBookingCard = false,
    this.status,
  });
}