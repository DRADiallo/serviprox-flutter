import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'auth_storage.dart';

class NotificationService {

  static final FirebaseMessaging _messaging =
    FirebaseMessaging.instance;
    static const String _vapidKey =
  'BJzYH5i95P518r6U8VJub5nSeSdjAQjFTXLZhpuAMrPYnMhr72USq9gJUzLxZQY9fXToPZvkFscG5k1MsFrg3P8';

  // ← Initialiser
  static Future<void> initialize() async {
  try {
    // ← Simple sans timeout complexe
    final settings =
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

    if (settings.authorizationStatus !=
        AuthorizationStatus.authorized) {
      debugPrint("⚠️ Notifications non autorisées");
      return;
    }

    // ← Token simple
    final token = await _messaging
      .getToken(vapidKey: _vapidKey);

    if (token != null) {
      await _saveTokenToBackend(token);
    }

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationClick);

  } catch (e) {
    // ← Ignorer toute erreur FCM
    debugPrint("⚠️ FCM ignoré: $e");
  }
}
    // ← Token avec timeout
   

// ← Appeler après login
static Future<void> saveFcmTokenAfterLogin()
    async {
  try {
    final token = await _messaging.getToken(
      vapidKey: _vapidKey,
    );
    if (token != null) {
      await _saveTokenToBackend(token);
      debugPrint(
        "✅ FCM Token sauvegardé après login");
    }
  } catch (e) {
    debugPrint("⚠️ Erreur FCM: $e");
  }
}

  // ← Envoyer token FCM au backend
  // ← MODIFICATION : _saveTokenToBackend
static Future<void> _saveTokenToBackend(
    String fcmToken) async {
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    final role   = await AuthStorage.getRole();

    // ← Si pas encore connecté → ignorer
    if (token == null || userId == null) {
      debugPrint("⚠️ Pas encore connecté "
        "→ FCM token ignoré");
      return;
    }

    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/notification'
        '/fcm-token'
        '?userId=$userId'
        '&role=$role'
        '&fcmToken=${Uri.encodeComponent(fcmToken)}'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      debugPrint("✅ FCM Token sauvegardé !");
    }
  } catch (e) {
    debugPrint("Erreur save FCM token: $e");
  }
}

  // ← Notification en premier plan
static void _handleForegroundMessage(
      RemoteMessage message) {
    debugPrint("📲 Notification reçue : "
      "${message.notification?.title}");
  }

// ← Clic sur notification
  static void _handleNotificationClick(
      RemoteMessage message) {
    debugPrint("👆 Notification cliquée : "
      "${message.data}");
  }
}