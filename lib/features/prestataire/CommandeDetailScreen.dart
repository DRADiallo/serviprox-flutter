import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class CommandeDetailScreen extends StatefulWidget {
  final int commandeId;

  const CommandeDetailScreen({
    super.key,
    required this.commandeId,
  });

  @override
  State<CommandeDetailScreen> createState() =>
      _CommandeDetailScreenState();
}

class _CommandeDetailScreenState
    extends State<CommandeDetailScreen> {

  // ── Variables ─────────────────────────────────────
  bool _isLoading      = true;
  bool _isUpdating     = false;
  Map<String, dynamic> _commande = {};
  List<dynamic> _lignes   = [];
  List<dynamic> _agents   = [];
  List<dynamic> _preuves = [];


  @override
  void initState() {
    super.initState();
    _loadCommande();
  }

  // ── Charger détail commande ───────────────────────
  Future<void> _loadCommande() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthStorage.getToken();

      // Charger commande + agents en parallèle
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '${ApiConstants.commandes}'
            '/${widget.commandeId}'),
          headers: {
            'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}'
            '/agent/disponibles'),
          headers: {
            'Authorization': 'Bearer $token'},
        ),
      ]);
      // Ajout New
      final preuveResp = await http.get(
          Uri.parse(
            '${ApiConstants.baseUrl}/preuve'
            '/commande/${widget.commandeId}'),
          headers: {
            'Authorization': 'Bearer $token'},
        );

      final cmdResp   = results[0];
      final agentResp = results[1];

      //  debugPrints
      debugPrint("=== CMD STATUS: ${cmdResp.statusCode} ===");
      debugPrint("=== CMD BODY: ${cmdResp.body} ===");
      debugPrint("=== AGENT STATUS: ${agentResp.statusCode} ===");
      debugPrint("=== AGENT BODY: ${agentResp.body} ===");

      if (cmdResp.statusCode == 200) {
        final data = jsonDecode(cmdResp.body);
        setState(() {
          _commande = data;
          _lignes   = data['lignes'] ?? [];
        });
      }

      if (agentResp.statusCode == 200) {
        setState(() {
          _agents = jsonDecode(agentResp.body);
        });
      }

    } catch (e) {
      debugPrint("Erreur: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Changer statut ────────────────────────────────
  Future<void> _changerStatut(String statut) async {
    setState(() => _isUpdating = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.put(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/${widget.commandeId}/statut'
          '?statut=$statut'
          '&acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await _loadCommande();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ Statut mis à jour !",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur statut: $e");
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ── Assigner agent ────────────────────────────────
  Future<void> _assignerAgent(
    int agentId, String typeAffectation) async {
  setState(() => _isUpdating = true);
  try {
    final token = await AuthStorage.getToken();

    final response = await http.put(
      Uri.parse(
        '${ApiConstants.commandes}'
        '/${widget.commandeId}/assigner-agent'
        '?agentId=$agentId'
        '&typeAffectation=$typeAffectation'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await _loadCommande();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Agent $typeAffectation assigné !",
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
  } finally {
    setState(() => _isUpdating = false);
  }
}

  // ── Dialog assigner agent ─────────────────────────
 // ← MODIFICATION : prend typeAffectation
  void _showAssignerAgentDialog(
      String typeAffectation) {
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              typeAffectation == 'COLLECTE'
                ? "Choisir agent de collecte"
                : "Choisir agent de livraison",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),

          _agents.isEmpty
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
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _agents.length,
                itemBuilder: (_, i) {
                  final agent = _agents[i];
                  final initiales =
                    '${agent['prenom']?[0] ?? ''}'
                    '${agent['nom']?[0] ?? ''}'
                    .toUpperCase();

                  return ListTile(
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: typeAffectation ==
                          'COLLECTE'
                          ? AppColors.greenLight
                          : AppColors.primaryLight,
                        borderRadius:
                          BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(initiales,
                          style: GoogleFonts.poppins(
                            color: typeAffectation ==
                              'COLLECTE'
                              ? AppColors.green
                              : AppColors.primary,
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
                          BorderRadius.circular(20),
                      ),
                      child: Text("Disponible",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onTap: () => _assignerAgent(
                      agent['id'],
                      typeAffectation),
                  );
                },
              ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Prochain statut possible ──────────────────────
  String? get _prochainStatut {
  switch (_commande['statut']) {
    case 'CREE':
      return 'CONFIRMEE';
    case 'CONFIRMEE':
      return 'EN_VERIFICATION';
    case 'EN_VERIFICATION':
      return 'EN_TRAITEMENT';
    case 'EN_TRAITEMENT':
      return 'TRAITEMENT_TERMINE';
    case 'TRAITEMENT_TERMINE':
      return 'PAIEMENT_RECU';
    case 'PAIEMENT_RECU':
      return 'EN_LIVRAISON';
    case 'EN_LIVRAISON':
      return 'VERIFICATION_FINALE';
    case 'VERIFICATION_FINALE':
      return 'TERMINEE';
    case 'TERMINEE':
      return 'CLOTUREE';
    default:
      return null;
  }
}

  String _labelStatut(String? statut) {
  switch (statut) {
    case 'CONFIRMEE':
      return '✅ Confirmer la commande';
    case 'EN_VERIFICATION':
      return '🔍 Démarrer vérification';
    case 'EN_TRAITEMENT':
      return '🔄 Démarrer le traitement';
    case 'TRAITEMENT_TERMINE':
      return '🏁 Traitement terminé';
    case 'PAIEMENT_RECU':
      return '💰 Paiement reçu';
    case 'EN_LIVRAISON':
      return '🚚 Démarrer livraison';
    case 'VERIFICATION_FINALE':
      return '🔍 Vérification finale';
    case 'TERMINEE':
      return '✅ Terminer';
    case 'CLOTUREE':
      return ' Clôturer';
    default:
      return '';
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
            Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Commande #${widget.commandeId}",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh, color: Colors.white),
            onPressed: _loadCommande,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.green))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // ── Statut ────────────────────────
                _buildStatutBadge(),

                const SizedBox(height: 14),

                // ── Infos client ──────────────────
                _buildSection(
                  title: "Client",
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        "Nom",
                        _commande['nomClient'] ?? ''),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        "Téléphone",
                        _commande['telephoneClient']
                          ?? 'Non renseigné'),
                      _buildInfoRow(
                        Icons.home_outlined,
                        "Mode dépôt",
                        _commande['motDepot'] ==
                          'COLLECTE_DOMICILE'
                          ? "Collecte à domicile"
                          : "Dépôt atelier"),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Agent assigné ─────────────────
                // ── Agent assigné ─────────────────────────────────
                _buildSection(
                  title: "Agents assignés",
                  icon: Icons.delivery_dining_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Agent Collecte ──────────────────────
                      Text("Collecte :",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecond,
                        ),
                      ),
                      const SizedBox(height: 6),

                      _commande['agentCollecteId'] != null
                        ? _buildInfoRow(
                            Icons.person,
                            "Agent",
                            _commande['nomAgentCollecte'] ?? '')
                        : _commande['statut'] == 'CONFIRMEE' &&
                          _commande['motDepot'] ==
                            'COLLECTE_DOMICILE'
                          ? SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.green,
                                  side: const BorderSide(
                                    color: AppColors.green),
                                ),
                                onPressed: () =>
                                  _showAssignerAgentDialog(
                                    'COLLECTE'),
                                icon: const Icon(
                                  Icons.person_add, size: 16),
                                label: Text(
                                  "Assigner agent collecte",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12)),
                              ),
                            )
                          : Text(
                              _commande['motDepot'] ==
                                'DEPOT_ATELIER'
                                ? "Dépôt atelier — pas d'agent"
                                : "En attente de confirmation",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecond,
                              ),
                            ),

                      const SizedBox(height: 12),

                      // ── Agent Livraison ─────────────────────
                      Text("Livraison :",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecond,
                        ),
                      ),
                      const SizedBox(height: 6),

                      _commande['agentLivraisonId'] != null
                        ? _buildInfoRow(
                            Icons.person,
                            "Agent",
                            _commande['nomAgentLivraison'] ?? '')
                        : _commande['statut'] == 'TERMINEE'
                          ? SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary),
                                ),
                                onPressed: () =>
                                  _showAssignerAgentDialog(
                                    'LIVRAISON'),
                                icon: const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 16),
                                label: Text(
                                  "Assigner agent livraison",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12)),
                              ),
                            )
                          : Text(
                              "En attente de fin de traitement",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecond,
                              ),
                            ),
                    ],
                  ),
                ),

                // ── Prestations ───────────────────
                _buildSection(
                  title: "Prestations",
                  icon: Icons.list_alt_outlined,
                  child: Column(
                    children: [
                      ..._lignes.map((ligne) =>
                        Padding(
                          padding: const EdgeInsets
                            .only(bottom: 8),
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
                                    size: 14),
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

                      // Total
                      Row(
                        mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            "${(_commande['montantTotal'] ?? 0).toInt()} FCFA",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                //Ajout New pour preuve
                if (_preuves.isNotEmpty)
                    _buildSection(
                      title: "Preuves photos",
                      icon: Icons.photo_library_outlined,
                      child: Column(
                        children: _preuves.map((preuve) =>
                          _buildPreuveCard(preuve)).toList(),
                      ),
                    ),

                const SizedBox(height: 20),

                // ── Boutons d'action ──────────────
                // ← MODIFICATION : case CREE
                // Si COLLECTE_DOMICILE → montrer dialog agent
                // Si DEPOT_ATELIER → confirmer directement

                if (_commande['statut'] == 'CREE') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                              color: Colors.red),
                            padding: const EdgeInsets
                              .symmetric(vertical: 12),
                          ),
                          onPressed: _isUpdating
                            ? null
                            : () => _changerStatut('ANNULEE'),
                          child: Text("Refuser",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets
                              .symmetric(vertical: 12),
                          ),
                          onPressed: _isUpdating
                            ? null
                            // ← CHANGEMENT :
                            // Si COLLECTE_DOMICILE →
                            // Dialog agent d'abord !
                            : () {
                                if (_commande['motDepot'] ==
                                    'COLLECTE_DOMICILE') {
                                  _showConfirmerAvecAgent();
                                } else {
                                  // DEPOT_ATELIER →
                                  // Confirmer directement
                                  _changerStatut('CONFIRMEE');
                                }
                              },
                          child: _isUpdating
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                            : Text("✅ Confirmer",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  ]else if (_prochainStatut != null) ...[
                  // Bouton prochain statut
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _commande[
                            'statut'] == 'CONFIRMEE'
                          ? AppColors.amber
                          : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      onPressed: _isUpdating
                        ? null
                        : () => _changerStatut(
                            _prochainStatut!),
                      child: _isUpdating
                        ? const SizedBox(
                            width: 22, height: 22,
                            child:
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                        : Text(
                            _labelStatut(
                              _prochainStatut),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                                FontWeight.w600,
                            ),
                          ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }

  

  // ← NOUVEAU : Confirmer + Assigner agent
// en une seule étape !
void _showConfirmerAvecAgent() {
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
            borderRadius: BorderRadius.circular(2),
          ),
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

        // Liste agents disponibles
        _agents.isEmpty
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
                      _changerStatut('CONFIRMEE');
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
              itemCount: _agents.length,
              itemBuilder: (_, i) {
                final agent = _agents[i];
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
                        BorderRadius.circular(12),
                    ),
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
                        BorderRadius.circular(20),
                    ),
                    child: Text("Disponible",
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
                    setState(() =>
                      _isUpdating = true);

                    try {
                      final token =
                        await AuthStorage.getToken();
                      final userId =
                        await AuthStorage.getUserId();

                      // ← ÉTAPE 1 : Confirmer
                      await http.put(
                        Uri.parse(
                          '${ApiConstants.commandes}'
                          '/${widget.commandeId}'
                          '/statut?statut=CONFIRMEE'
                          '&acteurId=$userId'),
                        headers: {
                          'Authorization':
                            'Bearer $token'},
                      );

                      // ← ÉTAPE 2 : Assigner agent
                      await http.put(
                        Uri.parse(
                          '${ApiConstants.commandes}'
                          '/${widget.commandeId}'
                          '/assigner-agent'
                          '?agentId=${agent['id']}'
                          '&typeAffectation=COLLECTE'),
                        headers: {
                          'Authorization':
                            'Bearer $token'},
                      );

                      await _loadCommande();

                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          .showSnackBar(
                            SnackBar(
                              content: Text(
                                "✅ Commande confirmée ! "
                                "${agent['prenom']} "
                                "assigné pour la collecte.",
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
                    } finally {
                      setState(() =>
                        _isUpdating = false);
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

  // ── Badge statut ───────────────────────────────────
  Widget _buildStatutBadge() {
  final statut = _commande['statut'] ?? '';
  Color color;
  Color bgColor;
  String label;

  switch (statut) {
    case 'CREE':
      color = AppColors.primary;
      bgColor = AppColors.primaryLight;
      label = "🆕 Nouvelle commande";
      break;
    case 'CONFIRMEE':
      color = AppColors.green;
      bgColor = AppColors.greenLight;
      label = "✅ Confirmée";
      break;
    case 'EN_VERIFICATION':
      color = AppColors.amber;
      bgColor = AppColors.amberLight;
      label = "🔍 En vérification";
      break;
    case 'EN_TRAITEMENT':
      color = AppColors.amber;
      bgColor = AppColors.amberLight;
      label = "🔄 En traitement";
      break;
    case 'TRAITEMENT_TERMINE':
      color = AppColors.purple;
      bgColor = AppColors.purpleLight;
      label = "🏁 Traitement terminé";
      break;
    case 'PAIEMENT_RECU':
      color = AppColors.green;
      bgColor = AppColors.greenLight;
      label = "💰 Paiement reçu";
      break;
    case 'EN_LIVRAISON':
      color = AppColors.primary;
      bgColor = AppColors.primaryLight;
      label = "🚚 En livraison";
      break;
    case 'VERIFICATION_FINALE':
      color = AppColors.amber;
      bgColor = AppColors.amberLight;
      label = "🔍 Vérification finale";
      break;
    case 'TERMINEE':
      color = AppColors.green;
      bgColor = AppColors.greenLight;
      label = "✅ Terminée";
      break;
    case 'CLOTUREE':
      color = AppColors.green;
      bgColor = AppColors.greenLight;
      label = " Clôturée ✅";
      break;
    case 'ANNULEE':
      color = Colors.red;
      bgColor = const Color(0xFFFCEBEB);
      label = "❌ Annulée";
      break;
    case 'LITIGE':
      color = Colors.orange;
      bgColor = AppColors.amberLight;
      label = "⚠️ Litige";
      break;
    default:
      color = Colors.grey;
      bgColor = AppColors.background;
      label = statut;
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          _commande['dateCommande']
            ?.toString() ?? '',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    ),
  );
}

  // ── Section ────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment:
          CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                color: AppColors.green, size: 18),
              const SizedBox(width: 8),
              Text(title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Info row ───────────────────────────────────────
  Widget _buildInfoRow(
      IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
            color: AppColors.textSecond, size: 16),
          const SizedBox(width: 8),
          Text("$label : ",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecond,
            ),
          ),
          Expanded(
            child: Text(value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreuveCard(
    Map<String, dynamic> preuve) {
  final type = preuve['type'] ?? '';
  final statut = preuve['statut'] ?? 'OK';
  final commentaire =
    preuve['commentaire'] ?? '';
  final photo = preuve['contenu'];

  Color statutColor = statut == 'OK'
    ? AppColors.green : Colors.red;
  Color statutBg = statut == 'OK'
    ? AppColors.greenLight
    : const Color(0xFFFCEBEB);

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment:
        CrossAxisAlignment.start,
      children: [

        // ← Header preuve
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statutBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.camera_alt_outlined,
                color: statutColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getLabelTypePreuve(type),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statutColor,
                  ),
                ),
              ),
              Container(
                padding:
                  const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statutColor,
                  borderRadius:
                    BorderRadius.circular(20),
                ),
                child: Text(
                  statut == 'OK'
                    ? "✅ OK"
                    : "⚠️ Problème",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ← Photo
        if (photo != null && photo.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: Image.memory(
              base64Decode(photo),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 80,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Center(
              child: Text(
                "Pas de photo disponible",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecond,
                ),
              ),
            ),
          ),

        // ← Commentaire
        if (commentaire.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: AppColors.textSecond),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(commentaire,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecond,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ← Label type preuve
String _getLabelTypePreuve(String type) {
  switch (type) {
    case 'COLLECTE_CLIENT':
      return "📦 Collecte chez le client";
    case 'RECEPTION_PRESTATAIRE':
      return "🏪 Réception au pressing";
    case 'LIVRAISON_CLIENT':
      return "🚚 Livraison chez le client";
    case 'AVANT_INTERVENTION':
      return "📸 Avant intervention";
    case 'APRES_INTERVENTION':
      return "📸 Après intervention";
    default:
      return type;
  }
}

  
}