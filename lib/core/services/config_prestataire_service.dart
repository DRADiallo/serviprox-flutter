import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/core/constants/api_constants.dart';
import 'package:memoireserviprox/core/models/config_prestataire_model.dart';
import 'package:memoireserviprox/core/services/auth_storage.dart';

class ConfigPrestataireService {
  static const String _baseUrl = ApiConstants.prestataireConfig;

  // ══════════════════════════════════════════════
  // POST /api/prestataire/config/{prestataireId}
  // CRÉATION INITIALE de la configuration
  //
  // Spring Boot : @RequestParam → query parameters
  // → typeService obligatoire (ex: "pressing")
  // → zoneCouverture optionnel
  //
  // Appelé par : ConfigurerServiceInitialScreen
  // ══════════════════════════════════════════════
  static Future<bool> configurerService(
    int prestataireId,
    String typeService, {
    String? zoneCouverture,
  }) async {
    try {
      final token = await AuthStorage.getToken();

      // @RequestParam → query string dans l'URL
      // Ex: /api/prestataire/config/6?typeService=pressing&zoneCouverture=M%C3%A9dina
      final Map<String, String> params = {
        'typeService': typeService,
      };
      if (zoneCouverture != null && zoneCouverture.isNotEmpty) {
        params['zoneCouverture'] = zoneCouverture;
      }

      final uri = Uri.parse('$_baseUrl/$prestataireId')
          .replace(queryParameters: params);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
            'configurerService erreur ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('configurerService: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // GET /api/prestataire/config/{prestataireId}
  // ══════════════════════════════════════════════
  static Future<ConfigPrestataireModel?> getConfig(int prestataireId) async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/$prestataireId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return ConfigPrestataireModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('getConfig erreur ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('getConfig exception: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // PUT /activer-collecte-livraison
  // @RequestBody ConfigurationCollecteRequest
  // ✅ FIX : modesDepotAcceptes et etapesPersonnalisees
  //          sont des String dans le DTO backend (pas des List !)
  //          → double-sérialiser avec jsonEncode()
  // ══════════════════════════════════════════════
  static Future<bool> activerCollecteLivraison(
    int prestataireId, {
    bool avecAgent = true,
    List<String> modesDepot = const [
      'COLLECTE_DOMICILE',
      'LIVRAISON_DOMICILE',
      'DEPOT_ATELIER',
    ],
    List<String> etapes = const [
      'EN_COLLECTE',
      'EN_TRAITEMENT',
      'EN_LIVRAISON',
    ],
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/$prestataireId/activer-collecte-livraison'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'avecAgent': avecAgent,
          // ✅ FIX : ConfigurationCollecteRequest attend String, pas List
          'modesDepotAcceptes': jsonEncode(modesDepot),
          'etapesPersonnalisees': jsonEncode(etapes),
        }),
      );
      if (response.statusCode != 200) {
        debugPrint(
            'activerCollecte erreur ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur activerCollecte: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // PUT /etapes
  // @RequestParam String etapesJson
  // ✅ FIX : query param ?etapesJson=... (pas de body JSON)
  // ══════════════════════════════════════════════
  static Future<bool> modifierEtapes(
      int prestataireId, List<String> etapes) async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/$prestataireId/etapes')
            .replace(queryParameters: {'etapesJson': jsonEncode(etapes)}),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        debugPrint(
            'modifierEtapes erreur ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('modifierEtapes: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // PUT /disponibilite
  // @RequestParam Boolean disponible
  // ✅ FIX : query param ?disponible=true (pas de body JSON)
  // ══════════════════════════════════════════════
  static Future<bool> toggleDisponibilite(
      int prestataireId, bool disponible) async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/$prestataireId/disponibilite')
            .replace(queryParameters: {'disponible': disponible.toString()}),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        debugPrint(
            'toggleDisponibilite erreur ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('toggleDisponibilite: $e');
      return false;
    }
  }
}



// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:memoireserviprox/core/models/config_prestataire_model.dart';
// import 'package:memoireserviprox/core/services/auth_storage.dart';


// class ConfigPrestataireService {
//   // ── URL de base ────────────────────────────────
//   static const String _baseUrl = 
//   'http://localhost:7090/api/prestataire/config';
//   // ══════════════════════════════════════════════
//   // GET /api/config-service/{prestataireId}
//   // Appelé par : NouvelleCommandeScreen, CommandeDetailScreen
//   // ══════════════════════════════════════════════
//   static Future<ConfigPrestataireModel?> getConfig(
//       int prestataireId) async {
//     try {
//       final token = await AuthStorage.getToken();
//       final response = await http.get(
//         Uri.parse('$_baseUrl/$prestataireId'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final json = jsonDecode(response.body)
//             as Map<String, dynamic>;
//         return ConfigPrestataireModel.fromJson(json);
//       }
//       debugPrint(
//         'getConfig erreur ${response.statusCode}');
//       return null;
//     } catch (e) {
//       debugPrint('getConfig exception: $e');
//       return null;
//     }
//   }

//   // ══════════════════════════════════════════════
//   // PUT /activer-collecte-livraison
//   // Le prestataire active collecte+livraison
//   // SANS changement de code Flutter
//   // ══════════════════════════════════════════════
//   static Future<bool> activerCollecteLivraison(
//   int prestataireId, {
//   bool avecAgent = true,
//   String modesDepot = '["Collecte domicile","Dépôt atelier (livraison)"]',
//   String etapes = '["collecte","traitement","livraison"]',
// }) async {
//   try {
//     final token = await AuthStorage.getToken();
//     final response = await http.put(
//       Uri.parse('$_baseUrl/$prestataireId/activer-collecte-livraison'),
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token',
//       },
//       body: jsonEncode({
//         'avecAgent': avecAgent,
//         'modesDepotAcceptes': modesDepot,
//         'etapesPersonnalisees': etapes,
//       }),
//     );
//     return response.statusCode == 200;
//   } catch (e) {
//     debugPrint('Erreur activerCollecte: $e');
//     return false;
//   }
// }
//   // ══════════════════════════════════════════════
//   // PUT /etapes — modifier les étapes du workflow
//   // ══════════════════════════════════════════════
//   static Future<bool> modifierEtapes(
//       int prestataireId,
//       List<String> etapes) async {
//     try {
//       final token = await AuthStorage.getToken();
//       final response = await http.put(
//         Uri.parse('$_baseUrl/$prestataireId/etapes'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({'etapes': etapes}),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       debugPrint('modifierEtapes: $e');
//       return false;
//     }
//   }

//   // ══════════════════════════════════════════════
//   // PUT /disponibilite — toggle ouvert/fermé
//   // ══════════════════════════════════════════════
//   static Future<bool> toggleDisponibilite(
//       int prestataireId,
//       bool disponible) async {
//     try {
//       final token = await AuthStorage.getToken();
//       final response = await http.put(
//         Uri.parse(
//           '$_baseUrl/$prestataireId/disponibilite'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode(
//           {'disponible': disponible}),
//       );
//       return response.statusCode == 200;
//     } catch (e) {
//       debugPrint('toggleDisponibilite: $e');
//       return false;
//     }
//   }
// }