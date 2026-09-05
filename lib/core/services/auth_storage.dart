// ═══════════════════════════════════════════════════════
// auth_storage.dart
//
// RÔLE : Gérer le stockage local du token JWT
//        et des infos utilisateur
//
// SharedPreferences = stockage clé-valeur sur le téléphone
// → Comme une Map<String, String> qui persiste
//   même après fermeture de l'app
//
// Exemple :
// await AuthStorage.saveToken("eyJhbGci...")
// → Stocké sur le téléphone
// → Disponible à la prochaine ouverture
// ═══════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {

  // ── Clés de stockage ──────────────────────────────
  // Constantes pour éviter les fautes de frappe
  // Ex: 'token' partout → une seule définition ici
  static const String _keyToken   = 'token';
  static const String _keyUserId  = 'userId';
  static const String _keyNom     = 'nom';
  static const String _keyPrenom  = 'prenom';
  static const String _keyEmail   = 'email';
  static const String _keyRole    = 'role';
  static const String _keyAdresse = 'adresse';

  // ── SAUVEGARDER après login/inscription ──────────
  // Appelé après POST /api/auth/login ou register
  // Stocke toutes les infos de la réponse JWT
  static Future<void> saveUserData({
    required String token,
    required int userId,
    required String nom,
    required String prenom,
    required String email,
    required String role,
  }) async {
    // getInstance() = ouvre le stockage local
    final prefs = await SharedPreferences.getInstance();

    // setString() = stocke une valeur String
    // setInt()    = stocke une valeur int
    await prefs.setString(_keyToken,  token);
    await prefs.setInt(_keyUserId,    userId);
    await prefs.setString(_keyNom,    nom);
    await prefs.setString(_keyPrenom, prenom);
    await prefs.setString(_keyEmail,  email);
    await prefs.setString(_keyRole,   role);
  }

  // ── LIRE les données stockées ─────────────────────
  // getString() retourne null si la clé n'existe pas
  // ?? = opérateur "null coalescing" :
  //   valeur ?? 'defaut' → si null → utilise 'defaut'
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<String> getNom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNom) ?? '';
  }

  static Future<String> getPrenom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrenom) ?? '';
  }

  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) ?? '';
  }
  
  // ── SAUVEGARDER l'adresse ─────────────────────────────
  static Future<void> saveAdresse(String adresse) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyAdresse, adresse);
}
// ── LIRE l'adresse ─────────────────────────────
static Future<String> getAdresse() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyAdresse) ?? 'Dakar, Sénégal';
}

  // ── VÉRIFIER si connecté ──────────────────────────
  // Utilisé dans SplashScreen pour rediriger
  // directement vers HomeScreen si déjà connecté
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    // token != null ET token non vide = connecté
    return token != null && token.isNotEmpty;
  }

  // ── DÉCONNEXION ───────────────────────────────────
  // Supprime toutes les données stockées
  // Appelé quand l'utilisateur clique "Déconnexion"
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // clear() = supprime TOUT le stockage
    await prefs.clear();
  }
}