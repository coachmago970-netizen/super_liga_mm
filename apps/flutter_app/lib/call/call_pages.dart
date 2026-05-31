import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "package:livekit_client/livekit_client.dart" as lk;
import "package:flutter_webrtc/flutter_webrtc.dart" as rtc;
import "../auth/auth_providers.dart";
import "../core/app_constants.dart";
import "../core/env.dart";
import "call_session.dart";

class VoiceChannelPage extends ConsumerStatefulWidget {
  const VoiceChannelPage({super.key});

  @override
  ConsumerState<VoiceChannelPage> createState() => _VoiceChannelPageState();
}

class _VoiceChannelPageState extends ConsumerState<VoiceChannelPage> {
  final _newChannelController = TextEditingController();
  bool _loadingChannels = false;
  bool _creatingChannel = false;
  bool _loading = false;
  String? _joiningChannelId;
  String? _status;
  List<_VoiceChannelSummary> _voiceChannels = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVoiceChannels());
  }

  @override
  void dispose() {
    _newChannelController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decodeObjectBody(String rawBody) {
    if (rawBody.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }

  Future<http.Response> _postTokenRequest({
    required String accessToken,
    required String channelId
  }) {
    return http.post(
      Uri.parse("${AppEnv.backendBaseUrl}/livekit/token"),
      headers: {
        "content-type": "application/json",
        "authorization": "Bearer $accessToken"
      },
      body: jsonEncode({
        "serverId": kServerId,
        "channelId": channelId
      })
    );
  }

  Future<bool> _joinServer(String accessToken) async {
    final response = await http.post(
      Uri.parse("${AppEnv.backendBaseUrl}/servers/join"),
      headers: {
        "content-type": "application/json",
        "authorization": "Bearer $accessToken"
      },
      body: jsonEncode({"serverId": kServerId})
    );
    final body = _decodeObjectBody(response.body);
    return response.statusCode >= 200 && response.statusCode < 300 && body["ok"] == true;
  }

  Future<void> _loadVoiceChannels() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (!mounted) return;
      context.go("/login");
      return;
    }

    if (AppEnv.backendBaseUrl.isEmpty) {
      if (!mounted) return;
      setState(() => _status = "BACKEND_BASE_URL nao configurado.");
      return;
    }

    setState(() {
      _loadingChannels = true;
      _status = null;
    });

    try {
      var response = await http.post(
        Uri.parse("${AppEnv.backendBaseUrl}/channels/list"),
        headers: {
          "content-type": "application/json",
          "authorization": "Bearer ${session.accessToken}"
        },
        body: jsonEncode({
          "serverId": kServerId,
          "type": "voice"
        })
      );

      var body = _decodeObjectBody(response.body);
      if (response.statusCode == 403) {
        final errorText = (body["error"]?.toString() ?? "").toLowerCase();
        if (errorText.contains("not a member")) {
          final joined = await _joinServer(session.accessToken);
          if (joined) {
            response = await http.post(
              Uri.parse("${AppEnv.backendBaseUrl}/channels/list"),
              headers: {
                "content-type": "application/json",
                "authorization": "Bearer ${session.accessToken}"
              },
              body: jsonEncode({
                "serverId": kServerId,
                "type": "voice"
              })
            );
            body = _decodeObjectBody(response.body);
          }
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!mounted) return;
        setState(() {
          _status = body["error"]?.toString() ?? "Nao foi possivel carregar os canais de voz.";
          _voiceChannels = const [];
        });
        return;
      }

      final channelsRaw = body["channels"] as List<dynamic>? ?? const [];
      final channels = channelsRaw
          .whereType<Map>()
          .map((row) => _VoiceChannelSummary.fromMap(row.cast<String, dynamic>()))
          .toList();

      if (!mounted) return;
      setState(() {
        _voiceChannels = channels;
        if (channels.isEmpty) {
          _status = "Nenhuma call criada ainda. Crie uma abaixo.";
        } else {
          _status = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = "Falha ao carregar canais de voz.");
      debugPrint("Voice channels list error: $error");
    } finally {
      if (mounted) {
        setState(() => _loadingChannels = false);
      }
    }
  }

  Future<void> _createVoiceChannel() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (!mounted) return;
      context.go("/login");
      return;
    }

    final name = _newChannelController.text.trim();
    if (name.length < 2) {
      setState(() => _status = "Nome da call precisa ter pelo menos 2 caracteres.");
      return;
    }

    setState(() {
      _creatingChannel = true;
      _status = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${AppEnv.backendBaseUrl}/channels/create"),
        headers: {
          "content-type": "application/json",
          "authorization": "Bearer ${session.accessToken}"
        },
        body: jsonEncode({
          "serverId": kServerId,
          "name": name,
          "type": "voice"
        })
      );

      final body = _decodeObjectBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _status = body["error"]?.toString() ?? "Nao foi possivel criar a call.";
        });
        return;
      }

      _newChannelController.clear();
      await _loadVoiceChannels();
      if (!mounted) return;
      setState(() => _status = "Call criada com sucesso.");
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = "Falha ao criar call.");
      debugPrint("Create voice channel error: $error");
    } finally {
      if (mounted) {
        setState(() => _creatingChannel = false);
      }
    }
  }

  Future<void> _requestVoiceToken(_VoiceChannelSummary channel) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (!mounted) return;
      context.go("/login");
      return;
    }

    if (AppEnv.backendBaseUrl.isEmpty) {
      setState(() => _status = "BACKEND_BASE_URL nao configurado.");
      return;
    }

    setState(() {
      _loading = true;
      _joiningChannelId = channel.id;
      _status = null;
    });

    try {
      var response = await _postTokenRequest(
        accessToken: session.accessToken,
        channelId: channel.id
      );
      var body = _decodeObjectBody(response.body);

      if (response.statusCode == 403) {
        final errorText = (body["error"]?.toString() ?? "").toLowerCase();
        if (errorText.contains("not a member")) {
          final joined = await _joinServer(session.accessToken);
          if (joined) {
            response = await _postTokenRequest(
              accessToken: session.accessToken,
              channelId: channel.id
            );
            body = _decodeObjectBody(response.body);
          }
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final backendError = body["error"]?.toString();
        String? issueMessage;
        final issues = body["issues"];
        if (issues is List && issues.isNotEmpty) {
          final first = issues.first;
          if (first is Map) {
            final path = first["path"]?.toString() ?? "";
            final message = first["message"]?.toString() ?? "";
            if (path.isNotEmpty || message.isNotEmpty) {
              issueMessage = "$path $message".trim();
            }
          }
        }
        setState(() {
          final baseMessage = backendError == null || backendError.isEmpty
              ? "Nao foi possivel entrar na chamada (HTTP ${response.statusCode})."
              : backendError;
          _status = issueMessage == null ? baseMessage : "$baseMessage ($issueMessage)";
        });
        return;
      }

      final token = body["token"]?.toString() ?? "";
      final url = body["url"]?.toString() ?? "";
      final room = body["room"]?.toString() ?? "";
      final responseChannelId = body["channelId"]?.toString() ?? channel.id;
      final responseChannelName = body["channelName"]?.toString() ?? channel.name;
      final voicePermission = body["voicePermission"] as Map<String, dynamic>?;
      final canPublish = voicePermission?["canPublish"] != false;
      final mutedReason = voicePermission?["mutedReason"]?.toString();
      final mutedUntil = voicePermission?["mutedUntil"]?.toString();

      if (token.isEmpty || url.isEmpty || room.isEmpty) {
        setState(() => _status = "Resposta de token incompleta.");
        return;
      }

      ref.read(voiceSessionProvider.notifier).state = VoiceSessionData(
            token: token,
            url: url,
            room: room,
            channelId: responseChannelId,
            channelName: responseChannelName,
            canPublish: canPublish,
            mutedReason: mutedReason,
            mutedUntil: mutedUntil
          );

      if (!mounted) return;
      context.push("/call");
    } catch (error) {
      setState(() {
        _status = "Falha ao solicitar token da chamada. Verifique se o backend esta ativo em ${AppEnv.backendBaseUrl}.";
      });
      debugPrint("LiveKit token request error: $error");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _joiningChannelId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Voltar",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go("/server");
          },
          icon: const Icon(Icons.arrow_back)
        ),
        title: const Text("Canal de Voz")
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Escolha uma call para entrar ou crie uma nova (ex: Equipe 1, Equipe 2).",
                        style: TextStyle(color: Color(0xFF6B7280))
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newChannelController,
                              decoration: const InputDecoration(
                                labelText: "Nome da nova call",
                                hintText: "Equipe 1"
                              )
                            )
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _creatingChannel ? null : _createVoiceChannel,
                            child: Text(_creatingChannel ? "Criando..." : "Criar")
                          )
                        ]
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadingChannels ? null : _loadVoiceChannels,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Atualizar lista")
                      ),
                      const SizedBox(height: 10),
                      if (_loadingChannels)
                        const Center(child: CircularProgressIndicator())
                      else if (_voiceChannels.isEmpty)
                        const Text("Nenhuma call disponivel.")
                      else
                        ..._voiceChannels.map(
                          (channel) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.graphic_eq),
                              title: Text(channel.name),
                              subtitle: Text("Canal de voz"),
                              trailing: FilledButton.icon(
                                onPressed: _loading ? null : () => _requestVoiceToken(channel),
                                icon: const Icon(Icons.call, size: 18),
                                label: Text(
                                  _joiningChannelId == channel.id ? "Conectando..." : "Entrar"
                                )
                              )
                            )
                          )
                        )
                    ]
                  )
                )
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push("/screen-share"),
                icon: const Icon(Icons.cast),
                label: const Text("Guia de compartilhamento de tela")
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(
                  _status!,
                  style: TextStyle(
                    color: _status!.toLowerCase().contains("sucesso")
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626)
                  )
                )
              ]
            ]
          )
        )
      )
    );
  }
}

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  lk.Room? _room;
  bool _connecting = true;
  bool _connected = false;
  bool _micEnabled = true;
  bool _screenShareEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    final room = _room;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      unawaited(room.disconnect().catchError((_) {}));
      unawaited(room.dispose().catchError((_) {}));
    }
    super.dispose();
  }

  void _onRoomChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _connect() async {
    final voiceSession = ref.read(voiceSessionProvider);
    if (voiceSession == null) {
      setState(() {
        _connecting = false;
        _error = "Sessao de voz expirada. Volte para Canal de Voz.";
      });
      return;
    }

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true)
    );
    room.addListener(_onRoomChanged);
    _room = room;

    try {
      await room.prepareConnection(voiceSession.url, voiceSession.token);
      await room.connect(voiceSession.url, voiceSession.token);
      final localParticipant = room.localParticipant;
      if (localParticipant == null) {
        throw Exception("Participante local indisponivel apos conexao.");
      }

      if (voiceSession.canPublish) {
        await localParticipant.setMicrophoneEnabled(true);
      } else {
        await localParticipant.setMicrophoneEnabled(false);
      }

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
        _micEnabled = voiceSession.canPublish && localParticipant.isMicrophoneEnabled();
        _screenShareEnabled = localParticipant.isScreenShareEnabled();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = false;
        _error = "Falha ao conectar na chamada.";
      });
      debugPrint("LiveKit connect error: $error");
    }
  }

  Future<void> _leaveCall() async {
    final room = _room;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
    }
    ref.read(voiceSessionProvider.notifier).state = null;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go("/voice-channel");
  }

  Future<void> _toggleMic() async {
    final room = _room;
    if (room == null || !_connected) return;
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;
    final voiceSession = ref.read(voiceSessionProvider);
    if (voiceSession == null || !voiceSession.canPublish) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voce esta mutado pela moderacao e so pode escutar."))
      );
      return;
    }

    final next = !_micEnabled;
    try {
      await localParticipant.setMicrophoneEnabled(next);
      if (!mounted) return;
      setState(() => _micEnabled = localParticipant.isMicrophoneEnabled());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nao foi possivel alternar microfone."))
      );
      debugPrint("Toggle mic error: $error");
    }
  }

  Future<void> _toggleScreenShare() async {
    final room = _room;
    if (room == null || !_connected) return;
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;
    final voiceSession = ref.read(voiceSessionProvider);
    if (voiceSession == null || !voiceSession.canPublish) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voce esta mutado pela moderacao e nao pode publicar tela."))
      );
      return;
    }

    final next = !_screenShareEnabled;
    try {
      if (next) {
        await _startScreenShare(room: room);
      } else {
        await localParticipant.setScreenShareEnabled(false);
      }
      if (!mounted) return;
      setState(() => _screenShareEnabled = localParticipant.isScreenShareEnabled());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Falha no compartilhamento de tela. Verifique permissoes da plataforma.")
        )
      );
      debugPrint("Toggle screen share error: $error");
    }
  }

  Future<void> _startScreenShare({required lk.Room room}) async {
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    if (kIsWeb) {
      await localParticipant.setScreenShareEnabled(true);
      return;
    }

    if (lk.lkPlatformIsDesktop()) {
      final source = await showDialog<dynamic>(
        context: context,
        builder: (_) => lk.ScreenSelectDialog()
      );
      if (source == null) return;
      final sourceId = (source as dynamic).id as String?;
      if (sourceId == null || sourceId.isEmpty) return;

      final track = await lk.LocalVideoTrack.createScreenShareTrack(
        lk.ScreenShareCaptureOptions(
          sourceId: sourceId,
          maxFrameRate: 15
        )
      );
      await localParticipant.publishVideoTrack(track);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await rtc.Helper.requestCapturePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permissao de captura de tela negada."))
          );
        }
        return;
      }
      await localParticipant.setScreenShareEnabled(true);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compartilhamento de tela no iOS entra em fase posterior do MVP.")
          )
        );
      }
      return;
    }

    await localParticipant.setScreenShareEnabled(true);
  }

  List<_ParticipantViewData> _participantItems() {
    final room = _room;
    if (room == null) return const [];
    final local = room.localParticipant;
    if (local == null) return const [];

    final activeSpeakerIds = room.activeSpeakers.map((participant) => participant.identity).toSet();

    final items = <_ParticipantViewData>[
      _ParticipantViewData(
        identity: local.identity,
        name: local.name.isEmpty ? "Voce" : local.name,
        role: "local",
        speaking: activeSpeakerIds.contains(local.identity),
        micOn: local.isMicrophoneEnabled()
      )
    ];

    for (final participant in room.remoteParticipants.values) {
      items.add(
        _ParticipantViewData(
          identity: participant.identity,
          name: participant.name.isEmpty ? participant.identity : participant.name,
          role: "remoto",
          speaking: activeSpeakerIds.contains(participant.identity) || participant.isSpeaking,
          micOn: participant.isMicrophoneEnabled()
        )
      );
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  List<_ScreenShareViewData> _screenShareTracks() {
    final room = _room;
    if (room == null) return const [];

    final items = <_ScreenShareViewData>[];

    for (final participant in room.remoteParticipants.values) {
      final publication =
          participant.getTrackPublicationBySource(lk.TrackSource.screenShareVideo);
      final track = publication?.track;
      if (track != null && track.kind == lk.TrackType.VIDEO) {
        items.add(
          _ScreenShareViewData(
            track: track,
            ownerName: participant.name.isEmpty ? participant.identity : participant.name,
            local: false
          )
        );
      }
    }

    final local = room.localParticipant;
    if (local != null) {
      final publication = local.getTrackPublicationBySource(lk.TrackSource.screenShareVideo);
      final track = publication?.track;
      if (track != null && track.kind == lk.TrackType.VIDEO) {
        items.add(
          _ScreenShareViewData(
            track: track,
            ownerName: local.name.isEmpty ? "Voce" : local.name,
            local: true
          )
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(voiceSessionProvider);
    final room = _room;
    final connectionLabel = room?.connectionState.toString() ?? "disconnected";
    final participants = _participantItems();
    final screenShareTracks = _screenShareTracks();
    final activeScreenShare = screenShareTracks.isNotEmpty ? screenShareTracks.first : null;
    final activeScreenShareVideoTrack = activeScreenShare?.track is lk.VideoTrack
        ? activeScreenShare!.track as lk.VideoTrack
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Voltar",
          onPressed: _leaveCall,
          icon: const Icon(Icons.arrow_back)
        ),
        title: const Text("Chamada"),
        actions: [
          IconButton(
            tooltip: "Sair da chamada",
            onPressed: _leaveCall,
            icon: const Icon(Icons.call_end)
          )
        ]
      ),
      body: session == null
          ? const Center(
              child: Text("Nenhuma chamada ativa. Entre novamente pelo Canal de Voz.")
            )
          : _connecting
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (activeScreenShare != null && activeScreenShareVideoTrack != null) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      "Tela compartilhada por ${activeScreenShare.ownerName}${activeScreenShare.local ? ' (voce)' : ''}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700
                                      )
                                    ),
                                    const SizedBox(height: 8),
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          color: Colors.black,
                                          child: lk.VideoTrackRenderer(
                                            activeScreenShareVideoTrack,
                                            fit: lk.VideoViewFit.contain
                                          )
                                        )
                                      )
                                    )
                                  ]
                                )
                              )
                            ),
                            const SizedBox(height: 10)
                          ],
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Conexao LiveKit",
                                    style: TextStyle(fontWeight: FontWeight.w700)
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Canal: ${session.channelName}"),
                                  Text("Sala: ${session.room}"),
                                  Text("Estado: $connectionLabel"),
                                  Text("Participantes: ${participants.length}"),
                                  Text("Telas compartilhadas: ${screenShareTracks.length}"),
                                  if (!session.canPublish) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      "Modo escuta: voce esta mutado pela moderacao.",
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600
                                      )
                                    ),
                                    if (session.mutedReason != null && session.mutedReason!.isNotEmpty)
                                      Text("Motivo: ${session.mutedReason}"),
                                    if (session.mutedUntil != null && session.mutedUntil!.isNotEmpty)
                                      Text("Validade: ${session.mutedUntil}")
                                  ]
                                ]
                              )
                            )
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: session.canPublish ? _toggleMic : null,
                                icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                                label: Text(_micEnabled ? "Mutar" : "Desmutar")
                              ),
                              FilledButton.tonalIcon(
                                onPressed: session.canPublish ? _toggleScreenShare : null,
                                icon: Icon(_screenShareEnabled ? Icons.stop_screen_share : Icons.cast),
                                label: Text(_screenShareEnabled ? "Parar Tela" : "Compartilhar Tela")
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push("/screen-share"),
                                icon: const Icon(Icons.info_outline),
                                label: const Text("Guia de Plataforma")
                              )
                            ]
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: participants.isEmpty
                                ? const Center(child: Text("Aguardando participantes..."))
                                : ListView.separated(
                                    itemCount: participants.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, index) {
                                      final item = participants[index];
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: item.speaking
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFE5E7EB),
                                            child: Icon(
                                              item.speaking ? Icons.graphic_eq : Icons.person_outline,
                                              color: item.speaking
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF4B5563)
                                            )
                                          ),
                                          title: Text(item.name),
                                          subtitle: Text(
                                            "${item.role} | ${item.micOn ? 'microfone ativo' : 'microfone mutado'}"
                                          ),
                                          trailing: item.speaking
                                              ? const Text(
                                                  "falando",
                                                  style: TextStyle(
                                                    color: Color(0xFF16A34A),
                                                    fontWeight: FontWeight.w600
                                                  )
                                                )
                                              : const SizedBox.shrink()
                                        )
                                      );
                                    }
                                  ),
                          )
                        ]
                      )
                    )
    );
  }
}

class _ParticipantViewData {
  _ParticipantViewData({
    required this.identity,
    required this.name,
    required this.role,
    required this.speaking,
    required this.micOn
  });

  final String identity;
  final String name;
  final String role;
  final bool speaking;
  final bool micOn;
}

class _VoiceChannelSummary {
  _VoiceChannelSummary({
    required this.id,
    required this.name
  });

  final String id;
  final String name;

  factory _VoiceChannelSummary.fromMap(Map<String, dynamic> map) {
    return _VoiceChannelSummary(
      id: map["id"] as String,
      name: (map["name"] as String? ?? "Canal de Voz").trim().isEmpty
          ? "Canal de Voz"
          : (map["name"] as String? ?? "Canal de Voz").trim()
    );
  }
}

class _ScreenShareViewData {
  _ScreenShareViewData({
    required this.track,
    required this.ownerName,
    required this.local
  });

  final lk.Track track;
  final String ownerName;
  final bool local;
}
