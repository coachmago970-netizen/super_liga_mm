import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../auth/auth_providers.dart";
import "../core/app_constants.dart";
import "chat_message.dart";
import "chat_repository.dart";

class GeneralChatPage extends ConsumerStatefulWidget {
  const GeneralChatPage({super.key});

  @override
  ConsumerState<GeneralChatPage> createState() => _GeneralChatPageState();
}

class _GeneralChatPageState extends ConsumerState<GeneralChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, String> _displayNamesByUserId = {};

  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialMessages());
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(chatRepositoryProvider);
      final messages = await repository.fetchMessages(channelId: kGeneralTextChannelId, limit: 50);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasMore = messages.length == 50;
        _loading = false;
      });
      await _syncDisplayNames(messages);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Nao foi possivel carregar o chat agora.";
      });
      debugPrint("Chat load error: $error");
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      final repository = ref.read(chatRepositoryProvider);
      final oldest = _messages.first.createdAt;
      final olderMessages = await repository.fetchMessages(
        channelId: kGeneralTextChannelId,
        limit: 50,
        olderThan: oldest
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, olderMessages);
        _hasMore = olderMessages.length == 50;
        _loadingMore = false;
      });
      await _syncDisplayNames(olderMessages);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      debugPrint("Chat pagination error: $error");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 120) {
      _loadMore();
    }
  }

  void _subscribeRealtime() {
    final repository = ref.read(chatRepositoryProvider);
    _channel = repository.createRealtimeChannel(
      channelName: "public:messages:${kGeneralTextChannelId.substring(0, 8)}",
      channelId: kGeneralTextChannelId,
      onChange: (_) {
        _syncLatest();
      }
    );
  }

  Future<void> _syncLatest() async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      final latest = await repository.fetchMessages(channelId: kGeneralTextChannelId, limit: 50);
      if (!mounted) return;
      setState(() {
        final byId = <String, ChatMessage>{
          for (final item in _messages) item.id: item
        };
        for (final item in latest) {
          byId[item.id] = item;
        }
        _messages
          ..clear()
          ..addAll(byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
      });
      await _syncDisplayNames(latest);
    } catch (error) {
      debugPrint("Chat realtime sync error: $error");
    }
  }

  Future<void> _syncDisplayNames(Iterable<ChatMessage> messages) async {
    final missingUserIds = messages
        .map((message) => message.userId)
        .where((id) => id.isNotEmpty && !_displayNamesByUserId.containsKey(id))
        .toSet();
    if (missingUserIds.isEmpty) return;

    try {
      final repository = ref.read(chatRepositoryProvider);
      final names = await repository.fetchDisplayNames(userIds: missingUserIds);
      if (!mounted || names.isEmpty) return;
      setState(() {
        _displayNamesByUserId.addAll(names);
      });
    } catch (error) {
      debugPrint("Display name sync error: $error");
    }
  }

  Future<void> _sendMessage() async {
    final raw = _inputController.text;
    final content = raw.trim();
    if (content.isEmpty || content.length > 2000 || _sending) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final repository = ref.read(chatRepositoryProvider);
      final message = await repository.sendMessage(
        channelId: kGeneralTextChannelId,
        userId: user.id,
        content: content
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
      });
      await _syncDisplayNames([message]);
      _inputController.clear();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falha ao enviar. Verifique limite anti-spam e permissao."))
      );
      debugPrint("Send message error: $error");
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar mensagem"),
          content: TextField(
            controller: controller,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: "Digite a nova mensagem")
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Salvar")
            )
          ]
        );
      }
    );

    if (result == null || result.isEmpty) return;
    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.editMessage(messageId: message.id, content: result);
      await _syncLatest();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nao foi possivel editar a mensagem."))
      );
      debugPrint("Edit message error: $error");
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.softDeleteMessage(messageId: message.id);
      await _syncLatest();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nao foi possivel remover a mensagem."))
      );
      debugPrint("Delete message error: $error");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Chat Geral")),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                        ? const Center(child: Text("Nenhuma mensagem ainda."))
                        : RefreshIndicator(
                            onRefresh: _loadInitialMessages,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (_, index) {
                                if (_loadingMore && index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2))
                                  );
                                }

                                final message = _messages[_loadingMore ? index - 1 : index];
                                final isMine = message.userId == currentUserId;
                                final authorName = isMine
                                    ? "Voce"
                                    : (_displayNamesByUserId[message.userId] ?? "Membro");
                                return _MessageBubble(
                                  message: message,
                                  authorName: authorName,
                                  isMine: isMine,
                                  onEdit: isMine ? () => _editMessage(message) : null,
                                  onDelete: isMine ? () => _deleteMessage(message) : null
                                );
                              }
                            )
                          ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Digite sua mensagem",
                      counterText: ""
                    ),
                    onSubmitted: (_) => _sendMessage()
                  )
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: Text(_sending ? "..." : "Enviar")
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.authorName,
    required this.isMine,
    this.onEdit,
    this.onDelete
  });

  final ChatMessage message;
  final String authorName;
  final bool isMine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          color: isMine ? const Color(0xFF2563EB) : Colors.white,
          child: InkWell(
            onLongPress: (onEdit == null && onDelete == null)
                ? null
                : () async {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text("Editar"),
                                  onTap: () => Navigator.pop(context, "edit")
                                ),
                              if (onDelete != null)
                                ListTile(
                                  leading: const Icon(Icons.delete_outline),
                                  title: const Text("Remover"),
                                  onTap: () => Navigator.pop(context, "delete")
                                )
                            ]
                          )
                        );
                      }
                    );
                    if (action == "edit") onEdit?.call();
                    if (action == "delete") onDelete?.call();
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMine ? const Color(0xFFBFDBFE) : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.isDeleted ? "[mensagem removida]" : message.content,
                    style: TextStyle(color: isMine ? Colors.white : const Color(0xFF111827))
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? const Color(0xFFBFDBFE) : const Color(0xFF9CA3AF)
                    )
                  )
                ]
              )
            )
          )
        )
      )
    );
  }

  static String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, "0");
    final mm = dt.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }
}
