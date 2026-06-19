import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// TODO (TV4 — Tuần 1):
// 1. Chạy: flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
// 2. Thêm google-services.json vào android/app/
// 3. Thêm GoogleService-Info.plist vào ios/Runner/
// 4. Uncomment các dòng Firebase bên dưới sau khi cấu hình xong

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  // ── Hive init (TV3 setup) ─────────────────────────────────────────────────
  // await Hive.initFlutter();
  // Hive.registerAdapter(LogEntryModelAdapter());

  runApp(const ForestCarbonApp());
}
