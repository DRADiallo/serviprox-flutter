// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'core/theme/app_theme.dart';
// import 'core/services/notification_service.dart';
// import 'features/auth/splash_screen.dart';
// import 'firebase_options.dart';

// // ← Handler notifications en arrière-plan
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message) async {
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform);
//   debugPrint("Notification arrière-plan: "
//     "${message.notification?.title}");
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     // ← Initialiser Firebase
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions
//         .currentPlatform,
//     );

//     // ← Handler arrière-plan
//     FirebaseMessaging.onBackgroundMessage(
//       _firebaseMessagingBackgroundHandler);

//     // ← Notifications en arrière-plan
//     // Ne pas bloquer si erreur !
//     NotificationService.initialize()
//       .catchError((e) {
//         debugPrint("⚠️ FCM init ignoré: $e");
//       });

//   } catch (e) {
//     // ← Firebase échoue → app continue quand même !
//     debugPrint("⚠️ Firebase ignoré: $e");
//   }

//   runApp(const ServiProxApp());
// }
// class ServiProxApp extends StatelessWidget {
//   const ServiProxApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'ServiProx',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.lightTheme,
//       home: const SplashScreen(),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:memoireserviprox/core/controllers/SettingsProvider.dart';
import 'package:memoireserviprox/features/client/ClientHomeScreen.dart';
import 'package:provider/provider.dart';
import 'package:memoireserviprox/features/commande/nouvelle_commande_screen.dart';
import 'package:memoireserviprox/features/prestataire/Commande_detail_screen.dart';
// ── Côté client ─────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────────────────
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';

import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notification arrière-plan: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);
    NotificationService.initialize().catchError((e) {
      debugPrint("⚠️ FCM init ignoré: $e");
    });
  } catch (e) {
    debugPrint("⚠️ Firebase ignoré: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const ServiProxApp(),
    ),
  );
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

      onGenerateRoute: (routeSettings) {
        final args =
            routeSettings.arguments as Map<String, dynamic>?;

        switch (routeSettings.name) {

          // ── Accueil client ─────────────────────────────────────────────
          case '/client-home':
            return MaterialPageRoute(
              builder: (_) => const ClientHomeScreen(),
            );

          // ── Nouvelle commande (générique) ──────────────────────────────
          case '/nouvelle-commande':
            return MaterialPageRoute(
              builder: (_) => NouvelleCommandeScreen(
                prestataire:
                    args?['prestataire'] as Map<String, dynamic>? ?? {},
              ));

          // ── Détail commande prestataire ────────────────────────────────
          case '/commande-detail':
            return MaterialPageRoute(
              builder: (_) => CommandeDetailScreen(
                commande:
                    args?['commande'] as Map<String, dynamic>? ?? {},
                etapesEffectives:
                    (args?['etapesEffectives'] as List<dynamic>? ?? [])
                        .cast<String>(),
                agents: (args?['agents'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>(),
                prestataireId: args?['prestataireId'] as int? ?? 0,
              ));

          default:
            return null;
        }
      },
    );
  }
}