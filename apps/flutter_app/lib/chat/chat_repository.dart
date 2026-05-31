import "package:supabase_flutter/supabase_flutter.dart";
import "../core/supabase_provider.dart";
import "chat_message.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRepository(client);
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient? _client;

  Future<List<ChatMessage>> fetchMessages({
    required String channelId,
    int limit = 50,
    DateTime? olderThan
  }) async {
    final client = _requireClient();
    var query = client.from("messages").select().eq("channel_id", channelId);

    if (olderThan != null) {
      query = query.lt("created_at", olderThan.toIso8601String());
    }

    final rows = await query.order("created_at", ascending: false).limit(limit);
    final messages = (rows as List<dynamic>)
        .map((row) => ChatMessage.fromMap(row as Map<String, dynamic>))
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<ChatMessage> sendMessage({
    required String channelId,
    required String userId,
    required String content
  }) async {
    final client = _requireClient();
    final rows = await client
        .from("messages")
        .insert({
          "channel_id": channelId,
          "user_id": userId,
          "content": content.trim()
        })
        .select()
        .limit(1);

    final row = (rows as List<dynamic>).first as Map<String, dynamic>;
    return ChatMessage.fromMap(row);
  }

  Future<void> editMessage({
    required String messageId,
    required String content
  }) async {
    final client = _requireClient();
    await client.from("messages").update({
      "content": content.trim(),
      "edited_at": DateTime.now().toIso8601String()
    }).eq("id", messageId);
  }

  Future<void> softDeleteMessage({required String messageId}) async {
    final client = _requireClient();
    await client.from("messages").update({
      "content": "[mensagem removida]",
      "deleted_at": DateTime.now().toIso8601String()
    }).eq("id", messageId);
  }

  Future<Map<String, String>> fetchDisplayNames({
    required Set<String> userIds
  }) async {
    if (userIds.isEmpty) return const {};
    final client = _requireClient();
    final rows = await client
        .from("profiles")
        .select("id, display_name")
        .inFilter("id", userIds.toList());

    final result = <String, String>{};
    for (final row in (rows as List<dynamic>)) {
      final map = row as Map<String, dynamic>;
      final id = map["id"] as String?;
      if (id == null || id.isEmpty) continue;

      final rawName = (map["display_name"] as String? ?? "").trim();
      result[id] = rawName.isEmpty ? "Membro" : rawName;
    }
    return result;
  }

  RealtimeChannel createRealtimeChannel({
    required String channelName,
    required String channelId,
    required void Function(PostgresChangePayload payload) onChange
  }) {
    final client = _requireClient();
    final channel = client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: "public",
          table: "messages",
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "channel_id",
            value: channelId
          ),
          callback: onChange
        )
        .subscribe();
    return channel;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw Exception("Supabase nao configurado no app.");
    }
    return client;
  }
}
