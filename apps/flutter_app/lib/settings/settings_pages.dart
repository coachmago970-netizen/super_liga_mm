import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../auth/auth_providers.dart";
import "../call/call_session.dart";
import "../core/supabase_provider.dart";

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _displayNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _formError;
  String? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _formError = null;
      _success = null;
    });

    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (client == null || user == null) {
      setState(() {
        _loading = false;
        _loadError = "Sessao indisponivel para carregar perfil.";
      });
      return;
    }

    try {
      final row = await client
          .from("profiles")
          .select("display_name, avatar_url")
          .eq("id", user.id)
          .maybeSingle();

      final baseName = user.email?.split("@").first ?? "membro";
      if (!mounted) return;
      setState(() {
        if (row is Map<String, dynamic>) {
          final rawName = (row["display_name"] as String? ?? baseName).trim();
          _displayNameController.text = rawName.isEmpty ? baseName : rawName;
          _avatarUrlController.text = (row["avatar_url"] as String? ?? "").trim();
        } else {
          _displayNameController.text = baseName;
          _avatarUrlController.text = "";
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Nao foi possivel carregar perfil agora.";
      });
      debugPrint("Profile load error: $error");
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (client == null || user == null) return;

    final name = _displayNameController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();

    if (name.length < 2) {
      setState(() => _formError = "Nome de exibicao deve ter ao menos 2 caracteres.");
      return;
    }
    if (name.length > 80) {
      setState(() => _formError = "Nome de exibicao deve ter no maximo 80 caracteres.");
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
      _success = null;
    });

    try {
      await client.from("profiles").upsert({
        "id": user.id,
        "display_name": name,
        "avatar_url": avatarUrl.isEmpty ? null : avatarUrl,
        "updated_at": DateTime.now().toIso8601String()
      });

      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = "Perfil atualizado com sucesso.";
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = "Nao foi possivel salvar seu perfil.";
      });
      debugPrint("Profile save error: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _loadProfile,
                          child: const Text("Tentar novamente")
                        )
                      ]
                    )
                  )
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Conta",
                              style: TextStyle(fontWeight: FontWeight.w700)
                            ),
                            const SizedBox(height: 8),
                            Text("E-mail: ${user?.email ?? "-"}"),
                            const SizedBox(height: 4),
                            Text("ID: ${user?.id ?? "-"}")
                          ]
                        )
                      )
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Dados publicos",
                              style: TextStyle(fontWeight: FontWeight.w700)
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(labelText: "Nome de exibicao")
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _avatarUrlController,
                              decoration: const InputDecoration(
                                labelText: "Avatar URL (opcional)"
                              )
                            ),
                            const SizedBox(height: 12),
                            if (_success != null) ...[
                              Text(
                                _success!,
                                style: const TextStyle(color: Color(0xFF16A34A))
                              ),
                              const SizedBox(height: 8)
                            ],
                            if (_formError != null) ...[
                              Text(
                                _formError!,
                                style: const TextStyle(color: Color(0xFFEF4444))
                              ),
                              const SizedBox(height: 8)
                            ],
                            FilledButton(
                              onPressed: _saving ? null : _saveProfile,
                              child: Text(_saving ? "Salvando..." : "Salvar perfil")
                            )
                          ]
                        )
                      )
                    )
                  ]
                )
    );
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _signingOut = false;

  Future<void> _clearVoiceSession() async {
    ref.read(voiceSessionProvider.notifier).state = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sessao de voz local foi limpa."))
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(voiceSessionProvider.notifier).state = null;
      if (!mounted) return;
      context.go("/welcome");
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nao foi possivel sair agora."))
      );
      debugPrint("Sign out error: $error");
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuracoes")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Perfil"),
                  subtitle: const Text("Editar nome e avatar"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push("/profile")
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.graphic_eq),
                  title: const Text("Canal de voz"),
                  subtitle: const Text("Entrar no canal e chamar"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push("/voice-channel")
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cast),
                  title: const Text("Compartilhamento de tela"),
                  subtitle: const Text("Guia por plataforma"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push("/screen-share")
                )
              ]
            )
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text("Limpar sessao de voz"),
                  subtitle: const Text("Remove token local de chamada"),
                  onTap: _clearVoiceSession
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Sair da conta"),
                  subtitle: const Text("Encerrar sessao atual"),
                  onTap: _signingOut ? null : _signOut
                )
              ]
            )
          ),
          if (_signingOut) ...[
            const SizedBox(height: 10),
            const Center(child: CircularProgressIndicator())
          ]
        ]
      )
    );
  }
}
