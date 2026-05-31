import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "../auth/auth_providers.dart";
import "../core/app_constants.dart";
import "../core/env.dart";

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Painel Admin")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminTile(
            title: "Gerenciar Convites",
            subtitle: "Criar, listar e desativar convites",
            icon: Icons.link,
            onTap: () => context.push("/admin/invites")
          ),
          const SizedBox(height: 10),
          _AdminTile(
            title: "Gerenciar Membros",
            subtitle: "Cargos, banimento, expulsao e mute",
            icon: Icons.people_outline,
            onTap: () => context.push("/admin/members")
          ),
          const SizedBox(height: 10),
          _AdminTile(
            title: "Logs Administrativos",
            subtitle: "Acompanhar acoes sensiveis",
            icon: Icons.receipt_long_outlined,
            onTap: () => context.push("/admin/logs")
          )
        ]
      )
    );
  }
}

class ManageInvitesPage extends ConsumerStatefulWidget {
  const ManageInvitesPage({super.key});

  @override
  ConsumerState<ManageInvitesPage> createState() => _ManageInvitesPageState();
}

class _ManageInvitesPageState extends ConsumerState<ManageInvitesPage> {
  final _maxUsesController = TextEditingController();
  final _expiresAtController = TextEditingController();
  bool _loading = true;
  bool _creating = false;
  String? _error;
  List<_AdminInvite> _invites = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvites());
  }

  @override
  void dispose() {
    _maxUsesController.dispose();
    _expiresAtController.dispose();
    super.dispose();
  }

  Uri _url(String path) {
    if (AppEnv.backendBaseUrl.isEmpty) {
      throw Exception("BACKEND_BASE_URL nao configurado.");
    }
    return Uri.parse("${AppEnv.backendBaseUrl}$path");
  }

  Future<Map<String, String>> _authHeaders() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) throw Exception("Sessao expirada.");
    return {
      "content-type": "application/json",
      "authorization": "Bearer ${session.accessToken}"
    };
  }

  Future<void> _loadInvites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        _url("/admin/invites/list"),
        headers: await _authHeaders(),
        body: jsonEncode({"serverId": kServerId})
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha ao carregar convites.");
      }

      final invitesRaw = (body["invites"] as List<dynamic>? ?? const []);
      final invites = invitesRaw
          .map((item) => _AdminInvite.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _invites = invites;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Nao foi possivel carregar convites.";
      });
      debugPrint("Load admin invites error: $error");
    }
  }

  Future<void> _createInvite() async {
    if (_creating) return;
    setState(() => _creating = true);

    int? maxUses;
    if (_maxUsesController.text.trim().isNotEmpty) {
      maxUses = int.tryParse(_maxUsesController.text.trim());
    }

    String? expiresAt;
    if (_expiresAtController.text.trim().isNotEmpty) {
      expiresAt = _expiresAtController.text.trim();
    }

    try {
      final response = await http.post(
        _url("/admin/invites/create"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "serverId": kServerId,
          "maxUses": maxUses,
          "expiresAt": expiresAt
        })
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha ao criar convite.");
      }

      _maxUsesController.clear();
      _expiresAtController.clear();
      await _loadInvites();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nao foi possivel criar convite. Use data no formato ISO-8601.")
        )
      );
      debugPrint("Create admin invite error: $error");
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _deactivateInvite(_AdminInvite invite) async {
    try {
      final response = await http.post(
        _url("/admin/invites/deactivate"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "serverId": kServerId,
          "inviteId": invite.id
        })
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha ao desativar convite.");
      }
      await _loadInvites();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nao foi possivel desativar convite."))
      );
      debugPrint("Deactivate admin invite error: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Convites")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Criar novo convite",
                    style: TextStyle(fontWeight: FontWeight.w700)
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _maxUsesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Limite de usos (opcional)",
                      hintText: "Ex: 20"
                    )
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _expiresAtController,
                    decoration: const InputDecoration(
                      labelText: "Validade ISO-8601 (opcional)",
                      hintText: "Ex: 2026-12-31T23:59:59Z"
                    )
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _creating ? null : _createInvite,
                    child: Text(_creating ? "Criando..." : "Criar convite")
                  )
                ]
              )
            )
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text(_error!))
          else if (_invites.isEmpty)
            const Center(child: Text("Nenhum convite criado ainda."))
          else
            ..._invites.map(
              (invite) => Card(
                child: ListTile(
                  title: Text(invite.code),
                  subtitle: Text(
                    "Usos: ${invite.currentUses}"
                    "${invite.maxUses == null ? '' : '/${invite.maxUses}'}"
                    " | ${invite.isActive ? 'Ativo' : 'Inativo'}"
                  ),
                  trailing: invite.isActive
                      ? TextButton(
                          onPressed: () => _deactivateInvite(invite),
                          child: const Text("Desativar")
                        )
                      : const Text("Desativado"),
                )
              )
            )
        ]
      )
    );
  }
}

class ManageMembersPage extends ConsumerStatefulWidget {
  const ManageMembersPage({super.key});

  @override
  ConsumerState<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends ConsumerState<ManageMembersPage> {
  bool _loading = true;
  String? _error;
  List<_AdminMember> _members = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Uri _url(String path) {
    if (AppEnv.backendBaseUrl.isEmpty) {
      throw Exception("BACKEND_BASE_URL nao configurado.");
    }
    return Uri.parse("${AppEnv.backendBaseUrl}$path");
  }

  Future<Map<String, String>> _authHeaders() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) throw Exception("Sessao expirada.");
    return {
      "content-type": "application/json",
      "authorization": "Bearer ${session.accessToken}"
    };
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        _url("/admin/members/list"),
        headers: await _authHeaders(),
        body: jsonEncode({"serverId": kServerId})
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha ao carregar membros.");
      }

      final membersRaw = (body["members"] as List<dynamic>? ?? const []);
      final members = membersRaw
          .map((item) => _AdminMember.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Nao foi possivel carregar membros.";
      });
      debugPrint("Load admin members error: $error");
    }
  }

  Future<void> _runAction({
    required String path,
    required _AdminMember member,
    String? reason,
    String? role,
    String? expiresAt
  }) async {
    try {
      final payload = <String, dynamic>{
        "serverId": kServerId,
        "targetUserId": member.userId
      };
      if (reason != null) payload["reason"] = reason;
      if (role != null) payload["role"] = role;
      if (expiresAt != null) payload["expiresAt"] = expiresAt;

      final response = await http.post(
        _url(path),
        headers: await _authHeaders(),
        body: jsonEncode(payload)
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha na acao administrativa.");
      }
      await _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A acao nao foi concluida. Verifique suas permissoes."))
      );
      debugPrint("Admin member action error: $error");
    }
  }

  Future<void> _changeRole(_AdminMember member) async {
    String selectedRole = member.role;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Alterar cargo"),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: "member", child: Text("member")),
                  DropdownMenuItem(value: "moderator", child: Text("moderator")),
                  DropdownMenuItem(value: "admin", child: Text("admin")),
                  DropdownMenuItem(value: "owner", child: Text("owner"))
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setInnerState(() => selectedRole = value);
                }
              );
            }
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Salvar"))
          ]
        );
      }
    );

    if (confirmed != true) return;
    await _runAction(path: "/admin/members/set-role", member: member, role: selectedRole);
  }

  Future<void> _quickReasonAction({
    required _AdminMember member,
    required String path,
    required String title
  }) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: "Motivo (opcional)")
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            FilledButton(
              onPressed: () => Navigator.pop(context, reasonController.text.trim()),
              child: const Text("Confirmar")
            )
          ]
        );
      }
    );

    if (reason == null) return;
    await _runAction(path: path, member: member, reason: reason.isEmpty ? null : reason);
  }

  Future<void> _mute(_AdminMember member) async {
    final reasonController = TextEditingController();
    final expiresController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Mutar membro"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: "Motivo (opcional)")
              ),
              const SizedBox(height: 10),
              TextField(
                controller: expiresController,
                decoration: const InputDecoration(
                  labelText: "Expira em (ISO-8601, opcional)",
                  hintText: "2026-12-31T23:59:59Z"
                )
              )
            ]
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Mutar"))
          ]
        );
      }
    );

    if (confirmed != true) return;
    await _runAction(
      path: "/admin/members/mute",
      member: member,
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      expiresAt: expiresController.text.trim().isEmpty ? null : expiresController.text.trim()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciar Membros")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _members.isEmpty
                  ? const Center(child: Text("Nenhum membro encontrado."))
                  : RefreshIndicator(
                      onRefresh: _loadMembers,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isBanned = member.isBanned;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: Text(
                                          member.displayName.isNotEmpty
                                              ? member.displayName[0].toUpperCase()
                                              : "M"
                                        )
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(member.displayName),
                                            Text(
                                              "${member.role} | ${isBanned ? 'banido' : 'ativo'}",
                                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)
                                            )
                                          ]
                                        )
                                      )
                                    ]
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _changeRole(member),
                                        child: const Text("Cargo")
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _quickReasonAction(
                                          member: member,
                                          path: "/admin/members/kick",
                                          title: "Expulsar membro"
                                        ),
                                        child: const Text("Expulsar")
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _mute(member),
                                        child: const Text("Mutar")
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _runAction(
                                          path: "/admin/members/unmute",
                                          member: member
                                        ),
                                        child: const Text("Desmutar")
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _quickReasonAction(
                                          member: member,
                                          path: isBanned ? "/admin/members/unban" : "/admin/members/ban",
                                          title: isBanned ? "Desbanir membro" : "Banir membro"
                                        ),
                                        child: Text(isBanned ? "Desbanir" : "Banir")
                                      )
                                    ]
                                  )
                                ]
                              )
                            )
                          );
                        }
                      )
                    )
    );
  }
}

class AdminLogsPage extends ConsumerStatefulWidget {
  const AdminLogsPage({super.key});

  @override
  ConsumerState<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends ConsumerState<AdminLogsPage> {
  bool _loading = true;
  String? _error;
  List<_AdminLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  Uri _url(String path) {
    if (AppEnv.backendBaseUrl.isEmpty) {
      throw Exception("BACKEND_BASE_URL nao configurado.");
    }
    return Uri.parse("${AppEnv.backendBaseUrl}$path");
  }

  Future<Map<String, String>> _authHeaders() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) throw Exception("Sessao expirada.");
    return {
      "content-type": "application/json",
      "authorization": "Bearer ${session.accessToken}"
    };
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        _url("/admin/logs/list"),
        headers: await _authHeaders(),
        body: jsonEncode({"serverId": kServerId, "limit": 200})
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body["error"]?.toString() ?? "Falha ao carregar logs.");
      }

      final logsRaw = (body["logs"] as List<dynamic>? ?? const []);
      final logs = logsRaw.map((item) => _AdminLog.fromMap(item as Map<String, dynamic>)).toList();

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Nao foi possivel carregar logs.";
      });
      debugPrint("Load admin logs error: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logs Administrativos")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _logs.isEmpty
                  ? const Center(child: Text("Nenhum log registrado."))
                  : RefreshIndicator(
                      onRefresh: _loadLogs,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final log = _logs[index];
                          return Card(
                            child: ListTile(
                              title: Text(log.action),
                              subtitle: Text(
                                "ator: ${log.actorId}\n"
                                "alvo: ${log.targetUserId ?? '-'}\n"
                                "quando: ${log.createdAt}\n"
                                "meta: ${log.metadata}"
                              ),
                              isThreeLine: true
                            )
                          );
                        }
                      )
                    )
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});
  @override
  Widget build(BuildContext context) => const _SimpleAdminPlaceholder(
        title: "Acesso Negado",
        subtitle: "Seu usuario nao possui permissao para essa acao."
      );
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap
      )
    );
  }
}

class _SimpleAdminPlaceholder extends StatelessWidget {
  const _SimpleAdminPlaceholder({
    required this.title,
    required this.subtitle
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(subtitle)
          )
        )
      )
    );
  }
}

class _AdminMember {
  _AdminMember({
    required this.userId,
    required this.role,
    required this.displayName,
    required this.avatarUrl,
    required this.isBanned
  });

  final String userId;
  final String role;
  final String displayName;
  final String? avatarUrl;
  final bool isBanned;

  factory _AdminMember.fromMap(Map<String, dynamic> map) {
    final profile = map["profile"];
    final profileMap = profile is Map<String, dynamic> ? profile : const <String, dynamic>{};

    final displayName = (profileMap["display_name"] as String? ?? "Membro").trim();
    return _AdminMember(
      userId: map["user_id"] as String,
      role: map["role"] as String? ?? "member",
      displayName: displayName.isEmpty ? "Membro" : displayName,
      avatarUrl: profileMap["avatar_url"] as String?,
      isBanned: profileMap["is_banned"] == true
    );
  }
}

class _AdminLog {
  _AdminLog({
    required this.id,
    required this.actorId,
    required this.targetUserId,
    required this.action,
    required this.createdAt,
    required this.metadata
  });

  final String id;
  final String actorId;
  final String? targetUserId;
  final String action;
  final String createdAt;
  final String metadata;

  factory _AdminLog.fromMap(Map<String, dynamic> map) {
    return _AdminLog(
      id: map["id"] as String,
      actorId: map["actor_id"] as String? ?? "-",
      targetUserId: map["target_user_id"] as String?,
      action: map["action"] as String? ?? "-",
      createdAt: map["created_at"] as String? ?? "-",
      metadata: jsonEncode(map["metadata"] ?? {})
    );
  }
}

class _AdminInvite {
  _AdminInvite({
    required this.id,
    required this.code,
    required this.currentUses,
    required this.maxUses,
    required this.isActive
  });

  final String id;
  final String code;
  final int currentUses;
  final int? maxUses;
  final bool isActive;

  factory _AdminInvite.fromMap(Map<String, dynamic> map) {
    return _AdminInvite(
      id: map["id"] as String,
      code: map["code"] as String? ?? "-",
      currentUses: (map["current_uses"] as num?)?.toInt() ?? 0,
      maxUses: (map["max_uses"] as num?)?.toInt(),
      isActive: map["is_active"] == true
    );
  }
}
