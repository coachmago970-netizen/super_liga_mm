import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../auth/auth_providers.dart";
import "../core/app_constants.dart";
import "../core/supabase_provider.dart";

class MembersOnlinePage extends ConsumerStatefulWidget {
  const MembersOnlinePage({super.key});

  @override
  ConsumerState<MembersOnlinePage> createState() => _MembersOnlinePageState();
}

class _MembersOnlinePageState extends ConsumerState<MembersOnlinePage> {
  RealtimeChannel? _presenceChannel;
  bool _loading = true;
  String? _error;
  List<_OnlineMember> _members = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupPresence());
  }

  @override
  void dispose() {
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _setupPresence() async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (client == null || user == null) {
      setState(() {
        _loading = false;
        _error = "Sessao indisponivel.";
      });
      return;
    }

    final channel = client.channel(
      "presence:server:$kServerId",
      opts: const RealtimeChannelConfig(self: true)
    );

    channel
        .onPresenceSync((_) {
          _refreshMembersFromPresence(channel);
        })
        .onPresenceJoin((_) {
          _refreshMembersFromPresence(channel);
        })
        .onPresenceLeave((_) {
          _refreshMembersFromPresence(channel);
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({
              "user_id": user.id,
              "display_name": user.email?.split("@").first ?? "membro",
              "online_at": DateTime.now().toIso8601String()
            });
            await _refreshMembersFromPresence(channel);
          }
          if (error != null && mounted) {
            setState(() {
              _error = "Falha para conectar presenca.";
            });
          }
        });

    _presenceChannel = channel;
  }

  Future<void> _refreshMembersFromPresence(RealtimeChannel channel) async {
    try {
      final userIds = _extractUserIds(channel.presenceState());
      final client = ref.read(supabaseClientProvider);
      if (client == null) return;

      if (userIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _members = const [];
          _loading = false;
          _error = null;
        });
        return;
      }

      final rows = await client
          .from("profiles")
          .select("id, display_name, avatar_url")
          .inFilter("id", userIds.toList());

      final members = (rows as List<dynamic>)
          .map((row) => _OnlineMember.fromMap(row as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Nao foi possivel carregar membros online.";
      });
      debugPrint("Presence sync error: $error");
    }
  }

  Set<String> _extractUserIds(dynamic rawPresenceState) {
    final userIds = <String>{};

    if (rawPresenceState is Map) {
      for (final value in rawPresenceState.values) {
        if (value is List) {
          for (final item in value) {
            _extractFromPresenceItem(item, userIds);
          }
        } else {
          _extractFromPresenceItem(value, userIds);
        }
      }
      return userIds;
    }

    if (rawPresenceState is List) {
      for (final item in rawPresenceState) {
        _extractFromPresenceItem(item, userIds);
      }
    }

    return userIds;
  }

  void _extractFromPresenceItem(dynamic item, Set<String> userIds) {
    if (item is Map<String, dynamic>) {
      final directUserId = item["user_id"];
      if (directUserId is String) {
        userIds.add(directUserId);
      }

      final payload = item["payload"];
      if (payload is Map<String, dynamic>) {
        final payloadUserId = payload["user_id"];
        if (payloadUserId is String) {
          userIds.add(payloadUserId);
        }
      }
      return;
    }

    try {
      final dynamic payload = item.payload;
      if (payload is Map && payload["user_id"] is String) {
        userIds.add(payload["user_id"] as String);
      }
    } catch (_) {
      // Ignore unknown presence payload formats.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Membros Online")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _members.isEmpty
                  ? const Center(child: Text("Ninguem online no momento."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final member = _members[index];
                        return Card(
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    member.displayName.isNotEmpty
                                        ? member.displayName.substring(0, 1).toUpperCase()
                                        : "M"
                                  )
                                ),
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 6,
                                    backgroundColor: Color(0xFF22C55E)
                                  )
                                )
                              ]
                            ),
                            title: Text(member.displayName),
                            subtitle: const Text("Online agora")
                          )
                        );
                      }
                    )
    );
  }
}

class _OnlineMember {
  _OnlineMember({
    required this.id,
    required this.displayName,
    this.avatarUrl
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory _OnlineMember.fromMap(Map<String, dynamic> map) {
    final rawName = (map["display_name"] as String? ?? "Membro").trim();
    return _OnlineMember(
      id: map["id"] as String,
      displayName: rawName.isEmpty ? "Membro" : rawName,
      avatarUrl: map["avatar_url"] as String?
    );
  }
}
