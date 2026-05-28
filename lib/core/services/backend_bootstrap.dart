import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';

Future<void> initializeBackend() async {
  if (!BackendConfig.useSupabase) {
    return;
  }

  if (!BackendConfig.hasSupabaseConfig) {
    throw StateError(
      'Supabase backend selected, but SUPABASE_URL or SUPABASE_ANON_KEY is missing.',
    );
  }

  await Supabase.initialize(
    url: BackendConfig.supabaseUrl,
    anonKey: BackendConfig.supabaseAnonKey,
  );
}
