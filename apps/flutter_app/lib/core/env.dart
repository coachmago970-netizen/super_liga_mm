class AppEnv {
  static const String supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");
  static const String supabasePublishableKey =
      String.fromEnvironment("SUPABASE_PUBLISHABLE_KEY", defaultValue: "");
  static const String livekitUrl = String.fromEnvironment("LIVEKIT_URL", defaultValue: "");
  static const String backendBaseUrl = String.fromEnvironment("BACKEND_BASE_URL", defaultValue: "");
}
