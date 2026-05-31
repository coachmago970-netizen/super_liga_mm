import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../core/supabase_provider.dart";
import "auth_repository.dart";

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

final authSessionStreamProvider = StreamProvider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository
      .onAuthStateChange()
      .map((event) => event.session)
      .handleError((Object _, StackTrace __) {});
});

final currentSessionProvider = Provider<Session?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final streamSession = ref.watch(authSessionStreamProvider).valueOrNull;
  return streamSession ?? repository.currentSession;
});

final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session?.user;
});
