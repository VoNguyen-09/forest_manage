import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/app.dart';

// TODO (TV4 — Tuần 1):
// 1. Chạy: flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
// 2. Thêm google-services.json vào android/app/
// 3. Thêm GoogleService-Info.plist vào ios/Runner/
// 4. Uncomment các dòng Firebase bên dưới sau khi cấu hình xong

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase init (uncomment sau khi TV4 setup) ──────────────────────────
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // ── Hive init (TV3 setup) ─────────────────────────────────────────────────
  // await Hive.initFlutter();
  // Hive.registerAdapter(LogEntryModelAdapter());

  runApp(const ForestCarbonApp());
}
