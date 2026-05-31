import "package:supabase_flutter/supabase_flutter.dart";

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;
  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> onAuthStateChange() {
    final client = _client;
    if (client == null) return const Stream<AuthState>.empty();
    return client.auth.onAuthStateChange;
  }

  Future<void> signIn({
    required String email,
    required String password
  }) async {
    final client = _requireClient();
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String emailRedirectTo
  }) async {
    final client = _requireClient();
    try {
      await client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: emailRedirectTo,
        data: {
          "display_name": displayName.trim()
        }
      );
    } on AuthException catch (error) {
      if (_isRedirectConfigError(error.message)) {
        await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            "display_name": displayName.trim()
          }
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> sendPasswordReset({
    required String email,
    required String redirectTo
  }) async {
    final client = _requireClient();
    try {
      await client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);
    } on AuthException catch (error) {
      if (_isRedirectConfigError(error.message)) {
        await client.auth.resetPasswordForEmail(email.trim());
        return;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = _requireClient();
    await client.auth.signOut();
  }

  Future<void> ensureProfile({
    required String userId,
    required String? email
  }) async {
    final client = _requireClient();
    final existing = await client.from("profiles").select("id").eq("id", userId).maybeSingle();
    if (existing != null) return;

    await client.from("profiles").insert({
      "id": userId,
      "display_name": (email ?? "membro").split("@").first
    });
  }

  String mapAuthError({
    required Object error,
    required String fallback
  }) {
    final message = error.toString().toLowerCase();

    if (message.contains("signup_disabled")) {
      return "Cadastro desativado no Supabase.";
    }
    if (message.contains("user already registered") || message.contains("already registered")) {
      return "Este e-mail ja esta cadastrado.";
    }
    if (message.contains("invalid login credentials")) {
      return "E-mail ou senha invalidos.";
    }
    if (message.contains("email not confirmed") || message.contains("email_not_confirmed")) {
      return "Confirme seu e-mail antes de entrar.";
    }
    if (message.contains("password") && message.contains("at least")) {
      return "A senha nao atende os requisitos minimos.";
    }
    if (_isRedirectConfigError(message)) {
      return "Ajuste pendente no Supabase: redirect URL do Auth.";
    }

    return fallback;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw Exception("Supabase nao configurado. Confira as variaveis do app.");
    }
    return client;
  }

  bool _isRedirectConfigError(String value) {
    final message = value.toLowerCase();
    return message.contains("redirect")
        || message.contains("email_redirect_to")
        || message.contains("not allowed")
        || message.contains("invalid redirect");
  }
}
