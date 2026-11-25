class ApiConstants {
  // ← Remplacer par l'IP de votre machine
  // Chrome (émulateur) → 10.0.2.2
  // Samsung (physique) → '192.168.1.239'
  static const String _host = '192.168.1.239';
  //static const String _host = 'localhost';

  static const String baseUrl =
      'http://$_host:7090/api';

  // ── Auth ──────────────────────────────────────────
  static const String registerClient =
      '$baseUrl/auth/register/client';

  static const String registerPrestataire =
      '$baseUrl/auth/register/prestataire';

  static const String login =
      '$baseUrl/auth/login';

  static const String verifyOtp =
      '$baseUrl/auth/verify-otp';

  static const String resendOtp =
      '$baseUrl/auth/resend-otp';

  static const String loginAgent =
      '$baseUrl/auth/login/agent';

  // ── Prestataire ───────────────────────────────────
  static const String prestataires =
      '$baseUrl/prestataire';

  // ← AJOUT : configuration prestataire
  // Utilisé par ConfigurerServiceScreen
  // POST   /api/prestataire/config/{id}  → configurer
  // GET    /api/prestataire/config/{id}  → lire config
  // PUT    /api/prestataire/config/{id}/tarifs
  // PUT    /api/prestataire/config/{id}/zone
  // PUT    /api/prestataire/config/{id}/disponibilite
  static const String prestataireConfig =
      '$baseUrl/prestataire/config';

  // ── Services ──────────────────────────────────────
  static const String servicesActifs =
      '$baseUrl/service-config/actifs';

  // ── Commandes (SINGULIER — correspond au backend) ─
  static const String commandes =
      '$baseUrl/commande';

  // ── Admin ─────────────────────────────────────────
  static const String admin =
      '$baseUrl/admin';
}



// class ApiConstants {
//   // ← Chrome → localhost / Samsung → '192.168.1.239'
//   static const String _host = '192.168.1.239';

//   static const String baseUrl =
//       'http://$_host:7090/api';

//   // ══════════════════════════════════════════════
//   // AUTH
//   // ══════════════════════════════════════════════
//   static const String registerClient =
//       '$baseUrl/auth/register/client';

//   static const String registerPrestataire =
//       '$baseUrl/auth/register/prestataire';

//   static const String login =
//       '$baseUrl/auth/login';

//   static const String verifyOtp =
//       '$baseUrl/auth/verify-otp';

//   static const String resendOtp =
//       '$baseUrl/auth/resend-otp';

//   static const String loginAgent =
//       '$baseUrl/auth/login/agent';

//   // ══════════════════════════════════════════════
//   // PRESTATAIRE
//   // ══════════════════════════════════════════════
//   static const String prestataires =
//       '$baseUrl/prestataire';

//   /// Config du prestataire (disponibilité, étapes, modes dépôt)
//   /// → /api/prestataire/config/{id}
//   static const String prestataireConfig =
//       '$baseUrl/prestataire/config';

//   /// Agents liés à un prestataire
//   /// → /api/agents/prestataire/{id}
//   static const String agentsPrestataire =
//       '$baseUrl/agents/prestataire';

//   // ══════════════════════════════════════════════
//   // COMMANDES
//   // ══════════════════════════════════════════════
//   static const String commandes =
//       '$baseUrl/commande';

//   // ══════════════════════════════════════════════
//   // SERVICE CONFIG (liste publique)
//   // ══════════════════════════════════════════════
//   static const String servicesActifs =
//       '$baseUrl/service-config/actifs';

//   // ══════════════════════════════════════════════
//   // NOTIFICATIONS (FCM tokens)
//   // ══════════════════════════════════════════════
//   static const String notification =
//       '$baseUrl/notification';

//   // ══════════════════════════════════════════════
//   // PAIEMENT (NabooPay)
//   // ══════════════════════════════════════════════
//   static const String paiement =
//       '$baseUrl/paiement';

//   // ══════════════════════════════════════════════
//   // ADMIN
//   // ══════════════════════════════════════════════
//   static const String admin =
//       '$baseUrl/admin';
// }




// class ApiConstants {
//   // ← Chrome → localhost
//   // Samsung → '192.168.1.239'
//   static const String _host = '192.168.1.239';

//   static const String baseUrl =
//       'http://$_host:7090/api';

//   static const String registerClient =
//       '$baseUrl/auth/register/client';

//   static const String registerPrestataire =
//       '$baseUrl/auth/register/prestataire';

//   static const String login =
//       '$baseUrl/auth/login';

//   // ← AJOUT : OTP endpoints
//   static const String verifyOtp =
//       '$baseUrl/auth/verify-otp';

//   static const String resendOtp =
//       '$baseUrl/auth/resend-otp';

//   // ← AJOUT : Login agent
//   static const String loginAgent =
//       '$baseUrl/auth/login/agent';

//   static const String prestataires =
//       '$baseUrl/prestataire';

//   static const String servicesActifs =
//       '$baseUrl/service-config/actifs';

//   static const String commandes =
//       '$baseUrl/commande';

//   static const String admin =
//       '$baseUrl/admin';
// }















//class ApiConstants {
  // ← CORRECTION : 127.0.0.1 au lieu de localhost
  // Chrome traite parfois localhost et 127.0.0.1 différemment

  // Samsung    → '192.168.1.239'
  //static const String _host = '192.168.1.239';

//   static const String baseUrl =
//       'http://127.0.0.1:7090/api';

//   static const String registerClient =
//       '$baseUrl/auth/register/client';

//   static const String registerPrestataire =
//       '$baseUrl/auth/register/prestataire';

//   static const String login =
//       '$baseUrl/auth/login';

//   static const String prestataires =
//       '$baseUrl/prestataire';

//   static const String servicesActifs =
//       '$baseUrl/service-config/actifs';

//   static const String commandes =
//       '$baseUrl/commande';

//   static const String admin =
//       '$baseUrl/admin';
// }


// class ApiConstants {
//   // ← URL backend Spring Boot
//   // Sur téléphone physique — utilisez l'IP de votre PC
//   // pas localhost ! (localhost = le téléphone lui-même)
//   static const String baseUrl = 'http://192.168.1.X:7090/api';

//   // Endpoints Auth
//   static const String registerClient =
//       '$baseUrl/auth/register/client';
//   static const String registerPrestataire =
//       '$baseUrl/auth/register/prestataire';
//   static const String login =
//       '$baseUrl/auth/login';
// }

