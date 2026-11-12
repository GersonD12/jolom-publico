import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/app/view/app.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';
import 'package:jolom/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android e iOS cargan automáticamente el archivo Firebase de su flavor.
  await Firebase.initializeApp();
  await FcmService.init();
  await setupDI();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const App(),
    ),
  );
}
