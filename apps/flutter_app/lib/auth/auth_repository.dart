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
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: emailRedirectTo,
      data: {
        "display_name": displayName.trim()
      }
    );
  }

  Future<void> sendPasswordReset({
    required String email,
    required String redirectTo
  }) async {
    final client = _requireClient();
    await client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);
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

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw Exception("Supabase nao configurado. Confira as variaveis do app.");
    }
    return client;
  }
}
