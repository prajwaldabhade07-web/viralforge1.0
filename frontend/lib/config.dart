/// Public build-time configuration, injected with --dart-define-from-file=config.json.
/// Only public values live here: the Supabase anon key and the API URL. Secrets never do.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api/v1');

  static bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
