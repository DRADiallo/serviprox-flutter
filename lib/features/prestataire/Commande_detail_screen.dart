// lib/features/prestataire/commande_detail_screen.dart   ← NOM CORRIGÉ (c minuscule)
//
// ✅ ARCHITECTURE THÈSE : Zéro if(typeService)
// etapesEffectives = _configEtapes → reçus du parent (depuis la config prestataire)
// _fullEtapes      = smart : si etapesEffectives contient CREE → liste directe
//                           sinon → ['CREE','CONFIRMEE', ..._configEtapes, 'CLOTUREE']
//                           ATTENTE_PAIEMENT : inclus UNIQUEMENT si dans la config
//                           → chaque prestataire choisit son flux
// _etapeIndex      = switch(statut) + indexOf(.toUpperCase()) pour EN_COURS
// _prochainStep    = config-driven : si ATTENTE_PAIEMENT ∈ _fullEtapes → va au paiement
//                                    sinon → CLOTUREE directement
// avecAgent        = arg optionnel (default false) → section agents visible si true
//
// FLUX (100% config-driven — chaque prestataire configure ses étapes) :
//   CREE → [CONFIRMEE* : bilan/facture] → [étapes métier] → [ATTENTE_PAIEMENT*] → CLOTUREE
//   * CONFIRMEE   : retirable → pas de bilan, passe directement aux étapes métier
//   * ATTENTE_PAIEMENT : retirable → clôture directe après les étapes métier
//   * Contenu facture : dynamique (frais collecte + frais livraison si présents)
//   Le client paie côté suivi_commande_client_screen → CLOTUREE ou LITIGE
//
// COULEURS : AppColors.green (#27500A) pour le prestataire

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_storage.dart';
// ✅ Nouveaux fichiers extraits pour faciliter le rollback
import '../commande/commande_progress_bar.dart';
import 'bilan_dialog.dart';

class CommandeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> commande;

  /// Couche 2 : étapes dynamiques de la config prestataire
  final List<String> etapesEffectives;

  /// Agents disponibles (non vide uniquement si avecAgent=true)
  final List<Map<String, dynamic>> agents;

  final int prestataireId;

  /// Vrai si le prestataire a activé l'option "avec agents"
  final bool avecAgent;

  const CommandeDetailScreen({
    super.key,
    required this.commande,
    required this.etapesEffectives,
    required this.agents,
    required this.prestataireId,
    this.avecAgent = false,
  });

  @override
  State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
}

class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
  late Map<String, dynamic> _cmd;
  late List<String> _configEtapes;
  late List<Map<String, dynamic>> _agents;
  late bool _avecAgent;
  bool _loading = false;

  // Montant établi lors du bilan (confirmé avec la commande)
  double _montantTotal = 0.0;

  // ── Étapes complètes (progress bar) ──────────────────────────────────────
  // Smart : gère l'ancienne archi (étapes métier seulement)
  // et la nouvelle archi (etapesEffectives inclut déjà CREE/CONFIRMEE/CLOTUREE)
  List<String> get _fullEtapes {
    // ⚠️ ATTENTE_PAIEMENT N'EST PAS auto-inséré : le prestataire
    // décide lui-même dans ses paramètres s'il veut ce statut.
    // Si absent → _prochainStep saute directement à CLOTUREE.
    if (_configEtapes.isEmpty) {
      return ['CREE', 'CONFIRMEE', 'CLOTUREE'];
    } else if (_configEtapes.contains('CREE')) {
      // Nouvelle architecture : etapesEffectives inclut déjà les étapes fixes
      return List<String>.from(_configEtapes);
    } else {
      // Ancienne architecture : etapesEffectives = étapes métier seulement
      return ['CREE', 'CONFIRMEE', ..._configEtapes, 'CLOTUREE'];
    }
  }

  @override
  void initState() {
    super.initState();
    _cmd = Map<String, dynamic>.from(widget.commande);
    _configEtapes = List<String>.from(widget.etapesEffectives);
    _agents = List<Map<String, dynamic>>.from(widget.agents);
    _avecAgent = widget.avecAgent || widget.agents.isNotEmpty;
    // Récupérer le montant déjà fixé (si re-chargement de la commande)
    _montantTotal =
        ((_cmd['montantTotal'] ?? _cmd['montant']) as num?)?.toDouble() ?? 0.0;
  }

  // ── Index dans _fullEtapes ────────────────────────────────────────────────
  int get _etapeIndex {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    final full = _fullEtapes;
    switch (statut) {
      case 'CREE':
        return full.indexOf('CREE').clamp(0, full.length - 1);
      case 'CONFIRMEE':
        return full.indexOf('CONFIRMEE').clamp(0, full.length - 1);
      case 'CLOTUREE':
        return full.indexOf('CLOTUREE').clamp(0, full.length - 1);
      case 'ATTENTE_PAIEMENT':
        final idx = full.indexOf('ATTENTE_PAIEMENT');
        return idx >= 0 ? idx : full.length - 2;
      case 'ANNULEE':
        return -1;
      case 'EN_COURS':
        final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase(); // FIX
        // Étapes métier = tout sauf les étapes fixes
        final mid = full.where((e) =>
            e != 'CREE' && e != 'CONFIRMEE' &&
            e != 'ATTENTE_PAIEMENT' && e != 'CLOTUREE').toList();
        final idx = mid.indexOf(ec);
        final confirmIdx = full.indexOf('CONFIRMEE');
        return idx >= 0 ? confirmIdx + 1 + idx : confirmIdx + 1;
      default:
        return 0;
    }
  }

  // ── Prochaine transition ───────────────────────────────────────────────────
  Map<String, String?>? get _prochainStep {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    final full = _fullEtapes;
    final mid = full.where((e) =>
        e != 'CREE' && e != 'CONFIRMEE' &&
        e != 'ATTENTE_PAIEMENT' && e != 'CLOTUREE').toList();

    switch (statut) {
      case 'CREE':
        // Si CONFIRMEE n'est pas configuré → sauter le bilan, aller directement
        if (!full.contains('CONFIRMEE')) {
          if (mid.isNotEmpty) return {'statut': 'EN_COURS', 'etapeCourante': mid.first};
          final hasAttente = full.contains('ATTENTE_PAIEMENT');
          return {'statut': hasAttente ? 'ATTENTE_PAIEMENT' : 'CLOTUREE', 'etapeCourante': null};
        }
        return {'statut': 'CONFIRMEE', 'etapeCourante': null};
      case 'CONFIRMEE':
        if (mid.isEmpty) {
          // Pas d'étapes métier → aller à ATTENTE_PAIEMENT si configuré, sinon CLOTUREE
          final hasAttente = full.contains('ATTENTE_PAIEMENT');
          return {'statut': hasAttente ? 'ATTENTE_PAIEMENT' : 'CLOTUREE', 'etapeCourante': null};
        }
        return {'statut': 'EN_COURS', 'etapeCourante': mid.first};
      case 'EN_COURS':
        final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = mid.indexOf(ec);
        if (idx < 0 || idx == mid.length - 1) {
          // Fin des étapes métier → ATTENTE_PAIEMENT si configuré, sinon CLOTUREE
          final hasAttente = full.contains('ATTENTE_PAIEMENT');
          return {'statut': hasAttente ? 'ATTENTE_PAIEMENT' : 'CLOTUREE', 'etapeCourante': null};
        }
        return {'statut': 'EN_COURS', 'etapeCourante': mid[idx + 1]};
      // ATTENTE_PAIEMENT : c'est le CLIENT qui paie → prestataire ne peut pas avancer
      case 'ATTENTE_PAIEMENT':
      case 'CLOTUREE':
      case 'ANNULEE':
        return null;
      default:
        return null;
    }
  }

  String get _labelBoutonAction {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    final full = _fullEtapes;
    final mid = full.where((e) =>
        e != 'CREE' && e != 'CONFIRMEE' &&
        e != 'ATTENTE_PAIEMENT' && e != 'CLOTUREE').toList();

    switch (statut) {
      case 'CREE':
        if (!full.contains('CONFIRMEE')) {
          // Pas de bilan → démarrage direct
          if (mid.isNotEmpty) return 'Démarrer la prestation';
          final hasAttente = _fullEtapes.contains('ATTENTE_PAIEMENT');
          return hasAttente ? 'Envoyer en paiement' : 'Clôturer la prestation';
        }
        return 'Confirmer et établir le bilan';
      case 'CONFIRMEE':
        if (mid.isEmpty) {
          final hasAttente = _fullEtapes.contains('ATTENTE_PAIEMENT');
          return hasAttente ? 'Envoyer en paiement' : 'Clôturer la prestation';
        }
        return 'Démarrer la prestation';
      case 'EN_COURS':
        final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = mid.indexOf(ec);
        if (idx >= 0 && idx < mid.length - 1) {
          return 'Passer à : ${_cap(mid[idx + 1])}';
        }
        final hasAttente = _fullEtapes.contains('ATTENTE_PAIEMENT');
        return hasAttente ? 'Terminer — demander le paiement' : 'Clôturer la prestation';
      default:
        return '';
    }
  }

  // ── Dialog bilan (montant total) ──────────────────────────────────────────
  // ✅ Délègue à BilanDialog (bilan_dialog.dart) — rollback = retirer l'import
  Future<bool> _showBilanDialog() async {
    final montant = await BilanDialog.show(
      context,
      commande: _cmd,
      montantInitial: _montantTotal,
    );
    if (montant == null) return false;
    setState(() => _montantTotal = montant);
    return true;
  }

  // ── PUT /api/commande/{id}/statut?statut=...&acteurId=...&etapeCourante=... ──
  Future<void> _avancerStatut() async {
    final next = _prochainStep;
    if (next == null) return;

    // Si on confirme (CREE → CONFIRMEE) : afficher le bilan d'abord
    if (next['statut'] == 'CONFIRMEE') {
      final ok = await _showBilanDialog();
      if (!ok) return;
    }

    setState(() => _loading = true);
    final token = await AuthStorage.getToken();
    final id = _cmd['id'];

    var url = '${ApiConstants.commandes}/$id/statut'
        '?statut=${next['statut']}'
        '&acteurId=${widget.prestataireId}';

    if (next['etapeCourante'] != null) {
      url += '&etapeCourante=${next['etapeCourante']}';
    }
    // Inclure le montant lors de la confirmation
    if (next['statut'] == 'CONFIRMEE' && _montantTotal > 0) {
      url += '&montantTotal=${_montantTotal.toStringAsFixed(0)}';
    }

    try {
      final res = await http.put(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _cmd = updated;
          _loading = false;
          _montantTotal =
              ((updated['montantTotal'] ?? updated['montant']) as num?)
                      ?.toDouble() ??
                  _montantTotal;
        });
        _showSnack('Statut mis à jour ✓');
      } else {
        setState(() => _loading = false);
        _showSnack('Erreur ${res.statusCode}', isError: true);
      }
    } catch (_) {
      setState(() => _loading = false);
      _showSnack('Connexion impossible', isError: true);
    }
  }

  // ── Assigner un agent ─────────────────────────────────────────────────────
  Future<void> _assignerAgent(int agentId) async {
    final token = await AuthStorage.getToken();
    final id = _cmd['id'];
    try {
      final res = await http.put(
        Uri.parse(
            '${ApiConstants.commandes}/$id/assigner-agent?agentId=$agentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _cmd = jsonDecode(res.body) as Map<String, dynamic>);
        _showSnack('Agent assigné ✓');
      }
    } catch (e) {
      debugPrint('Assign agent error: $e');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _labelStatut(String s) {
    const map = {
      'CREE': 'Créée',
      'CONFIRMEE': 'Confirmée',
      'EN_COURS': 'En cours',
      'ATTENTE_PAIEMENT': 'Attente paiement',
      'CLOTUREE': 'Clôturée',
      'ANNULEE': 'Annulée',
      'LITIGE': 'Litige',
    };
    return map[s] ?? s;
  }

  Color _colorStatut(String s) {
    switch (s) {
      case 'CREE':              return AppColors.primary;
      case 'CONFIRMEE':         return AppColors.purple;
      case 'EN_COURS':          return AppColors.amber;
      case 'ATTENTE_PAIEMENT':  return AppColors.amber;
      case 'CLOTUREE':          return AppColors.green;
      case 'ANNULEE':           return AppColors.red;
      default:                  return AppColors.textSecond;
    }
  }

  // _labelEtapeProgress → déplacé dans CommandeProgressBar.labelEtape()

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _fmt(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return '${buf.toString()} FCFA';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    final ec = _cmd['etapeCourante'] as String?;
    final canAdvance = _prochainStep != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Commande #${_cmd['id']}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Carte progression ──────────────────────────────────────
            _buildProgressCard(statut, ec),
            const SizedBox(height: 16),

            // ── Montant (visible dès CONFIRMEE) ───────────────────────
            if (statut != 'CREE' && statut != 'ANNULEE') ...[
              _buildMontantCard(statut),
              const SizedBox(height: 16),
            ],

            // ── Infos client / commande ────────────────────────────────
            _buildInfoCard(),
            const SizedBox(height: 16),

            // ── Champs personnalisés ───────────────────────────────────
            if (_getChampsCommande().isNotEmpty) ...[
              _buildChampsCard(),
              const SizedBox(height: 16),
            ],

            // ── Agents (si avecAgent) ──────────────────────────────────
            if (_avecAgent) ...[
              _buildAgentsCard(),
              const SizedBox(height: 16),
            ],

            // ── Message attente paiement ───────────────────────────────
            if (statut == 'ATTENTE_PAIEMENT') ...[
              _buildAttenteCard(),
              const SizedBox(height: 16),
            ],

            // ── Bouton action ──────────────────────────────────────────
            if (canAdvance) _buildActionButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Carte progression ──────────────────────────────────────────────────────
  Widget _buildProgressCard(String statut, String? ec) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _colorStatut(statut).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labelStatut(statut),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _colorStatut(statut)),
              ),
            ),
            if (statut == 'EN_COURS' && ec != null) ...[
              const SizedBox(width: 8),
              Text('· ${_cap(ec)}',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w500)),
            ],
          ]),
          if (statut != 'ANNULEE') ...[
            const SizedBox(height: 20),
            _buildEtapesProgress(),
          ],
        ],
      ),
    );
  }

  // ✅ Délègue à CommandeProgressBar (commande_progress_bar.dart)
  Widget _buildEtapesProgress() {
    return CommandeProgressBar(
      fullEtapes   : _fullEtapes,
      currentIndex : _etapeIndex,
      accentColor  : AppColors.amber,   // étape active : ambre
      doneColor    : AppColors.green,   // étapes passées : vert prestataire
    );
  }

  // ── Carte montant ──────────────────────────────────────────────────────────
  Widget _buildMontantCard(String statut) {
    final montant = _montantTotal > 0
        ? _montantTotal
        : ((_cmd['montantTotal'] ?? _cmd['montant']) as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.green.withOpacity(0.08), AppColors.greenLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(Icons.receipt_long_outlined, color: AppColors.green, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Montant de la commande',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.green)),
            Text(
              montant > 0 ? _fmt(montant) : 'En attente du bilan',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.green),
            ),
          ]),
        ),
        if (statut == 'ATTENTE_PAIEMENT')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('En attente',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.amber)),
          ),
      ]),
    );
  }

  // ── Carte attente paiement ─────────────────────────────────────────────────
  Widget _buildAttenteCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.hourglass_top_rounded, color: AppColors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'En attente du paiement client.\nLe client a été notifié.',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textPrimary, height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ── Carte infos client ─────────────────────────────────────────────────────
  Widget _buildInfoCard() {
  return _card(
    title: 'Informations',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(Icons.person_outline, 'Client',
            _cmd['nomClient'] as String? ?? '-'),          // ← était clientNom
        _infoRow(Icons.phone_outlined, 'Téléphone',
            _cmd['telephoneClient'] as String? ?? '-'),    // ← était clientTel
        _infoRow(Icons.location_on_outlined, 'Mode dépôt',
            _cmd['modeDepot'] as String? ?? '-'),          // ← remplace adresse
        if (_cmd['dateCommande'] != null)
          _infoRow(Icons.calendar_today_outlined, 'Date',
              _formatDate(_cmd['dateCommande'].toString())),// ← était dateCreation
      ],
    ),
  );
}

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.textSecond),
          const SizedBox(width: 8),
          Text('$label : ',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecond)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );

  String _formatDate(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return d;
    }
  }

  // ── Champs personnalisés ───────────────────────────────────────────────────
  Map<String, dynamic> _getChampsCommande() {
    final json = _cmd['champsCommandeJson'] as String? ??
        (_cmd['champsCommande'] is String
            ? _cmd['champsCommande'] as String
            : null) ??
        '';
    if (json.isEmpty) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Widget _buildChampsCard() {
    final champs = _getChampsCommande();
    return _card(
      title: 'Détails de la prestation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: champs.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_cap(e.key)} : ',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecond)),
                        Expanded(
                          child: Text('${e.value}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Section agents ─────────────────────────────────────────────────────────
  Widget _buildAgentsCard() {
    final agentAssigneId = _cmd['agentId'] as int?;
    return _card(
      title: 'Agents',
      icon: Icons.people_alt_outlined,
      iconColor: AppColors.red,
      child: _agents.isEmpty
          ? Text('Aucun agent configuré',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecond))
          : Column(
              children: _agents.map((agent) {
                final id = agent['id'] as int?;
                return _buildAgentTile(agent, id == agentAssigneId);
              }).toList()),
    );
  }

  Widget _buildAgentTile(Map<String, dynamic> agent, bool isAssigne) {
    final nom = agent['nom'] as String? ?? 'Agent';
    final prenom = agent['prenom'] as String? ?? '';
    final disponible = agent['disponible'] as bool? ?? true;
    final initiales = '${nom.isNotEmpty ? nom[0] : ''}'
        '${prenom.isNotEmpty ? prenom[0] : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAssigne
            ? AppColors.red.withOpacity(0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isAssigne
                ? AppColors.red.withOpacity(0.3)
                : AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isAssigne
              ? AppColors.red.withOpacity(0.15)
              : AppColors.greenLight,
          child: Text(initiales,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAssigne ? AppColors.red : AppColors.green)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$prenom $nom',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Row(children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: disponible
                              ? AppColors.green
                              : AppColors.textSecond)),
                  const SizedBox(width: 4),
                  Text(disponible ? 'Disponible' : 'Occupé',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: disponible
                              ? AppColors.green
                              : AppColors.textSecond)),
                ]),
              ]),
        ),
        if (isAssigne)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('Assigné',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.red,
                    fontWeight: FontWeight.w600)),
          )
        else if (disponible)
          TextButton(
            onPressed: () => _assignerAgent(agent['id'] as int),
            style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: Text('Assigner',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.green)),
          ),
      ]),
    );
  }

  // ── Bouton action ──────────────────────────────────────────────────────────
  Widget _buildActionButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _avancerStatut,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white),
          label: Text(_labelBoutonAction,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
        ),
      );

  // ── Conteneur carte réutilisable ───────────────────────────────────────────
  Widget _card({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor ?? AppColors.green),
              const SizedBox(width: 8),
            ],
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}



// // lib/features/prestataire/commande_detail_screen.dart   ← NOM CORRIGÉ (c minuscule)
// //
// // ✅ ARCHITECTURE THÈSE : Zéro if(typeService)
// // etapesEffectives = _configEtapes → reçus du parent (depuis la config prestataire)
// // _fullEtapes      = smart : si etapesEffectives contient déjà CREE → liste directe
// //                           sinon → ['CREE','CONFIRMEE', ..._configEtapes, 'CLOTUREE']
// // _etapeIndex      = switch(statut) + indexOf(.toUpperCase()) sur _configEtapes pour EN_COURS
// // _prochainStep    = {statut, etapeCourante?} → null si terminé
// // avecAgent        = arg optionnel (default false) → section agents visible si true
// //
// // COULEURS : AppColors.green (#27500A) pour le prestataire ← CORRIGÉ

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import '../../core/constants/api_constants.dart';
// import '../../core/constants/app_colors.dart';
// import '../../core/services/auth_storage.dart';

// class CommandeDetailScreen extends StatefulWidget {
//   final Map<String, dynamic> commande;

//   /// Couche 2 : étapes dynamiques de la config (ex: ['collecte','traitement','livraison'])
//   final List<String> etapesEffectives;

//   /// Agents disponibles (non vide uniquement si avecAgent=true)
//   final List<Map<String, dynamic>> agents;

//   final int prestataireId;

//   /// Vrai si le prestataire a activé l'option "avec agents"
//   final bool avecAgent;

//   const CommandeDetailScreen({
//     super.key,
//     required this.commande,
//     required this.etapesEffectives,
//     required this.agents,
//     required this.prestataireId,
//     this.avecAgent = false, // ← optionnel, rétrocompatible avec main.dart
//   });

//   @override
//   State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
// }

// class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
//   late Map<String, dynamic> _cmd;
//   late List<String> _configEtapes;
//   late List<Map<String, dynamic>> _agents;
//   late bool _avecAgent;
//   bool _loading = false;

//   /// Couche 1 + Couche 2 fusionnées
//   /// — Nouvelle archi : etapesEffectives contient DÉJÀ CREE/CONFIRMEE/CLOTUREE
//   ///   → on l'utilise tel quel pour éviter les doublons
//   /// — Ancienne archi : etapesEffectives = étapes métier seulement
//   ///   → on entoure avec CREE / CONFIRMEE / CLOTUREE
//   List<String> get _fullEtapes {
//     if (_configEtapes.isEmpty) return ['CREE', 'CONFIRMEE', 'CLOTUREE'];
//     if (_configEtapes.contains('CREE')) return List<String>.from(_configEtapes);
//     return ['CREE', 'CONFIRMEE', ..._configEtapes, 'CLOTUREE'];
//   }

//   @override
//   void initState() {
//     super.initState();
//     _cmd = widget.commande;
//     _configEtapes = widget.etapesEffectives;
//     _agents = widget.agents;
//     // avecAgent passé explicitement OU déduit des agents non vides
//     _avecAgent = widget.avecAgent || widget.agents.isNotEmpty;
//   }

//   // ── Index dans _fullEtapes ─────────────────────────────────────────────
//   int get _etapeIndex {
//     final statut = _cmd['statut'] as String? ?? 'CREE';
//     switch (statut) {
//       case 'CREE':      return 0;
//       case 'CONFIRMEE': return 1;
//       case 'CLOTUREE':  return _fullEtapes.length - 1;
//       case 'ANNULEE':   return -1;
//       case 'EN_COURS':
//         final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase(); // FIX: uppercase pour matcher _configEtapes
//         final idx = _configEtapes.indexOf(ec);
//         return idx >= 0 ? 2 + idx : 2;
//       default: return 0;
//     }
//   }

//   // ── Prochaine transition ───────────────────────────────────────────────
//   Map<String, String?>? get _prochainStep {
//     final statut = _cmd['statut'] as String? ?? 'CREE';
//     switch (statut) {
//       case 'CREE':
//         return {'statut': 'CONFIRMEE', 'etapeCourante': null};
//       case 'CONFIRMEE':
//         if (_configEtapes.isEmpty) return {'statut': 'CLOTUREE', 'etapeCourante': null};
//         return {'statut': 'EN_COURS', 'etapeCourante': _configEtapes.first};
//       case 'EN_COURS':
//         final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase(); // FIX: uppercase
//         final idx = _configEtapes.indexOf(ec);
//         if (idx < 0 || idx == _configEtapes.length - 1) {
//           return {'statut': 'CLOTUREE', 'etapeCourante': null};
//         }
//         return {'statut': 'EN_COURS', 'etapeCourante': _configEtapes[idx + 1]};
//       case 'CLOTUREE':
//       case 'ANNULEE':
//         return null;
//       default: return null;
//     }
//   }

//   String get _labelBoutonAction {
//     final statut = _cmd['statut'] as String? ?? 'CREE';
//     switch (statut) {
//       case 'CREE':      return 'Confirmer la commande';
//       case 'CONFIRMEE': return _configEtapes.isEmpty ? 'Clôturer' : 'Démarrer la prestation';
//       case 'EN_COURS':
//         final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase(); // FIX: uppercase
//         final idx = _configEtapes.indexOf(ec);
//         if (idx >= 0 && idx < _configEtapes.length - 1) {
//           return 'Passer à ${_cap(_configEtapes[idx + 1])}';
//         }
//         return 'Clôturer la commande';
//       default: return '';
//     }
//   }

//   // ── PUT /api/commande/{id}/statut?statut=...&acteurId=...&etapeCourante=... ──
//   Future<void> _avancerStatut() async {
//     final next = _prochainStep;
//     if (next == null) return;
//     setState(() => _loading = true);

//     final token = await AuthStorage.getToken();
//     final id = _cmd['id'];
//     var url =
//         '${ApiConstants.commandes}/$id/statut'
//         '?statut=${next['statut']}'
//         '&acteurId=${widget.prestataireId}';
//     if (next['etapeCourante'] != null) {
//       url += '&etapeCourante=${next['etapeCourante']}';
//     }

//     try {
//       final res = await http.put(
//         Uri.parse(url),
//         headers: {'Authorization': 'Bearer $token'},
//       );
//       if (res.statusCode == 200) {
//         final updated = jsonDecode(res.body) as Map<String, dynamic>;
//         setState(() { _cmd = updated; _loading = false; });
//         _showSnack('Statut mis à jour');
//       } else {
//         setState(() => _loading = false);
//         _showSnack('Erreur ${res.statusCode}', isError: true);
//       }
//     } catch (_) {
//       setState(() => _loading = false);
//       _showSnack('Connexion impossible', isError: true);
//     }
//   }

//   // ── Assigner un agent à la commande ────────────────────────────────────
//   Future<void> _assignerAgent(int agentId) async {
//     final token = await AuthStorage.getToken();
//     final id = _cmd['id'];
//     try {
//       final res = await http.put(
//         Uri.parse('${ApiConstants.commandes}/$id/assigner-agent?agentId=$agentId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );
//       if (res.statusCode == 200) {
//         setState(() => _cmd = jsonDecode(res.body) as Map<String, dynamic>);
//         _showSnack('Agent assigné');
//       }
//     } catch (e) {
//       debugPrint('Assign agent error: $e');
//     }
//   }

//   void _showSnack(String msg, {bool isError = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
//       backgroundColor: isError ? AppColors.red : AppColors.green,
//       behavior: SnackBarBehavior.floating,
//     ));
//   }

//   String _labelStatut(String s) {
//     const map = {
//       'CREE': 'Créée', 'CONFIRMEE': 'Confirmée', 'EN_COURS': 'En cours',
//       'CLOTUREE': 'Clôturée', 'ANNULEE': 'Annulée', 'LITIGE': 'Litige',
//     };
//     return map[s] ?? s;
//   }

//   Color _colorStatut(String s) {
//     switch (s) {
//       case 'CREE':      return AppColors.primary;
//       case 'CONFIRMEE': return AppColors.purple;
//       case 'EN_COURS':  return AppColors.amber;
//       case 'CLOTUREE':  return AppColors.green;
//       case 'ANNULEE':   return AppColors.red;
//       default:          return AppColors.textSecond;
//     }
//   }

//   String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

//   // ════════════════════════════════════════════════════════════════════════
//   //  BUILD
//   // ════════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     final statut = _cmd['statut'] as String? ?? 'CREE';
//     final ec = _cmd['etapeCourante'] as String?;
//     final canAdvance = _prochainStep != null;

//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         title: Text('Commande #${_cmd['id']}',
//             style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           // ── Carte progression ─────────────────────────────────────
//           _buildProgressCard(statut, ec),
//           const SizedBox(height: 16),

//           // ── Infos client / commande ───────────────────────────────
//           _buildInfoCard(),
//           const SizedBox(height: 16),

//           // ── Champs personnalisés (si présents) ────────────────────
//           if (_getChampsCommande().isNotEmpty) ...[
//             _buildChampsCard(),
//             const SizedBox(height: 16),
//           ],

//           // ── Section agents (uniquement si avecAgent=true) ─────────
//           if (_avecAgent) ...[
//             _buildAgentsCard(),
//             const SizedBox(height: 16),
//           ],

//           // ── Bouton action ─────────────────────────────────────────
//           if (canAdvance) _buildActionButton(),
//           const SizedBox(height: 20),
//         ]),
//       ),
//     );
//   }

//   // ── Carte progression ───────────────────────────────────────────────────
//   Widget _buildProgressCard(String statut, String? ec) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         // Badge statut + étape courante
//         Row(children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//             decoration: BoxDecoration(
//               color: _colorStatut(statut).withOpacity(0.1),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Text(_labelStatut(statut),
//                 style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _colorStatut(statut))),
//           ),
//           if (statut == 'EN_COURS' && ec != null) ...[
//             const SizedBox(width: 8),
//             Text('· ${_cap(ec)}',
//                 style: GoogleFonts.poppins(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w500)),
//           ],
//         ]),

//         // Barre de progression (si non annulée)
//         if (statut != 'ANNULEE') ...[
//           const SizedBox(height: 20),
//           _buildEtapesProgress(),
//         ],
//       ]),
//     );
//   }

//   Widget _buildEtapesProgress() {
//     final currentIdx = _etapeIndex;
//     final total = _fullEtapes.length;

//     return Column(children: [
//       // Segments colorés
//       Row(children: List.generate(total, (i) {
//         final done = currentIdx >= 0 && i <= currentIdx;
//         final current = i == currentIdx;
//         return Expanded(
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 1),
//             height: 5,
//             decoration: BoxDecoration(
//               color: done ? (current ? AppColors.amber : AppColors.green) : AppColors.border,
//               borderRadius: BorderRadius.circular(3),
//             ),
//           ),
//         );
//       })),
//       const SizedBox(height: 8),
//       // Labels sous les segments
//       Row(children: _fullEtapes.asMap().entries.map((e) {
//         final i = e.key;
//         final done = currentIdx >= 0 && i <= currentIdx;
//         final current = i == currentIdx;
//         final label = e.value == 'CREE' ? 'Créée'
//             : e.value == 'CONFIRMEE' ? 'Confirmée'
//             : e.value == 'CLOTUREE' ? 'Clôturée'
//             : _cap(e.value);
//         return Expanded(
//           child: Text(label,
//             style: GoogleFonts.poppins(
//               fontSize: 9,
//               color: done ? (current ? AppColors.amber : AppColors.green) : AppColors.textSecond,
//               fontWeight: current ? FontWeight.w600 : FontWeight.w400,
//             ),
//             textAlign: i == 0 ? TextAlign.left : i == total - 1 ? TextAlign.right : TextAlign.center,
//             overflow: TextOverflow.ellipsis,
//           ),
//         );
//       }).toList()),
//     ]);
//   }

//   // ── Carte infos client ──────────────────────────────────────────────────
//   Widget _buildInfoCard() {
//     return _card(
//       title: 'Informations',
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         _infoRow(Icons.person_outline,       'Client',    _cmd['clientNom'] as String? ?? '-'),
//         _infoRow(Icons.phone_outlined,       'Téléphone', _cmd['clientTel'] as String? ?? '-'),
//         _infoRow(Icons.location_on_outlined, 'Adresse',   _cmd['adresse']   as String? ?? '-'),
//         if (_cmd['dateCreation'] != null)
//           _infoRow(Icons.calendar_today_outlined, 'Date', _formatDate(_cmd['dateCreation'] as String)),
//       ]),
//     );
//   }

//   Widget _infoRow(IconData icon, String label, String value) => Padding(
//     padding: const EdgeInsets.only(bottom: 8),
//     child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Icon(icon, size: 16, color: AppColors.textSecond),
//       const SizedBox(width: 8),
//       Text('$label : ', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecond)),
//       Expanded(child: Text(value,
//           style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
//     ]),
//   );

//   String _formatDate(String d) {
//     try {
//       final dt = DateTime.parse(d);
//       return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
//     } catch (_) { return d; }
//   }

//   // ── Champs personnalisés ────────────────────────────────────────────────
//   Map<String, dynamic> _getChampsCommande() {
//     final json = _cmd['champsCommandeJson'] as String?
//         ?? (_cmd['champsCommande'] is String ? _cmd['champsCommande'] as String : null)
//         ?? '';
//     if (json.isEmpty) return {};
//     try { return jsonDecode(json) as Map<String, dynamic>; } catch (_) { return {}; }
//   }

//   Widget _buildChampsCard() {
//     final champs = _getChampsCommande();
//     return _card(
//       title: 'Détails de la prestation',
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start,
//         children: champs.entries.map((e) => Padding(
//           padding: const EdgeInsets.only(bottom: 8),
//           child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             Text('${_cap(e.key)} : ',
//                 style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecond)),
//             Expanded(child: Text('${e.value}',
//                 style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
//           ]),
//         )).toList(),
//       ),
//     );
//   }

//   // ── Section agents (visible uniquement si _avecAgent=true) ─────────────
//   Widget _buildAgentsCard() {
//     final agentAssigneId = _cmd['agentId'] as int?;
//     return _card(
//       title: 'Agents',
//       icon: Icons.people_alt_outlined,
//       iconColor: AppColors.red,
//       child: _agents.isEmpty
//           ? Text('Aucun agent configuré',
//               style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecond))
//           : Column(children: _agents.map((agent) {
//               final id = agent['id'] as int?;
//               return _buildAgentTile(agent, id == agentAssigneId);
//             }).toList()),
//     );
//   }

//   Widget _buildAgentTile(Map<String, dynamic> agent, bool isAssigne) {
//     final nom = agent['nom'] as String? ?? 'Agent';
//     final prenom = agent['prenom'] as String? ?? '';
//     final disponible = agent['disponible'] as bool? ?? true;
//     final initiales = '${nom.isNotEmpty ? nom[0] : ''}${prenom.isNotEmpty ? prenom[0] : ''}';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: isAssigne ? AppColors.red.withOpacity(0.07) : AppColors.background,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: isAssigne ? AppColors.red.withOpacity(0.3) : AppColors.border),
//       ),
//       child: Row(children: [
//         // Avatar
//         CircleAvatar(
//           radius: 18,
//           backgroundColor: isAssigne ? AppColors.red.withOpacity(0.15) : AppColors.greenLight,
//           child: Text(initiales,
//               style: GoogleFonts.poppins(
//                 fontSize: 12, fontWeight: FontWeight.w600,
//                 color: isAssigne ? AppColors.red : AppColors.green,
//               )),
//         ),
//         const SizedBox(width: 10),
//         // Nom + disponibilité
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('$prenom $nom',
//               style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
//           Row(children: [
//             Container(width: 6, height: 6,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: disponible ? AppColors.green : AppColors.textSecond,
//                 )),
//             const SizedBox(width: 4),
//             Text(disponible ? 'Disponible' : 'Occupé',
//                 style: GoogleFonts.poppins(fontSize: 11,
//                     color: disponible ? AppColors.green : AppColors.textSecond)),
//           ]),
//         ])),
//         // Badge assigné ou bouton
//         if (isAssigne)
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//             decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
//             child: Text('Assigné', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.red, fontWeight: FontWeight.w600)),
//           )
//         else if (disponible)
//           TextButton(
//             onPressed: () => _assignerAgent(agent['id'] as int),
//             style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
//             child: Text('Assigner', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.green)),
//           ),
//       ]),
//     );
//   }

//   // ── Bouton action principal ─────────────────────────────────────────────
//   Widget _buildActionButton() => SizedBox(
//     width: double.infinity,
//     child: ElevatedButton.icon(
//       onPressed: _loading ? null : _avancerStatut,
//       icon: _loading
//           ? const SizedBox(width: 18, height: 18,
//               child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//           : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
//       label: Text(_labelBoutonAction,
//           style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.green,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         elevation: 0,
//       ),
//     ),
//   );

//   // ── Widget conteneur carte réutilisable ─────────────────────────────────
//   Widget _card({
//     required String title,
//     required Widget child,
//     IconData? icon,
//     Color? iconColor,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Row(children: [
//           if (icon != null) ...[
//             Icon(icon, size: 18, color: iconColor ?? AppColors.green),
//             const SizedBox(width: 8),
//           ],
//           Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
//         ]),
//         const SizedBox(height: 12),
//         child,
//       ]),
//     );
//   }
// }








// //############################################

