import "package:supabase_flutter/supabase_flutter.dart";
import "env.dart";

Future<void> bootstrapApp() async {
  if (AppEnv.supabaseUrl.isEmpty || AppEnv.supabasePublishableKey.isEmpty) {
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabasePublishableKey
  );
}
