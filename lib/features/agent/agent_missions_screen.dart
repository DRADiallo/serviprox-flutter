import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/core/widgets/photos_commande_widget.dart';
import 'package:memoireserviprox/features/agent/photo_preuve_screen.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class AgentMissionsScreen extends StatefulWidget {
  const AgentMissionsScreen({super.key});

  @override
  State<AgentMissionsScreen> createState() =>
      _AgentMissionsScreenState();
}

class _AgentMissionsScreenState
    extends State<AgentMissionsScreen> {

  bool _isLoading = true;
  List<dynamic> _missions = [];
  List<dynamic> _missionsEnAttente = [];
  final Map<int, bool> _photosPrises = {};

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  // ── Charger missions ──────────────────────────────
  Future<void> _loadMissions() async {
    setState(() => _isLoading = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final results = await Future.wait([
        // Toutes les missions
        http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/affectation'
            '/agent/$userId'),
          headers: {
            'Authorization': 'Bearer $token'},
        ),
        // Missions en attente
        http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/affectation'
            '/agent/$userId/en-attente'),
          headers: {
            'Authorization': 'Bearer $token'},
        ),
      ]);

      if (results[0].statusCode == 200) {
        setState(() {
          _missions = jsonDecode(results[0].body);
        });
      }
      if (results[1].statusCode == 200) {
        setState(() {
          _missionsEnAttente =
            jsonDecode(results[1].body);
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Confirmer ou refuser mission ──────────────────
  Future<void> _repondreMission(
    int commandeId,
    String decision,
  ) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/affectation'
          '/commande/$commandeId/confirmer'
          '?agentId=$userId'
          '&decision=$decision'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await _loadMissions();
        if (mounted) {
          ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  decision == 'CONFIRMER'
                    ? "✅ Mission acceptée !"
                    : "❌ Mission refusée",
                  style: GoogleFonts.poppins(
                    fontSize: 12)),
                backgroundColor:
                  decision == 'CONFIRMER'
                    ? AppColors.green
                    : Colors.red,
                behavior:
                  SnackBarBehavior.floating,
              ),
            );
        }
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Mes missions",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white),
            onPressed: _loadMissions,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.green))
        : RefreshIndicator(
            onRefresh: _loadMissions,
            color: AppColors.green,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              physics:
                const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment:
                  CrossAxisAlignment.start,
                children: [

                  // ── Missions en attente ───────
                  if (_missionsEnAttente.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration:
                            const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "En attente de confirmation"
                          " (${_missionsEnAttente.length})",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._missionsEnAttente.map((m) =>
                      _buildMissionEnAttente(m)),
                    const SizedBox(height: 16),
                  ],

                  // ── Toutes les missions ───────
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Mes missions"
                        " (${_missions.length})",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _missions.isEmpty
                    ? Container(
                        padding: const EdgeInsets
                          .all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                            BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5)),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons
                                  .assignment_outlined,
                                color:
                                  AppColors.textMuted,
                                size: 40),
                              const SizedBox(height: 8),
                              Text(
                                "Aucune mission",
                                style:
                                  GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors
                                      .textSecond,
                                  ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _missions
                          .map((m) =>
                            _buildMissionCard(m))
                          .toList(),
                      ),
                ],
              ),
            ),
          ),
    );
  }

  // ── Carte mission en attente ──────────────────────
  Widget _buildMissionEnAttente(
      Map<String, dynamic> mission) {
    final type = mission['typeAffectation'] ?? '';
    final commandeId = mission['commandeId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'COLLECTE'
                    ? AppColors.greenLight
                    : AppColors.primaryLight,
                  borderRadius:
                    BorderRadius.circular(20)),
                child: Text(
                  type == 'COLLECTE'
                    ? "🏠 Collecte"
                    : "🚚 Livraison",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: type == 'COLLECTE'
                      ? AppColors.green
                      : AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius:
                    BorderRadius.circular(20)),
                child: Text("⏳ En attente",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Infos client
          _infoRow(Icons.person_outline,
            mission['nomClient'] ?? ''),
          _infoRow(Icons.phone_outlined,
            mission['telephoneClient'] ?? ''),
          _infoRow(Icons.store_outlined,
            mission['nomPrestataire'] ?? ''),
          _infoRow(Icons.payments_outlined,
            "${(mission['montantTotal'] ?? 0).toInt()} FCFA"),

          // Description colis
          if (mission['descriptionColis'] != null &&
              mission['descriptionColis']
                .toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                  BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt_outlined,
                    color: AppColors.primary,
                    size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      mission['descriptionColis'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Boutons accepter/refuser
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(
                      color: Colors.red),
                    padding:
                      const EdgeInsets.symmetric(
                        vertical: 10)),
                  onPressed: () =>
                    _repondreMission(
                      commandeId, 'REFUSER'),
                  icon: const Icon(
                    Icons.close, size: 16),
                  label: Text("Refuser",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding:
                      const EdgeInsets.symmetric(
                        vertical: 10)),
                  onPressed: () =>
                    _repondreMission(
                      commandeId, 'CONFIRMER'),
                  icon: const Icon(
                    Icons.check, size: 16),
                  label: Text("✅ Accepter",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // ← Confirmer collecte → EN_VERIFICATION
Future<void> _confirmerCollecte(
    int commandeId, int affectationId) async {
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    // ← Changer statut commande
    final response = await http.put(
      Uri.parse(
        '${ApiConstants.commandes}'
        '/$commandeId/statut'
        '?statut=EN_VERIFICATION'
        '&acteurId=$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // ← Mettre à jour statut affectation
      await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/affectation'
          '/$affectationId/statut'
          '?statut=TERMINEE'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      await _loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Text(
                "✅ Collecte confirmée ! "
                "Le prestataire a été notifié.",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  } catch (e) {
    debugPrint("Erreur: $e");
  }
}

// ← Confirmer livraison → VERIFICATION_FINALE
Future<void> _confirmerLivraison(
    int commandeId, int affectationId) async {
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    final response = await http.put(
      Uri.parse(
        '${ApiConstants.commandes}'
        '/$commandeId/statut'
        '?statut=VERIFICATION_FINALE'
        '&acteurId=$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/affectation'
          '/$affectationId/statut'
          '?statut=TERMINEE'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      await _loadMissions();
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Text(
                "✅ Livraison confirmée ! "
                "Client notifié.",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  } catch (e) {
    debugPrint("Erreur: $e");
  }
}

  // ── Carte mission normale ─────────────────────────
  Widget _buildMissionCard(
      Map<String, dynamic> mission) {
    final type = mission['typeAffectation'] ?? '';
    final statut = mission['statut'] ?? '';

    Color statutColor;
    Color statutBg;
    String statutLabel;

    switch (statut) {
      case 'EN_ATTENTE':
        statutColor = Colors.orange;
        statutBg = const Color(0xFFFFF3E0);
        statutLabel = "⏳ En attente";
        break;
      case 'CONFIRMEE':
        statutColor = AppColors.green;
        statutBg = AppColors.greenLight;
        statutLabel = "✅ Confirmée";
        break;
      case 'EN_COURS':
        statutColor = AppColors.primary;
        statutBg = AppColors.primaryLight;
        statutLabel = "🔄 En cours";
        break;
      case 'TERMINEE':
        statutColor = AppColors.green;
        statutBg = AppColors.greenLight;
        statutLabel = "🏁 Terminée";
        break;
      case 'REFUSEE':
        statutColor = Colors.red;
        statutBg = const Color(0xFFFCEBEB);
        statutLabel = "❌ Refusée";
        break;
      default:
        statutColor = Colors.grey;
        statutBg = AppColors.background;
        statutLabel = statut;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment:
          CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              // Type mission
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'COLLECTE'
                    ? AppColors.greenLight
                    : AppColors.primaryLight,
                  borderRadius:
                    BorderRadius.circular(20)),
                child: Text(
                  type == 'COLLECTE'
                    ? "🏠 Collecte"
                    : "🏍️/🛵  Livraison",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: type == 'COLLECTE'
                      ? AppColors.green
                      : AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Statut
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statutBg,
                  borderRadius:
                    BorderRadius.circular(20)),
                child: Text(statutLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: statutColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _infoRow(Icons.person_outline,
            mission['nomClient'] ?? ''),
          _infoRow(Icons.store_outlined,
            mission['nomPrestataire'] ?? ''),
          _infoRow(Icons.payments_outlined,
            "${(mission['montantTotal'] ?? 0).toInt()} FCFA"),

          // Description colis
          if (mission['descriptionColis'] != null &&
              mission['descriptionColis']
                .toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                  BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt_outlined,
                    color: AppColors.primary,
                    size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      mission['descriptionColis'],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          PhotosCommandeWidget(
            commandeId:
              mission['commandeId'] as int),
          
          if (type == 'COLLECTE') ...[
            // Bouton photo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(
                    color: AppColors.green),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10)),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoPreuveScreen(
                        commandeId:
                          mission['commandeId'] as int,
                        typePreuve: 'COLLECTE_CLIENT',
                        titre: '📸 Photo colis collecté',
                      )));
                  // ← Si photo prise → recharger
                  if (result == true) {
                    setState(() {
                      _photosPrises[
                        mission['commandeId'] as int
                      ] = true;
                    });
                  }
                },
                icon: const Icon(
                  Icons.camera_alt_outlined, size: 16),
                label: Text(
                  _photosPrises[
                    mission['commandeId'] as int
                  ] == true
                    ? "✅ Photo prise — Reprendre"
                    : "📸 Prendre photo du colis",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 8),

            // ← Bouton "J'ai collecté"
            // Visible seulement si photo prise !
            if (_photosPrises[
                mission['commandeId'] as int] == true)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12)),
                  onPressed: () =>
                    _confirmerCollecte(
                      mission['commandeId'] as int,
                      mission['id'] as int),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16),
                  label: Text(
                    "✅ J'ai collecté les articles !",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ),
              ),
          ],

          // ← LIVRAISON
          if (type == 'LIVRAISON') ...[
            // Bouton photo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                    color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10)),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoPreuveScreen(
                        commandeId:
                          mission['commandeId'] as int,
                        typePreuve: 'LIVRAISON_CLIENT',
                        titre: '📸 Photo livraison',
                      )));
                  if (result == true) {
                    setState(() {
                      _photosPrises[
                        mission['commandeId'] as int
                      ] = true;
                    });
                  }
                },
                icon: const Icon(
                  Icons.camera_alt_outlined, size: 16),
                label: Text(
                  _photosPrises[
                    mission['commandeId'] as int
                  ] == true
                    ? "✅ Photo prise — Reprendre"
                    : "📸 Prendre photo livraison",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 8),

            // ← Bouton "J'ai livré"
            if (_photosPrises[
                mission['commandeId'] as int] == true)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12)),
                  onPressed: () =>
                    _confirmerLivraison(
                      mission['commandeId'] as int,
                      mission['id'] as int),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16),
                  label: Text(
                    "✅ J'ai livré la commande !",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ], 
      ),
    );
  }


  // ── Info row ──────────────────────────────────────
  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon,
            color: AppColors.textSecond,
            size: 14),
          const SizedBox(width: 6),
          Text(value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}