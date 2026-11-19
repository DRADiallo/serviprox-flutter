// ═══════════════════════════════════════════════════════
// auth_storage.dart
//
// RÔLE : Gérer le stockage local du token JWT
//        et des infos utilisateur
//
// SharedPreferences = stockage clé-valeur sur le téléphone
// → Comme une Map<String, String> qui persiste
//   même après fermeture de l'app
// ═══════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {

  // ── Clés de stockage ──────────────────────────────
  static const String _keyToken       = 'token';
  static const String _keyUserId      = 'userId';
  static const String _keyNom         = 'nom';
  static const String _keyPrenom      = 'prenom';
  static const String _keyEmail       = 'email';
  static const String _keyRole        = 'role';
  static const String _keyAdresse     = 'adresse';
  static const String _keyTypeService = 'typeService'; // ← AJOUT

  // ── SAUVEGARDER après login/inscription ──────────
  static Future<void> saveUserData({
    required String token,
    required int userId,
    required String nom,
    required String prenom,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,  token);
    await prefs.setInt(_keyUserId,    userId);
    await prefs.setString(_keyNom,    nom);
    await prefs.setString(_keyPrenom, prenom);
    await prefs.setString(_keyEmail,  email);
    await prefs.setString(_keyRole,   role);
  }

  // ── LIRE les données stockées ─────────────────────
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

  // ── ADRESSE ───────────────────────────────────────
  static Future<void> saveAdresse(String adresse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdresse, adresse);
  }

  static Future<String> getAdresse() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdresse) ?? 'Dakar, Sénégal';
  }

  // ── TYPE SERVICE (Prestataire) ────────────────────
  // Sauvegardé après login ou config initiale
  // Utilisé pour afficher le badge dans PrestataireHomeScreen
  static Future<void> saveTypeService(String typeService) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTypeService, typeService);
  }

  static Future<String> getTypeService() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTypeService) ?? '';
  }

  // ── VÉRIFIER si connecté ──────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── DÉCONNEXION ───────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}