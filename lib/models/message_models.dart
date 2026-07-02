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
  });

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