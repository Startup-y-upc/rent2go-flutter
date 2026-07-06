import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/message_models.dart';
import 'auth_service.dart';

class MessageService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/community-trust/users/{userId}/conversations
  /// Lista todas las conversaciones reales del usuario actual (como owner o renter).
  static Future<List<ConversationData>> getUserConversations(int userId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/users/$userId/conversations');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((c) => ConversationData.fromJson(c)).toList();
    }
    throw Exception('No se pudieron cargar tus conversaciones');
  }

  static Future<int> getOrCreateConversation({
    required int ownerId,
    required int renterId,
    int? vehicleId,
    int? reservationId,
    required String subject,
  }) async {
    final box = Hive.box('conversations_map');
    final key = 'conv_${ownerId}_${renterId}_${vehicleId ?? 0}';

    final cachedId = box.get(key);
    if (cachedId != null) return cachedId as int;

    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/conversations');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ownerId': ownerId,
        'renterId': renterId,
        'vehicleId': vehicleId ?? 0,
        'reservationId': reservationId ?? 0,
        'subject': subject,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final conversation = ConversationData.fromJson(data);
      await box.put(key, conversation.id);
      return conversation.id;
    }

    throw Exception('No se pudo iniciar la conversación');
  }

  static Future<List<MessageData>> getMessages(int conversationId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/conversations/$conversationId/messages');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((m) => MessageData.fromJson(m)).toList();
    }
    throw Exception('No se pudieron cargar los mensajes');
  }

  static Future<MessageData> sendMessage({
    required int conversationId,
    required int senderId,
    required String content,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/conversations/$conversationId/messages');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'senderId': senderId, 'content': content}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return MessageData.fromJson(data);
    }
    throw Exception('No se pudo enviar el mensaje');
  }

  static Future<void> closeConversation(int conversationId, int userId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/conversations/$conversationId/close?userId=$userId');
    await http.post(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  /// Whether [userId] has any conversation with activity newer than the last
  /// time they opened the Messages screen. Replaces the old N+1 unread-count
  /// logic (one GET .../messages call per conversation just to count unread
  /// items client-side): the conversations list endpoint already returns
  /// `lastMessageAt` for free, so this only needs the single list call plus a
  /// local timestamp comparison — no per-conversation message fetch, no
  /// numeric count, just "is there something new".
  static Future<bool> hasRecentActivity(int userId) async {
    try {
      final conversations = await getUserConversations(userId);
      final lastOpened = await UnreadIndicatorStore.getLastOpenedAt(userId);
      if (lastOpened == null) {
        // Never opened Messages before: show the dot if any conversation has
        // ever had a message, otherwise there is nothing new to flag.
        return conversations.any((c) => c.lastMessageAt != null && c.lastMessageAt!.isNotEmpty);
      }
      for (final c in conversations) {
        final iso = c.lastMessageAt;
        if (iso == null || iso.isEmpty) continue;
        final ts = DateTime.tryParse(iso);
        if (ts != null && ts.isAfter(lastOpened)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Persists, per user, the last time the Messages screen was opened so the
/// unread activity dot can be derived from `ConversationData.lastMessageAt`
/// without any additional network call.
class UnreadIndicatorStore {
  static const _boxName = 'messages_unread_indicator';

  static Future<Box> _box() => Hive.openBox(_boxName);

  static Future<DateTime?> getLastOpenedAt(int userId) async {
    final box = await _box();
    final iso = box.get('last_opened_$userId') as String?;
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  static Future<void> markOpenedNow(int userId) async {
    final box = await _box();
    await box.put('last_opened_$userId', DateTime.now().toUtc().toIso8601String());
  }
}