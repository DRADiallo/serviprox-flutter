import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/prestataire/CommandeDetailScreen.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

// ══════════════════════════════════════════════════════
// MODÈLE COMMANDE
// ══════════════════════════════════════════════════════
class CommandeModel {
  final int id;
  final String statut;
  final double montantTotal;
  final String dateCommande;
  final String motDepot;
  final String nomClient;
  final String nomPrestataire;
  final List<Map<String, dynamic>> lignes;
  // Ajout
  final double? prixParTypePrestations;
  final double? prixCourseCollecte;
  final double? prixCourseLivraison;
  final String? detailPrixReel;
  final bool? prixAccepteClient;
  final String? descriptionColis;
  final String? nomAgentCollecte;
  final String? telephoneAgentCollecte;
  final String? nomAgentLivraison;

  const CommandeModel({
    required this.id,
    required this.statut,
    required this.montantTotal,
    required this.dateCommande,
    required this.motDepot,
    required this.nomClient,
    required this.nomPrestataire,
    required this.lignes,
    //Ajout
    this.prixParTypePrestations,
    this.prixCourseCollecte,
    this.prixCourseLivraison,
    this.detailPrixReel,
    this.prixAccepteClient,
    this.descriptionColis,
    this.nomAgentCollecte,
    this.telephoneAgentCollecte,
    this.nomAgentLivraison,
  });

  factory CommandeModel.fromJson(
      Map<String, dynamic> json) {
    return CommandeModel(
      id:             json['id'] ?? 0,
      statut:         json['statut'] ?? 'CREE',
      montantTotal:   (json['montantTotal'] ?? 0)
        .toDouble(),
      dateCommande:   json['dateCommande'] ?? '',
      motDepot:       json['motDepot'] ?? '',
      nomClient:      json['nomClient'] ?? '',
      nomPrestataire: json['nomPrestataire'] ?? '',
      lignes:         json['lignes'] != null
        ? List<Map<String, dynamic>>.from(
            json['lignes'])
        : [],
         // ← AJOUT
      prixParTypePrestations:
        json['prixParTypePrestations'] != null
          ? (json['prixParTypePrestations'])
              .toDouble()
          : null,
      prixCourseCollecte:
        json['prixCourseCollecte'] != null
          ? (json['prixCourseCollecte']).toDouble()
          : null,
      prixCourseLivraison:
        json['prixCourseLivraison'] != null
          ? (json['prixCourseLivraison']).toDouble()
          : null,
      detailPrixReel:  json['detailPrixReel'],
      prixAccepteClient: json['prixAccepteClient'],
      descriptionColis: json['descriptionColis'],
      nomAgentCollecte: json['nomAgentCollecte'],
      telephoneAgentCollecte:
        json['telephoneAgentCollecte'],
      nomAgentLivraison: json['nomAgentLivraison'],
    );
  }
}

// ══════════════════════════════════════════════════════
// ÉCRAN COMMANDES PRESTATAIRE
// ══════════════════════════════════════════════════════
class PrestataireCommandesScreen extends StatefulWidget {
  const PrestataireCommandesScreen({super.key});

  @override
  State<PrestataireCommandesScreen> createState() =>
      _PrestataireCommandesScreenState();
}

class _PrestataireCommandesScreenState
    extends State<PrestataireCommandesScreen> {

  // ── Variables d'état ──────────────────────────────
  bool _isLoading = true;
  List<CommandeModel> _commandes = [];
  String _filterStatut = 'TOUS';

  final List<Map<String, String>> _filtres = [
  {'key': 'TOUS',               'label': 'Toutes'},
  {'key': 'CREE',               'label': 'Nouvelles'},
  {'key': 'CONFIRMEE',          'label': 'Confirmées'},
  // ← AJOUT
  {'key': 'EN_COLLECTE',        'label': '🛵 Collecte'},
  {'key': 'EN_VERIFICATION',    'label': ' Vérification'},
  {'key': 'EN_TRAITEMENT',      'label': 'En cours'},
  {'key': 'TRAITEMENT_TERMINE', 'label': '🏁 Terminé'},
  // ← SUPPRIMÉ : PAIEMENT_RECU
  {'key': 'EN_LIVRAISON',       'label': '🛵 Livraison'},
  {'key': 'VERIFICATION_FINALE','label': 'Vérif. finale'},
  // ← SUPPRIMÉ : TERMINEE
  {'key': 'CLOTUREE',           'label': ' Clôturées'},
  {'key': 'ANNULEE',            'label': 'Annulées'},
  {'key': 'LITIGE',             'label': '⚠️ Litiges'},
];

  @override
  void initState() {
    super.initState();
    _loadCommandes();
  }

  // ── Charger les commandes ─────────────────────────
  Future<void> _loadCommandes() async {
    setState(() => _isLoading = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/prestataire/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);
        setState(() {
          _commandes = data
            .map((c) => CommandeModel.fromJson(c))
            .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Erreur commandes: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Changer statut commande ───────────────────────
  Future<void> _changerStatut(
      int commandeId, String statut) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/$commandeId/statut'
          '?statut=$statut'
          '&acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Recharger les commandes
        _loadCommandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Statut mis à jour : "
                "${_getLabelStatut(statut)}",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur changement statut: $e");
    }
  }

  // ── Annuler commande ──────────────────────────────
  Future<void> _annuler(int commandeId) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      await http.put(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/$commandeId/annuler'
          '?acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      _loadCommandes();
    } catch (e) {
      debugPrint("Erreur annulation: $e");
    }
  }

  // ── Commandes filtrées ────────────────────────────
  List<CommandeModel> get _filtered {
    if (_filterStatut == 'TOUS') return _commandes;
    return _commandes
      .where((c) => c.statut == _filterStatut)
      .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mes commandes",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "${_commandes.length} commande(s) reçue(s)",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh, color: Colors.white),
            onPressed: _loadCommandes,
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Filtres statut ─────────────────────────
          Container(
            color: Colors.white,
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
              itemCount: _filtres.length,
              itemBuilder: (_, i) {
                final f = _filtres[i];
                final sel =
                  _filterStatut == f['key'];
                return GestureDetector(
                  onTap: () => setState(
                    () => _filterStatut =
                      f['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 200),
                    margin: const EdgeInsets.only(
                      right: 8),
                    padding:
                      const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4),
                    decoration: BoxDecoration(
                      color: sel
                        ? AppColors.green
                        : AppColors.background,
                      borderRadius:
                        BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                          ? AppColors.green
                          : AppColors.border),
                    ),
                    child: Text(f['label']!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: sel
                          ? Colors.white
                          : AppColors.textSecond,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Liste commandes ────────────────────────
          Expanded(
            child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.green))
              : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 60,
                          color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          "Aucune commande",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color:
                              AppColors.textSecond,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                      _buildCommandeCard(
                        _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Carte commande ─────────────────────────────────
  Widget _buildCommandeCard(CommandeModel cmd) {
    final statut = _getStatutConfig(cmd.statut);

    return GestureDetector(
    onTap: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommandeDetailScreen(
            commandeId: cmd.id,
          ),
        ),
      );
      // ← Recharger après retour
      _loadCommandes();
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statut['borderColor'] as Color,
          width: 1),
      ),
      child: Column(
        children: [

          // ── Header carte ───────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statut['bgColor'] as Color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Avatar client
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.green
                      .withValues(alpha: 0.2),
                    borderRadius:
                      BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      cmd.nomClient.isNotEmpty
                        ? cmd.nomClient[0]
                          .toUpperCase()
                        : 'C',
                      style: GoogleFonts.poppins(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                      CrossAxisAlignment.start,
                    children: [
                      Text(cmd.nomClient,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "Commande #${cmd.id} · "
                        "${cmd.dateCommande}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecond,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge statut
                Container(
                  padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statut['color'] as Color,
                    borderRadius:
                      BorderRadius.circular(20),
                  ),
                  child: Text(
                    statut['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Corps carte ────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // Lignes de commande
                if (cmd.lignes.isNotEmpty) ...[
                  Text("Prestations :",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecond,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...cmd.lignes.map((ligne) =>
                    Padding(
                      padding: const EdgeInsets
                        .only(bottom: 4),
                      child: Row(
                        mainAxisAlignment:
                          MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.green,
                                size: 12),
                              const SizedBox(width: 6),
                              Text(
                                "${ligne['typePrestation']} "
                                "× ${ligne['quantite']}",
                                style:
                                  GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors
                                      .textPrimary,
                                  ),
                              ),
                            ],
                          ),
                          Text(
                            "${((ligne['prixUnitaire'] ?? 0) * (ligne['quantite'] ?? 1)).toInt()} FCFA",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight:
                                FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                ],

                // Total + mode dépôt
                Row(
                  mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.home_outlined,
                          size: 14,
                          color: AppColors.textSecond),
                        const SizedBox(width: 4),
                        Text(
                          cmd.motDepot ==
                            'COLLECTE_DOMICILE'
                            ? "Collecte domicile"
                            : "Dépôt atelier",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecond,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${cmd.montantTotal.toInt()} FCFA",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),


                // ← AJOUT : Description colis
              if (cmd.descriptionColis != null &&
                  cmd.descriptionColis!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.list_alt_outlined,
                        color: AppColors.primary,
                        size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cmd.descriptionColis!,
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

              // ← AJOUT : Agent collecte
              if (cmd.nomAgentCollecte != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delivery_dining,
                        color: AppColors.green,
                        size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "Agent : ${cmd.nomAgentCollecte}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        cmd.telephoneAgentCollecte ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

                const SizedBox(height: 12),

                // ── Boutons d'action ──────────────────
                _buildActionButtons(cmd),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Boutons selon statut ───────────────────────────
  Widget _buildActionButtons(CommandeModel cmd) {
  switch (cmd.statut) {

    case 'CREE':
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(
                  color: Colors.red),
              ),
              onPressed: () =>
                _showConfirmDialog(
                  "Refuser la commande ?",
                  "Cette action est irréversible.",
                  () => _annuler(cmd.id)),
              child: Text("Refuser",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              // ← COLLECTE_DOMICILE → dialog agent
              // DEPOT_ATELIER → confirmer direct
              onPressed: () =>
                cmd.motDepot == 'COLLECTE_DOMICILE'
                  ? _showConfirmerAvecAgent(cmd.id)
                  : _changerStatut(
                      cmd.id, 'CONFIRMEE'),
              child: Text("✅ Confirmer",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

    // ← AJOUT : En attente confirmation agent
    case 'CONFIRMEE':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.amberLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty,
              color: AppColors.amber,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "⏳ En attente confirmation agent",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      );

    // ← AJOUT : Agent en collecte
    case 'EN_COLLECTE':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delivery_dining,
              color: AppColors.primary,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "🛵 Agent en cours de collecte...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );

    // ← MODIFICATION : fixer prix réel
    case 'EN_VERIFICATION':
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius:
                BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.amber,
                  size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Vérifiez les articles, "
                    "pesez/comptez et fixez "
                    "le prix réel",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // ← Signaler problème
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
                    _showSignalerProbleme(cmd.id),
                  icon: const Icon(
                    Icons.warning_amber, size: 14),
                  label: Text("⚠️ Problème",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              // ← Fixer prix réel
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
                    _showFixerPrixDialog(cmd.id,
                      cmd.montantTotal),
                  icon: const Icon(
                    Icons.price_change_outlined,
                    size: 14),
                  label: Text(
                    "💰 Fixer prix réel",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      );

    case 'EN_TRAITEMENT':
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _changerStatut(
            cmd.id, 'TRAITEMENT_TERMINE'),
          child: Text(
            "🏁 Traitement terminé",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600)),
        ),
      );

    // ← MODIFICATION : confirmer paiement
    case 'TRAITEMENT_TERMINE':
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius:
                BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_empty,
                  color: AppColors.amber,
                  size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "💰 En attente paiement client",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ← Confirmer paiement reçu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding:
                  const EdgeInsets.symmetric(
                    vertical: 12)),
              onPressed: () =>
                _confirmerPaiement(cmd.id),
              icon: const Icon(
                Icons.verified_outlined,
                size: 16),
              label: Text(
                "✅ Confirmer paiement reçu",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

    // ← MODIFICATION : assigner agent livraison
    case 'EN_LIVRAISON':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delivery_dining,
              color: AppColors.primary,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "🛵 Livraison en cours...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );

    // ← MODIFICATION : CLOTUREE directement !
    case 'VERIFICATION_FINALE':
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _changerStatut(
            cmd.id, 'CLOTUREE'),
          child: Text(
            "🎉 Clôturer la commande",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600)),
        ),
      );

    // ← SUPPRIMÉ : TERMINEE
    // ← SUPPRIMÉ : PAIEMENT_RECU

    case 'CLOTUREE':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.green,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "🎉 Commande clôturée !",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

    case 'ANNULEE':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBEB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cancel_outlined,
              color: Colors.red,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "Commande annulée",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );

    case 'LITIGE':
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
            MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber,
              color: Colors.orange,
              size: 16),
            const SizedBox(width: 8),
            Text(
              "⚠️ Litige en cours",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );

    default:
      return const SizedBox.shrink();
  }
}


void _showFixerPrixDialog(
    int commandeId, double prixEstimatif) {
  final prixController = TextEditingController(
    text: prixEstimatif.toInt().toString());
  final collecteController =
    TextEditingController(text: '0');
  final livraisonController =
    TextEditingController(text: '0');
  final detailController =
    TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context)
          .viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
            CrossAxisAlignment.start,
          children: [

            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius:
                    BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Text("💰 Fixer le prix réel",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Après pesée/comptage des articles",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecond,
              ),
            ),
            const SizedBox(height: 16),

            // Prix prestations
            _inputPrix(
              "Prix prestations (FCFA)",
              prixController,
              Icons.local_laundry_service_outlined),
            const SizedBox(height: 10),

            // Frais collecte
            _inputPrix(
              "Frais collecte (FCFA)",
              collecteController,
              Icons.delivery_dining_outlined),
            const SizedBox(height: 10),

            // Frais livraison
            _inputPrix(
              "Frais livraison (FCFA)",
              livraisonController,
              Icons.local_shipping_outlined),
            const SizedBox(height: 10),

            // Détail
            TextField(
              controller: detailController,
              maxLines: 2,
              style: GoogleFonts.poppins(
                fontSize: 12),
              decoration: InputDecoration(
                hintText:
                  "Ex: 3.5kg lavage = 2100F, "
                  "1 boubou = 2500F",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.notes_outlined,
                  color: AppColors.green),
                border: OutlineInputBorder(
                  borderRadius:
                    BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Bouton confirmer
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                      BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final token =
                    await AuthStorage.getToken();
                  final userId =
                    await AuthStorage.getUserId();

                  final prix = double.tryParse(
                    prixController.text) ?? 0;
                  final collecte = double.tryParse(
                    collecteController.text) ?? 0;
                  final livraison = double.tryParse(
                    livraisonController.text) ?? 0;

                  await http.put(
                    Uri.parse(
                      '${ApiConstants.commandes}'
                      '/$commandeId/fixer-prix'
                      '?prixPrestations=$prix'
                      '&prixCollecte=$collecte'
                      '&prixLivraison=$livraison'
                      '&detailPrix=${Uri.encodeComponent(detailController.text)}'
                      '&acteurId=$userId'),
                    headers: {
                      'Authorization':
                        'Bearer $token'},
                  );

                  _loadCommandes();
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                      .showSnackBar(
                        SnackBar(
                          content: Text(
                            "✅ Prix réel fixé ! "
                            "Client notifié.",
                            style: GoogleFonts.poppins(
                              fontSize: 12)),
                          backgroundColor:
                            AppColors.green,
                          behavior:
                            SnackBarBehavior.floating,
                        ),
                      );
                  }
                },
                child: Text(
                  "Confirmer et notifier client",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}

// ← Helper input prix
Widget _inputPrix(
  String label,
  TextEditingController controller,
  IconData icon,
) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    style: GoogleFonts.poppins(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon,
        color: AppColors.green),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.green, width: 1.5)),
    ),
  );
}

Future<void> _confirmerPaiement(
    int commandeId) async {
  try {
    final token  = await AuthStorage.getToken();

    // ← Récupérer paiement
    final paiementResp = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/paiement'
        '/commande/$commandeId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (paiementResp.statusCode == 200) {
      final paiement =
        jsonDecode(paiementResp.body);
      final paiementId = paiement['id'];

      // ← Confirmer
      final response = await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/paiement'
          '/$paiementId/confirmer-prestataire'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _loadCommandes();
        if (mounted) {
          ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  "✅ Paiement confirmé ! "
                  "Assignez un agent de livraison.",
                  style: GoogleFonts.poppins(
                    fontSize: 12)),
                backgroundColor: AppColors.green,
                behavior:
                  SnackBarBehavior.floating,
              ),
            );
        }
      }
    }
  } catch (e) {
    debugPrint("Erreur: $e");
  }
}

  // ── Dialog confirmation ────────────────────────────
  void _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
        title: Text(title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600)),
        content: Text(message,
          style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
              style: GoogleFonts.poppins(
                color: AppColors.textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text("Confirmer",
              style: GoogleFonts.poppins(
                fontSize: 13))),
        ],
      ),
    );
  }

  // ── Config visuelle selon statut ───────────────────
  Map<String, dynamic> _getStatutConfig(
    String statut) {
  switch (statut) {
    case 'CREE':
      return {
        'label': 'Nouvelle',
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
        'borderColor': AppColors.primary
          .withValues(alpha: 0.3),
      };
    case 'CONFIRMEE':
      return {
        'label': '⏳ Confirmée',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'borderColor': AppColors.amber
          .withValues(alpha: 0.3),
      };
    // ← AJOUT
    case 'EN_COLLECTE':
      return {
        'label': '🛵 Collecte',
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
        'borderColor': AppColors.primary
          .withValues(alpha: 0.3),
      };
    // ← AJOUT
    case 'EN_VERIFICATION':
      return {
        'label': '🔍 Vérification',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'borderColor': AppColors.amber
          .withValues(alpha: 0.3),
      };
    case 'EN_TRAITEMENT':
      return {
        'label': '🔄 En traitement',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'borderColor': AppColors.amber
          .withValues(alpha: 0.3),
      };
    // ← AJOUT
    case 'TRAITEMENT_TERMINE':
      return {
        'label': '🏁 Terminé',
        'color': AppColors.purple,
        'bgColor': AppColors.purpleLight,
        'borderColor': AppColors.purple
          .withValues(alpha: 0.3),
      };
    // ← AJOUT
    case 'EN_LIVRAISON':
      return {
        'label': '🛵 Livraison',
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
        'borderColor': AppColors.primary
          .withValues(alpha: 0.3),
      };
    // ← AJOUT
    case 'VERIFICATION_FINALE':
      return {
        'label': '🔍 Vérif. finale',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'borderColor': AppColors.amber
          .withValues(alpha: 0.3),
      };
    case 'CLOTUREE':
      return {
        'label': '!!! Clôturée !!',
        'color': AppColors.green,
        'bgColor': AppColors.greenLight,
        'borderColor': AppColors.green
          .withValues(alpha: 0.3),
      };
    case 'ANNULEE':
      return {
        'label': 'Annulée',
        'color': Colors.red,
        'bgColor': const Color(0xFFFCEBEB),
        'borderColor': Colors.red
          .withValues(alpha: 0.3),
      };
    case 'LITIGE':
      return {
        'label': '⚠️ Litige',
        'color': Colors.orange,
        'bgColor': const Color(0xFFFFF3E0),
        'borderColor': Colors.orange
          .withValues(alpha: 0.3),
      };
    default:
      return {
        'label': statut,
        'color': Colors.grey,
        'bgColor': AppColors.background,
        'borderColor': AppColors.border,
      };
  }
}

  Future<void> _showConfirmerAvecAgent(
    int commandeId) async {

  // ← Charger agents disponibles
  final token  = await AuthStorage.getToken();
  final agentsResp = await http.get(
    Uri.parse(
      '${ApiConstants.baseUrl}/agent/disponibles'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (!mounted) return;

  final agents = agentsResp.statusCode == 200
    ? jsonDecode(agentsResp.body) as List
    : [];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20))),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2)),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
              CrossAxisAlignment.start,
            children: [
              Text(
                "Confirmer + Assigner collecte",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                "Choisissez l'agent qui va "
                "collecter chez le client",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecond,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        agents.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 40,
                    color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    "Aucun agent disponible",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecond,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ← Confirmer sans agent
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _changerStatut(
                        commandeId, 'CONFIRMEE');
                    },
                    child: Text(
                      "Confirmer sans agent",
                      style: GoogleFonts.poppins(
                        fontSize: 12)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: agents.length,
              itemBuilder: (_, i) {
                final agent = agents[i];
                final initiales =
                  '${agent['prenom']?[0] ?? ''}'
                  '${agent['nom']?[0] ?? ''}'
                  .toUpperCase();

                return ListTile(
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius:
                        BorderRadius.circular(12)),
                    child: Center(
                      child: Text(initiales,
                        style: GoogleFonts.poppins(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    '${agent['prenom']} '
                    '${agent['nom']}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    agent['telephone'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecond,
                    ),
                  ),
                  trailing: Container(
                    padding:
                      const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius:
                        BorderRadius.circular(20)),
                    child: Text("✅ Disponible",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // ← 1 clic = Confirmer + Assigner !
                  onTap: () async {
                    Navigator.pop(context);

                    try {
                      final token =
                        await AuthStorage.getToken();
                      final userId =
                        await AuthStorage.getUserId();

                      // ← ÉTAPE 1 : Confirmer
                      await http.put(
                        Uri.parse(
                          '${ApiConstants.commandes}'
                          '/$commandeId/statut'
                          '?statut=CONFIRMEE'
                          '&acteurId=$userId'),
                        headers: {
                          'Authorization':
                            'Bearer $token'},
                      );

                      // ← ÉTAPE 2 : Assigner agent
                      await http.put(
                        Uri.parse(
                          '${ApiConstants.commandes}'
                          '/$commandeId/assigner-agent'
                          '?agentId=${agent['id']}'
                          '&typeAffectation=COLLECTE'),
                        headers: {
                          'Authorization':
                            'Bearer $token'},
                      );

                      _loadCommandes();

                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          .showSnackBar(
                            SnackBar(
                              content: Text(
                                "✅ Confirmée ! "
                                "${agent['prenom']} "
                                "assigné pour collecte.",
                                style: GoogleFonts.poppins(
                                  fontSize: 12)),
                              backgroundColor:
                                AppColors.green,
                              behavior:
                                SnackBarBehavior.floating,
                            ),
                          );
                      }
                    } catch (e) {
                      debugPrint("Erreur: $e");
                    }
                  },
                );
              },
            ),

        const SizedBox(height: 20),
      ],
    ),
  );
}

// ← AJOUT : Signaler problème → LITIGE
void _showSignalerProbleme(int commandeId) {
  final commentaireController =
    TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)),
      title: Text("Signaler un problème",
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius:
                BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: Colors.red,
                  size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Un litige sera ouvert. "
                    "Décrivez le problème.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentaireController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                "Ex: Article manquant, "
                "endommagé...",
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.5)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
            Navigator.pop(context),
          child: Text("Annuler",
            style: GoogleFonts.poppins(
              color: AppColors.textSecond)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final token =
              await AuthStorage.getToken();
            final userId =
              await AuthStorage.getUserId();

            await http.post(
              Uri.parse(
                '${ApiConstants.baseUrl}'
                '/verification'
                '/$commandeId/confirmer'
                '?acteurType=PRESTATAIRE'
                '&statut=PROBLEME'
                '&commentaire=${Uri.encodeComponent(commentaireController.text)}'
                '&acteurId=$userId'),
              headers: {
                'Authorization':
                  'Bearer $token'},
            );
            _loadCommandes();
          },
          child: Text("Ouvrir litige",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

  // ── Label statut ───────────────────────────────────
  String _getLabelStatut(String statut) {
  switch (statut) {
    case 'CONFIRMEE':         return 'Confirmée';
    case 'EN_COLLECTE':       return '🛵 En collecte';
    case 'EN_VERIFICATION':   return '🔍 Vérification';
    case 'EN_TRAITEMENT':     return '🔄 En traitement';
    case 'TRAITEMENT_TERMINE':return '🏁 Traitement terminé';
    case 'EN_LIVRAISON':      return '🛵 En livraison';
    case 'VERIFICATION_FINALE':return '🔍 Vérif. finale';
    case 'CLOTUREE':          return '!! Clôturée !!!';
    case 'ANNULEE':           return 'Annulée';
    case 'LITIGE':            return '⚠️ Litige';
    default:                  return statut;
  }
}
}