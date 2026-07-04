import 'counterparty_data.dart';

class ConversationData {
  final int id;
  final int ownerId;
  final int renterId;
  final int? vehicleId;
  final int? reservationId;
  final String subject;
  final String status;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String createdAt;
  final String updatedAt;
  // TS18/US60 — nested counterparty objects, additive alongside ownerId/renterId.
  final CounterpartyData? owner;
  final CounterpartyData? renter;

  ConversationData({
    required this.id,
    required this.ownerId,
    required this.renterId,
    this.vehicleId,
    this.reservationId,
    required this.subject,
    required this.status,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
    this.renter,
  });

  /// Nombre a mostrar de la contraparte: nombre real si el backend lo envió,
  /// fallback explícito con el ID (nunca solo el ID sin contexto) — US60 AC3.
  String get ownerDisplayName => owner?.fullName ?? 'Propietario #$ownerId';
  String get renterDisplayName => renter?.fullName ?? 'Arrendatario #$renterId';

  factory ConversationData.fromJson(Map<String, dynamic> json) {
    return ConversationData(
      id: json['id'] as int,
      ownerId: json['ownerId'] as int,
      renterId: json['renterId'] as int,
      vehicleId: json['vehicleId'] as int?,
      reservationId: json['reservationId'] as int?,
      subject: json['subject'] ?? '',
      status: json['status'] ?? '',
      lastMessageAt: json['lastMessageAt'],
      lastMessagePreview: json['lastMessagePreview'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      owner: CounterpartyData.tryParse(json['owner']),
      renter: CounterpartyData.tryParse(json['renter']),
    );
  }
}

class MessageData {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String? readAt;
  final String createdAt;
  final String updatedAt;

  MessageData({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageData.fromJson(Map<String, dynamic> json) {
    return MessageData(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderId: json['senderId'] as int,
      content: json['content'] ?? '',
      readAt: json['readAt'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}