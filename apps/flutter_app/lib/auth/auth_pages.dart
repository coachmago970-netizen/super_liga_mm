import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "auth_providers.dart";

const String _authRedirect = "superligamm://auth-callback";

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Super Liga M&M",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Plataforma de Comunicacao",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280))
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.go("/login"),
                    child: const Text("Entrar")
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go("/register"),
                    child: const Text("Criar Conta")
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go("/invite"),
                    child: const Text("Entrar com Convite")
                  )
                ]
              )
            )
          )
        )
      )
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signIn(
        email: _emailController.text,
        password: _passwordController.text
      );
      final user = repository.currentUser;
      if (user != null) {
        await repository.ensureProfile(userId: user.id, email: user.email);
      }
      if (!mounted) return;
      context.go("/server");
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = "Nao foi possivel entrar. Confira e-mail e senha.");
      debugPrint("Login error: $error");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: "Entrar",
      subtitle: "Use seu e-mail e senha para acessar a comunidade.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "E-mail"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Informe seu e-mail.";
                if (!value.contains("@")) return "Digite um e-mail valido.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Senha"),
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 6) return "Senha minima de 6 caracteres.";
                return null;
              }
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : () => context.go("/forgot-password"),
                child: const Text("Esqueci minha senha")
              )
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 8)
            ],
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? "Entrando..." : "Entrar")
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.go("/register"),
              child: const Text("Nao tenho conta")
            )
          ]
        )
      )
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
        emailRedirectTo: _authRedirect
      );
      if (!mounted) return;
      context.go("/email-confirmation");
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = "Nao foi possivel criar conta agora.");
      debugPrint("Register error: $error");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: "Criar conta",
      subtitle: "Entre para o servidor privado da Super Liga M&M.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: "Nome de exibicao"),
              validator: (value) {
                if (value == null || value.trim().length < 2) return "Minimo de 2 caracteres.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "E-mail"),
              validator: (value) {
                if (value == null || !value.contains("@")) return "Digite um e-mail valido.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Senha"),
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 8) return "Senha minima de 8 caracteres.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: "Confirmar senha"),
              obscureText: true,
              validator: (value) {
                if (value != _passwordController.text) return "As senhas nao coincidem.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            const Text(
              "Ao continuar, voce concorda com Termos e Privacidade.",
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 8)
            ],
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? "Criando..." : "Criar conta")
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.go("/login"),
              child: const Text("Ja tenho conta")
            )
          ]
        )
      )
    );
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendPasswordReset(
        email: _emailController.text,
        redirectTo: _authRedirect
      );
      if (!mounted) return;
      setState(() {
        _message = "Se o e-mail existir, enviamos um link para redefinir sua senha.";
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = "Nao foi possivel enviar agora.");
      debugPrint("Reset password error: $error");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: "Recuperar senha",
      subtitle: "Vamos te enviar um link de recuperacao no e-mail.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "E-mail"),
              validator: (value) {
                if (value == null || !value.contains("@")) return "Digite um e-mail valido.";
                return null;
              }
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 8)
            ],
            if (_message != null) ...[
              Text(_message!, style: const TextStyle(color: Color(0xFF16A34A))),
              const SizedBox(height: 8)
            ],
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? "Enviando..." : "Enviar link")
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.go("/login"),
              child: const Text("Voltar para login")
            )
          ]
        )
      )
    );
  }
}

class EmailConfirmationPage extends StatelessWidget {
  const EmailConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: "Confirme seu e-mail",
      subtitle: "Enviamos um e-mail de confirmacao. Depois de confirmar, faca login.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Se nao encontrar na caixa de entrada, confira spam ou lixo eletronico.",
            style: TextStyle(color: Color(0xFF6B7280))
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go("/login"),
            child: const Text("Ir para login")
          )
        ]
      )
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700
                            )
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF6B7280))
                      ),
                      const SizedBox(height: 18),
                      child
                    ]
                  )
                )
              )
            )
          )
        )
      )
    );
  }
}
