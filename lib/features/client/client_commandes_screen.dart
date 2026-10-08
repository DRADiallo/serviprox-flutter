import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/core/widgets/photos_commande_widget.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import 'package:image_picker/image_picker.dart';

class ClientCommandesScreen extends StatefulWidget {
  const ClientCommandesScreen({super.key});

  @override
  State<ClientCommandesScreen> createState() =>
      _ClientCommandesScreenState();
}

class _ClientCommandesScreenState
    extends State<ClientCommandesScreen> {

  bool _isLoading = true;
  List<dynamic> _commandes = [];
  String _filterStatut = 'TOUS';

  final List<Map<String, String>> _filtres = [
  {'key': 'TOUS',               'label': 'Toutes'},
  {'key': 'CREE',               'label': 'En attente'},
  {'key': 'CONFIRMEE',          'label': 'Confirmées'},
  {'key': 'EN_COLLECTE',        'label': '🛵 Collecte'},
  {'key': 'EN_VERIFICATION',    'label': '?? Vérification'},
  {'key': 'EN_TRAITEMENT',      'label': 'En cours'},
  {'key': 'TRAITEMENT_TERMINE', 'label': '💰 À payer'},
  {'key': 'EN_LIVRAISON',       'label': '🛵 Livraison'},
  {'key': 'VERIFICATION_FINALE','label': 'Vérif. finale'},
  {'key': 'CLOTUREE',           'label': ' Clôturées'},
  {'key': 'ANNULEE',            'label': 'Annulées'},
  {'key': 'LITIGE',             'label': '⚠️ Litiges'},
];

  @override
  void initState() {
    super.initState();
    _loadCommandes();
  }

  // ── Charger commandes ─────────────────────────────
  Future<void> _loadCommandes() async {
    setState(() => _isLoading = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/client/$userId'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _commandes = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Confirmer réception → CLOTUREE ────────────────
  Future<void> _confirmerReception(
      int commandeId) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/$commandeId/statut'
          '?statut=CLOTUREE'
          '&acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _loadCommandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ Réception confirmée ! "
                "Merci pour votre confiance.",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur confirmation: $e");
    }
  }

  // ── Ouvrir litige → LITIGE ────────────────────────
  Future<void> _ouvrirLitige(
      int commandeId, String motif) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/$commandeId/statut'
          '?statut=LITIGE'
          '&acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _loadCommandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "⚠️ Litige ouvert. "
                "Le prestataire sera notifié.",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur litige: $e");
    }
  }

  // ── Dialog confirmation réception ─────────────────
  void _showConfirmationDialog(int commandeId,
      String nomPrestataire) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text("Confirmer la réception",
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius:
                  BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.green,
                    size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Confirmez-vous avoir reçu "
                      "vos articles de $nomPrestataire "
                      "en bon état ?",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ← Bouton ouvrir litige
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showLitigeDialog(commandeId);
            },
            child: Text("⚠️ Signaler un problème",
              style: GoogleFonts.poppins(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
          // ← Bouton confirmer
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _confirmerReception(commandeId);
            },
            child: Text("✅ Tout est bon !",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Dialog litige ─────────────────────────────────
  void _showLitigeDialog(int commandeId) {
    final motifController = TextEditingController();

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
                color: AppColors.amberLight,
                borderRadius:
                  BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.amber,
                    size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Décrivez le problème rencontré",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Ex: Article manquant, "
                  "dommage, mauvaise qualité...",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                    BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                    BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Colors.orange),
                ),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _ouvrirLitige(
                commandeId,
                motifController.text);
            },
            child: Text("Ouvrir un litige",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Commandes filtrées ────────────────────────────
  List<dynamic> get _filtered {
    if (_filterStatut == 'TOUS') return _commandes;
    return _commandes
      .where((c) => c['statut'] == _filterStatut)
      .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment:
            CrossAxisAlignment.start,
          children: [
            Text("Mes commandes",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "${_commandes.length} commande(s)",
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

          // ── Filtres ────────────────────────────
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

          // ── Liste commandes ────────────────────
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
                        Text("Aucune commande",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color:
                              AppColors.textSecond,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCommandes,
                    color: AppColors.green,
                    child: ListView.builder(
                      padding:
                        const EdgeInsets.all(14),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) =>
                        _buildCommandeCard(
                          _filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Carte commande ─────────────────────────────────
  Widget _buildCommandeCard(
      Map<String, dynamic> cmd) {
    final statut = cmd['statut'] ?? '';
    final config = _getStatutConfig(statut);

    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (config['borderColor'] as Color),
          width: 1),
      ),
      child: Column(
        children: [

          // ── Header ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: config['bgColor'] as Color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Logo pressing
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.green
                      .withValues(alpha: 0.15),
                    borderRadius:
                      BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (cmd['nomPrestataire']
                        as String? ?? 'P')[0]
                        .toUpperCase(),
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
                      Text(
                        cmd['nomPrestataire'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                            AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "Commande #${cmd['id']} · "
                        "${cmd['dateCommande']}",
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
                    color: config['color'] as Color,
                    borderRadius:
                      BorderRadius.circular(20),
                  ),
                  child: Text(
                    config['label'] as String,
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

          // ── Corps ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [

                // Prestations
                if (cmd['lignes'] != null &&
                    (cmd['lignes'] as List)
                      .isNotEmpty) ...[
                  ...(cmd['lignes'] as List)
                    .map((ligne) =>
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
                                  "× ${(ligne['quantite'] as double).toInt()}",
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
                              "${((ligne['montantLigne'] ?? 0)).toInt()} FCFA",
                              style:
                                GoogleFonts.poppins(
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
                  const Divider(height: 12),
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
                          cmd['motDepot'] ==
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
                      "${(cmd['montantTotal'] ?? 0).toInt()} FCFA",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),

                // ── Agent info ───────────────────
                if (cmd['nomAgentCollecte'] != null)
                  ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius:
                          BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            color: AppColors.primary,
                            size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "Agent : "
                            "${cmd['nomAgentCollecte']}",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            cmd['telephoneAgentCollecte']
                              ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                const SizedBox(height: 10),

                // ── Boutons action client ─────────
                _buildClientActions(cmd),
                // ← AJOUT ICI : Photos de la commande
                // Visibles pour tous les acteurs !
                PhotosCommandeWidget(
                  commandeId: cmd['id'] as int),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions client selon statut ───────────────────
  Widget _buildClientActions(
      Map<String, dynamic> cmd) {
    final statut = cmd['statut'] ?? '';
    final id = cmd['id'] as int;
    final nomPrestataire =
      cmd['nomPrestataire'] ?? '';

    switch (statut) {

      case 'CREE':
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
                Icons.hourglass_empty,
                color: AppColors.primary,
                size: 14),
              const SizedBox(width: 6),
              Text(
                "En attente de confirmation "
                "du prestataire",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );

      case 'CONFIRMEE':
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
                Icons.check_circle_outline,
                color: AppColors.green,
                size: 14),
              const SizedBox(width: 6),
              Text(
                "Commande confirmée par le "
                "prestataire",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        );

      // ← AJOUT : EN_COLLECTE
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
                size: 14),
              const SizedBox(width: 6),
              Text(
                "🛵 Agent en cours de collecte...",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );

      // ← MODIFICATION : EN_VERIFICATION
      // Client accepte ou refuse le prix réel !
      case 'EN_VERIFICATION':
        return Column(
          children: [
            // Info
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
                      cmd['montantTotal'] != null &&
                      cmd['montantTotal'] > 0
                        ? "💰 Prix réel fixé : "
                          "${(cmd['montantTotal'] ?? 0).toInt()} FCFA\n"
                          "Veuillez confirmer !"
                        : " ?? Vérification en cours...\n"
                          "Le prestataire vérifie vos articles.",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ← Si prix fixé → boutons accepter/refuser
            if (cmd['prixAccepteClient'] == false &&
                cmd['montantTotal'] != null &&
                cmd['montantTotal'] > 0) ...[
              const SizedBox(height: 8),

              // Détail prix
              if (cmd['detailPrixReel'] != null &&
                  cmd['detailPrixReel']
                    .toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets
                    .only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                      BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment:
                      CrossAxisAlignment.start,
                    children: [
                      Text("Détail :",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecond,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cmd['detailPrixReel'],
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  // ← Refuser
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
                        _accepterPrix(id, 'REFUSER'),
                      icon: const Icon(
                        Icons.close, size: 14),
                      label: Text("❌ Refuser",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ← Accepter
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
                        _accepterPrix(id, 'ACCEPTER'),
                      icon: const Icon(
                        Icons.check, size: 14),
                      label: Text(
                        "✅ Accepter le prix",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );  

      case 'EN_TRAITEMENT':
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
                Icons.local_laundry_service,
                color: AppColors.amber,
                size: 14),
              const SizedBox(width: 6),
              Text(
                "Vos articles sont en cours "
                "de traitement",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        );

      

    // ← NOUVEAU : Client doit payer !
      case 'TRAITEMENT_TERMINE':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 12),
            ),
            onPressed: () => _showPaiementDialog(
              id,
              (cmd['montantTotal'] ?? 0).toInt()),
            icon: const Icon(
              Icons.payment_outlined, size: 18),
            label: Text(
              "💰 Effectuer le paiement",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600)),
          ),
        );

      // ← Attente confirmation prestataire

      // ← En livraison
      case 'EN_LIVRAISON':
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.primary, size: 14),
              const SizedBox(width: 6),
              Text(
                "🚚 Votre commande est en livraison",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );

    // ← Client vérifie et confirme

     case 'VERIFICATION_FINALE':
        return Column(
          children: [

            // ← Voir photos
            GestureDetector(
              onTap: () => _showPreuvesDialog(
                cmd['id'] as int),
              child: Container(
                margin: const EdgeInsets
                  .only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius:
                    BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment:
                    MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.primary,
                      size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "📸 Voir et comparer les photos",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ← Info
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(10),
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
                      "Vérifiez vos articles reçus "
                      "avant de confirmer.",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ← Boutons OK ou Litige
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(
                        color: Colors.orange),
                      padding: const EdgeInsets
                        .symmetric(vertical: 12)),
                    onPressed: () =>
                      _showLitigeDialog(id),
                    icon: const Icon(
                      Icons.warning_amber, size: 16),
                    label: Text("⚠️ Signaler",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets
                        .symmetric(vertical: 12)),
                    onPressed: () =>
                      _confirmerReception(id),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16),
                    label: Text(
                      "✅ Tout est bon !",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        );

      

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
              const SizedBox(width: 6),
              Text(
                "Commande clôturée ✅",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.green,
                  fontWeight: FontWeight.w500,
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
              const SizedBox(width: 6),
              Text(
                "Litige en cours de traitement",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.orange,
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
              const SizedBox(width: 6),
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

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _accepterPrix(
    int commandeId, String decision) async {
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    final response = await http.put(
      Uri.parse(
        '${ApiConstants.commandes}'
        '/$commandeId/accepter-prix'
        '?decision=$decision'
        '&acteurId=$userId'),
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
                decision == 'ACCEPTER'
                  ? "✅ Prix accepté ! "
                    "Traitement en cours."
                  : "❌ Prix refusé. "
                    "Un litige a été ouvert.",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor:
                decision == 'ACCEPTER'
                  ? AppColors.green
                  : Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  } catch (e) {
    debugPrint("Erreur: $e");
  }
}

  // ── Config statut ──────────────────────────────────
  Map<String, dynamic> _getStatutConfig(
      String statut) {
    switch (statut) {
      case 'CREE':
        return {
          'label': 'En attente',
          'color': AppColors.primary,
          'bgColor': AppColors.primaryLight,
          'borderColor': AppColors.primary
            .withValues(alpha: 0.3),
        };
      case 'CONFIRMEE':
        return {
          'label': 'Confirmée',
          'color': AppColors.green,
          'bgColor': AppColors.greenLight,
          'borderColor': AppColors.green
            .withValues(alpha: 0.3),
        };

      case 'EN_COLLECTE':
        return {
          'label': '🛵 Collecte',
          'color': AppColors.primary,
          'bgColor': AppColors.primaryLight,
          'borderColor': AppColors.primary
            .withValues(alpha: 0.3),
        };

       case 'EN_VERIFICATION':
        return {
          'label': 'Vérification',
          'color': AppColors.amber,
          'bgColor': AppColors.amberLight,
          'borderColor': AppColors.amber
            .withValues(alpha: 0.3),
        };  

      case 'EN_TRAITEMENT':
        return {
          'label': 'En cours',
          'color': AppColors.amber,
          'bgColor': AppColors.amberLight,
          'borderColor': AppColors.amber
            .withValues(alpha: 0.3),
        };


      case 'TRAITEMENT_TERMINE':
        return {
          'label': '💰 À payer',
          'color': AppColors.primary,
          'bgColor': AppColors.primaryLight,
          'borderColor': AppColors.primary
            .withValues(alpha: 0.3),
        };
      
      case 'EN_LIVRAISON':
        return {
          'label': '🚚 Livraison',
          'color': AppColors.primary,
          'bgColor': AppColors.primaryLight,
          'borderColor': AppColors.primary
            .withValues(alpha: 0.3),
        };
      case 'VERIFICATION_FINALE':
        return {
          'label': '🔍 Vérifier',
          'color': AppColors.purple,
          'bgColor': AppColors.purpleLight,
          'borderColor': AppColors.purple
            .withValues(alpha: 0.3),
        };

      case 'CLOTUREE':
        return {
          'label': 'Clôturée',
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
          'label': 'Litige',
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

  Future<void> _showPreuvesDialog(
    int commandeId) async {
  // ← Charger les preuves
  final token = await AuthStorage.getToken();
  final response = await http.get(
    Uri.parse(
      '${ApiConstants.baseUrl}/preuve'
      '/commande/$commandeId'),
    headers: {
      'Authorization': 'Bearer $token'},
  );

  if (response.statusCode != 200) return;

  final preuves =
    jsonDecode(response.body) as List;

  if (!mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) =>
        Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets
                .only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius:
                  BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                const EdgeInsets.all(16),
              child: Text(
                "Photos de votre commande",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),

            // ← Liste preuves
            Expanded(
              child: preuves.isEmpty
                ? Center(
                    child: Text(
                      "Aucune photo disponible",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color:
                          AppColors.textSecond,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding:
                      const EdgeInsets.all(16),
                    itemCount: preuves.length,
                    itemBuilder: (_, i) {
                      final p = preuves[i];
                      final type =
                        p['type'] ?? '';
                      final statut =
                        p['statut'] ?? 'OK';
                      final photo =
                        p['contenu'];

                      return Container(
                        margin: const EdgeInsets
                          .only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius:
                            BorderRadius.circular(
                              12),
                          border: Border.all(
                            color: statut == 'OK'
                              ? AppColors.green
                                  .withValues(
                                    alpha: 0.3)
                              : Colors.red
                                  .withValues(
                                    alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment
                              .start,
                          children: [

                            // Header
                            Container(
                              padding:
                                const EdgeInsets
                                  .all(10),
                              decoration:
                                BoxDecoration(
                                  color: statut ==
                                    'OK'
                                    ? AppColors
                                        .greenLight
                                    : const Color(
                                        0xFFFCEBEB),
                                  borderRadius:
                                    const
                                    BorderRadius
                                      .only(
                                      topLeft: Radius
                                        .circular(12),
                                      topRight: Radius
                                        .circular(12),
                                    ),
                                ),
                              child: Row(
                                children: [
                                  Text(
                                    _getLabelType(
                                      type),
                                    style:
                                      GoogleFonts
                                        .poppins(
                                          fontSize:
                                            12,
                                          fontWeight:
                                            FontWeight
                                              .w600,
                                          color: statut
                                            == 'OK'
                                            ? AppColors
                                                .green
                                            : Colors
                                                .red,
                                        ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    statut == 'OK'
                                      ? "✅ OK"
                                      : "⚠️ Problème",
                                    style:
                                      GoogleFonts
                                        .poppins(
                                          fontSize:
                                            11,
                                          color: statut
                                            == 'OK'
                                            ? AppColors
                                                .green
                                            : Colors
                                                .red,
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            // Photo
                            if (photo != null &&
                                photo.toString()
                                  .isNotEmpty)
                              ClipRRect(
                                borderRadius:
                                  const BorderRadius
                                    .only(
                                    bottomLeft:
                                      Radius.circular(
                                        12),
                                    bottomRight:
                                      Radius.circular(
                                        12),
                                  ),
                                child:
                                  Image.memory(
                                    base64Decode(
                                      photo
                                        .toString()),
                                    width:
                                      double.infinity,
                                    height: 200,
                                    fit:
                                      BoxFit.cover,
                                  ),
                              )
                            else
                              Container(
                                height: 60,
                                child: Center(
                                  child: Text(
                                    "Pas de photo",
                                    style:
                                      GoogleFonts
                                        .poppins(
                                          fontSize:
                                            12,
                                          color:
                                            AppColors
                                              .textSecond,
                                        ),
                                  ),
                                ),
                              ),

                            // Commentaire
                            if (p['commentaire'] !=
                                null &&
                                p['commentaire']
                                  .toString()
                                  .isNotEmpty)
                              Padding(
                                padding:
                                  const EdgeInsets
                                    .all(10),
                                child: Text(
                                  p['commentaire'],
                                  style:
                                    GoogleFonts
                                      .poppins(
                                        fontSize:
                                          11,
                                        color:
                                          AppColors
                                            .textSecond,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
    ),
  );
}

void _showPaiementDialog(
    int commandeId, int montant) {
  String modePaiement = 'WAVE';
  final referenceController =
    TextEditingController();
  String? captureBase64;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setModal) =>
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx)
              .viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius:
                        BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text("💰 Effectuer le paiement",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Montant
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius:
                      BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Montant à payer",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.green)),
                      Text("$montant FCFA",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text("Mode de paiement",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Modes paiement
                Row(
                  children: [
                    _modeBtn('🟠', 'WAVE',
                      'Wave', modePaiement,
                      (v) => setModal(
                        () => modePaiement = v)),
                    const SizedBox(width: 8),
                    _modeBtn('🟠', 'ORANGE_MONEY',
                      'Orange', modePaiement,
                      (v) => setModal(
                        () => modePaiement = v)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _modeBtn('💵', 'ESPECES',
                      'Espèces', modePaiement,
                      (v) => setModal(
                        () => modePaiement = v)),
                    const SizedBox(width: 8),
                    _modeBtn('🟣', 'FREE_MONEY',
                      'Free Money', modePaiement,
                      (v) => setModal(
                        () => modePaiement = v)),
                  ],
                ),

                const SizedBox(height: 16),

                // Wave/Orange → capture écran
                if (modePaiement != 'ESPECES') ...[
                  Text(
                    "📸 Capture d'écran du reçu",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final photo =
                        await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70);
                      if (photo != null) {
                        final bytes =
                          await photo.readAsBytes();
                        setModal(() =>
                          captureBase64 =
                            base64Encode(bytes));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: captureBase64 != null
                        ? 180 : 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                          BorderRadius.circular(10),
                        border: Border.all(
                          color: captureBase64 != null
                            ? AppColors.green
                            : AppColors.border,
                          width: captureBase64 != null
                            ? 2 : 1),
                      ),
                      child: captureBase64 != null
                        ? ClipRRect(
                            borderRadius:
                              BorderRadius.circular(9),
                            child: Image.memory(
                              base64Decode(
                                captureBase64!),
                              fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment:
                              MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.textMuted,
                                size: 28),
                              const SizedBox(height: 6),
                              Text(
                                "Ajouter capture d'écran",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecond),
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Référence
                  TextField(
                    controller: referenceController,
                    decoration: InputDecoration(
                      labelText: "Référence transaction",
                      hintText: "Ex: DK2024XXXXX",
                      prefixIcon: const Icon(
                        Icons.receipt_outlined,
                        color: AppColors.green),
                      border: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5)),
                    ),
                  ),
                ],

                // Espèces → info
                if (modePaiement == 'ESPECES') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
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
                          size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Le prestataire devra "
                            "confirmer avoir reçu "
                            "$montant FCFA en espèces.",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

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
                      try {
                        final token =
                          await AuthStorage.getToken();
                        final userId =
                          await AuthStorage.getUserId();

                        final uri = Uri.parse(
                          '${ApiConstants.baseUrl}'
                          '/paiement/commande'
                          '/$commandeId'
                          '?montant=$montant'
                          '&modePaiement=$modePaiement'
                          '${referenceController.text.isNotEmpty ? "&reference=${referenceController.text}" : ""}'
                          '${captureBase64 != null ? "&captureBase64=$captureBase64" : ""}');

                        final response = await http.post(
                          uri,
                          headers: {
                            'Authorization':
                              'Bearer $token'},
                        );

                        if (response.statusCode == 200) {
                          Navigator.pop(ctx);
                          _loadCommandes();
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                              .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "✅ Paiement enregistré ! "
                                    "En attente confirmation "
                                    "du prestataire.",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12)),
                                  backgroundColor:
                                    AppColors.green,
                                  behavior:
                                    SnackBarBehavior.floating,
                                ),
                              );
                          }
                        }
                      } catch (e) {
                        debugPrint("Erreur paiement: $e");
                      }
                    },
                    child: Text(
                      "Confirmer le paiement",
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
    ),
  );
}

// ← Bouton mode paiement
Widget _modeBtn(
  String emoji,
  String value,
  String label,
  String selected,
  Function(String) onSelect,
) {
  final bool isSelected = selected == value;
  return Expanded(
    child: GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
            ? AppColors.greenLight
            : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
              ? AppColors.green
              : AppColors.border,
            width: isSelected ? 1.5 : 0.5),
        ),
        child: Column(
          children: [
            Text(emoji,
              style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected
                  ? FontWeight.w600
                  : FontWeight.normal,
                color: isSelected
                  ? AppColors.green
                  : AppColors.textSecond,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

String _getLabelType(String type) {
  switch (type) {
    case 'COLLECTE_CLIENT':
      return "📦 Collecte";
    case 'RECEPTION_PRESTATAIRE':
      return "🏪 Réception pressing";
    case 'LIVRAISON_CLIENT':
      return "🚚 Livraison";
    default:
      return "📸 $type";
  }
}
}