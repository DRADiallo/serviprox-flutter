import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';

// ← Handler notifications en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notification arrière-plan: "
    "${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ← Initialiser Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions
        .currentPlatform,
    );

    // ← Handler arrière-plan
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

    // ← Notifications en arrière-plan
    // Ne pas bloquer si erreur !
    NotificationService.initialize()
      .catchError((e) {
        debugPrint("⚠️ FCM init ignoré: $e");
      });

  } catch (e) {
    // ← Firebase échoue → app continue quand même !
    debugPrint("⚠️ Firebase ignoré: $e");
  }

  runApp(const ServiProxApp());
}
class ServiProxApp extends StatelessWidget {
  const ServiProxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiProx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}