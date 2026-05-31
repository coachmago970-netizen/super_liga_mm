import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../auth/auth_providers.dart";

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 500), _routeFromSession);
  }

  void _routeFromSession() {
    if (!mounted) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      context.go("/welcome");
      return;
    }
    context.go("/server");
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator()
      )
    );
  }
}

class ServerHomePage extends ConsumerWidget {
  const ServerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final repository = ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Super Liga M&M"),
        actions: [
          IconButton(
            tooltip: "Sair",
            onPressed: () async {
              await repository.signOut();
              if (!context.mounted) return;
              context.go("/welcome");
            },
            icon: const Icon(Icons.logout)
          )
        ]
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text(user?.email ?? "Usuario"),
                subtitle: const Text("Servidor unico: Super Liga M&M"),
                leading: const CircleAvatar(child: Icon(Icons.person))
              )
            ),
            const SizedBox(height: 12),
            _NavCard(
              title: "Chat Geral",
              subtitle: "Canal de texto em tempo real",
              icon: Icons.chat_bubble_outline,
              onTap: () => context.push("/chat/geral")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Canal de Voz",
              subtitle: "Entrar em calls por equipe e compartilhar tela",
              icon: Icons.graphic_eq,
              onTap: () => context.push("/voice-channel")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Membros Online",
              subtitle: "Quem esta conectado agora",
              icon: Icons.people_alt_outlined,
              onTap: () => context.push("/members-online")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Convites",
              subtitle: "Validar e usar um convite",
              icon: Icons.link,
              onTap: () => context.push("/invite")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Painel Admin",
              subtitle: "Convites, membros e logs",
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => context.push("/admin")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Perfil",
              subtitle: "Editar nome de exibicao e avatar",
              icon: Icons.badge_outlined,
              onTap: () => context.push("/profile")
            ),
            const SizedBox(height: 10),
            _NavCard(
              title: "Configuracoes",
              subtitle: "Opcoes da conta e sessao",
              icon: Icons.settings_outlined,
              onTap: () => context.push("/settings")
            )
          ]
        )
      )
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
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
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: const Color(0xFF2563EB),
          child: Icon(icon)
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap
      )
    );
  }
}
