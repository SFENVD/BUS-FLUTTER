enum BackendMode {
  auto('auto'),
  mock('mock'),
  supabase('supabase');

  const BackendMode(this.value);

  final String value;

  static BackendMode fromValue(String value) {
    return BackendMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => BackendMode.auto,
    );
  }
}

class BackendConfig {
  const BackendConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const rawBackendMode = String.fromEnvironment(
    'BACKEND',
    defaultValue: 'auto',
  );

  static BackendMode get backendMode => BackendMode.fromValue(rawBackendMode);

  static bool get hasSupabaseConfig {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  static bool get useSupabase {
    return switch (backendMode) {
      BackendMode.supabase => true,
      BackendMode.mock => false,
      BackendMode.auto => hasSupabaseConfig,
    };
  }

  static String get activeBackendLabel {
    return useSupabase ? 'Supabase' : 'Mock';
  }
}
