class ChatMessage {
  ChatMessage({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.deletedAt
  });

  final String id;
  final String channelId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map["id"] as String,
      channelId: map["channel_id"] as String,
      userId: map["user_id"] as String,
      content: map["content"] as String? ?? "",
      createdAt: DateTime.parse(map["created_at"] as String),
      editedAt: map["edited_at"] == null ? null : DateTime.parse(map["edited_at"] as String),
      deletedAt: map["deleted_at"] == null ? null : DateTime.parse(map["deleted_at"] as String)
    );
  }
}
