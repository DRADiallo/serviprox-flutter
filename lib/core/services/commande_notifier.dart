// lib/core/services/commande_notifier.dart
// Notifier global partagé entre tous les écrans de commandes
import 'package:flutter/foundation.dart';

/// Incrémenté à chaque notification FCM "commande"
/// → déclenche _loadCommandes(silent) sur tous les écrans abonnés
final ValueNotifier<int> commandeRefreshTrigger = ValueNotifier(0);