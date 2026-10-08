class ApiConstants {
  // ← Chrome → localhost
  // Samsung → '192.168.1.239'
  static const String _host = 'localhost';

  static const String baseUrl =
      'http://$_host:7090/api';

  static const String registerClient =
      '$baseUrl/auth/register/client';

  static const String registerPrestataire =
      '$baseUrl/auth/register/prestataire';

  static const String login =
      '$baseUrl/auth/login';

  // ← AJOUT : OTP endpoints
  static const String verifyOtp =
      '$baseUrl/auth/verify-otp';

  static const String resendOtp =
      '$baseUrl/auth/resend-otp';

  // ← AJOUT : Login agent
  static const String loginAgent =
      '$baseUrl/auth/login/agent';

  static const String prestataires =
      '$baseUrl/prestataire';

  static const String servicesActifs =
      '$baseUrl/service-config/actifs';

  static const String commandes =
      '$baseUrl/commande';

  static const String admin =
      '$baseUrl/admin';
}















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

