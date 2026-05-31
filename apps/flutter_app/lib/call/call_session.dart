import "package:flutter_riverpod/flutter_riverpod.dart";

class VoiceSessionData {
  VoiceSessionData({
    required this.token,
    required this.url,
    required this.room,
    required this.channelId,
    required this.channelName,
    required this.canPublish,
    this.mutedReason,
    this.mutedUntil
  });

  final String token;
  final String url;
  final String room;
  final String channelId;
  final String channelName;
  final bool canPublish;
  final String? mutedReason;
  final String? mutedUntil;
}

final voiceSessionProvider = StateProvider<VoiceSessionData?>((ref) => null);
