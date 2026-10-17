import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(); // sozlama bo'lmasa o'tkazib yuboradi, ilova ochiladi
  runApp(const ProviderScope(child: HosilApp()));
}
