// lib/features/client/client_detail_commande_screen.dart
//
// Écran détail commande CLIENT — correspond à la maquette "Commande #042"
//
// Architecture 2 couches :
//   Couche 1 (modèle de référence) : statuts universels dans cmd['statut']
//   Couche 2 (métamodèle)          : étapes dans cmd['etapesEffectives']
//       ex: ["CREE","CONFIRMEE","EN_COLLECTE","EN_TRAITEMENT","EN_LIVRAISON","CLOTUREE"]
//
// Barre de progression :
//   • étape passée  → cercle vert  ✓
//   • étape active  → cercle orange avec index (0-based)
//   • étape future  → cercle gris vide
//
// NabooPay : bouton "Payer" affiché quand statut == TRAITEMENT_TERMINE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

// ── Fallback minimal si etapesEffectives absent de l'API ────────────────────
// À supprimer dès que ConfigPrestataireService.toDTO() retourne etapesEffectives
const List<String> _etapesFallback = [
  'CREE', 'CONFIRMEE', 'CLOTUREE',
];

// ── Labels courts pour la barre de progression ───────────────────────────────
const Map<String, String> _labelsEtapes = {
  'CREE':                  'Créée',
  'CONFIRMEE':             'Confirmée',
  'EN_COLLECTE':           'Collecte',
  'EN_TRAITEMENT':         'Traitement',
  'EN_LIVRAISON':          'Livraison',
  'CLOTUREE':              'Clôturée',
  'DIAGNOSTIC':            'Diagnostic',
  'DEVIS_ENVOYE':          'Devis',
  'EN_REPARATION':         'Réparation',
  'REPARATION_TERMINEE':   'Réparé',
  'PLANIFIEE':             'Planifiée',
  'EN_INTERVENTION':       'Intervention',
  'INTERVENTION_TERMINEE': 'Terminée',
  'TRAITEMENT_TERMINE':    'À payer',
  'ANNULEE':               'Annulée',
  'LITIGE':                'Litige',
};

class ClientDetailCommandeScreen extends StatefulWidget {
  // Reçoit UNIQUEMENT l'ID — charge ses propres données fraîches depuis l'API
  // Ainsi, etapesEffectives, statut à jour, et tous les champs complets
  // sont garantis, même si la liste n'avait qu'un snapshot partiel
  final int commandeId;

  const ClientDetailCommandeScreen({
    super.key,
    required this.commandeId,
  });

  @override
  State<ClientDetailCommandeScreen> createState() =>
      _ClientDetailCommandeScreenState();
}

class _ClientDetailCommandeScreenState
    extends State<ClientDetailCommandeScreen> {

  Map<String, dynamic> _cmd = {};
  bool _loading = true;   // true au premier chargement

  @override
  void initState() {
    super.initState();
    _loadCommande(); // charge immédiatement depuis l'API
  }

  // ── Chargement initial (et refresh) depuis l'API ─────────────────────────
  Future<void> _loadCommande({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final token = await AuthStorage.getToken();
      if (token == null) return;
      final r = await http.get(
        Uri.parse('${ApiConstants.commandes}/${widget.commandeId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        setState(() => _cmd = jsonDecode(r.body));
      }
    } catch (e) {
      debugPrint("Chargement commande détail : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Alias pour le pull-to-refresh ────────────────────────────────────────
  Future<void> _refresh() => _loadCommande(silent: true);

  // ── Étapes effectives ────────────────────────────────────────────────────
  List<String> get _etapes {
    // Couche 2 : etapesEffectives retourné par l'API (ConfigPrestataireService)
    if (_cmd['etapesEffectives'] != null) {
      try {
        final raw = _cmd['etapesEffectives'];
        if (raw is List) return List<String>.from(raw);
        // Si l'API retourne une String JSON
        return List<String>.from(jsonDecode(raw as String) as List);
      } catch (_) {}
    }
    // Fallback minimal — à retirer dès que le backend retourne etapesEffectives
    return _etapesFallback;
  }

  String get _statut => _cmd['statut'] as String? ?? '';

  int get _currentIdx {
    final idx = _etapes.indexOf(_statut);
    if (idx >= 0) return idx;
    // Étape hors liste (ex: TRAITEMENT_TERMINE) → après CLOTUREE-1
    return _etapes.length;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Pendant le chargement initial → spinner centré
    if (_loading && _cmd.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Commande #${widget.commandeId.toString().padLeft(3, '0')}",
            style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w700)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final id       = _cmd['id'] as int? ?? widget.commandeId;
    final nomPrest = _cmd['nomPrestataire'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Commande #${id.toString().padLeft(3, '0')}",
          style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 16,
            fontWeight: FontWeight.w700)),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refresh,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Statut + Prestataire ──────────────────────────────────
              _buildStatutRow(nomPrest),
              const SizedBox(height: 14),

              // ── Barre de progression ──────────────────────────────────
              _buildProgressBar(),
              const SizedBox(height: 14),

              // ── Agent (si présent) ────────────────────────────────────
              if (_cmd['avecAgent'] == true &&
                  _cmd['nomAgentCollecte'] != null) ...[
                _buildAgentCard(),
                const SizedBox(height: 14),
              ],

              // ── Détail commande ───────────────────────────────────────
              _buildDetailCard(),
              const SizedBox(height: 14),

              // ── Zone d'action client ──────────────────────────────────
              _buildActionZone(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Statut + Prestataire ───────────────────────────────────────────────────
  Widget _buildStatutRow(String nomPrest) {
    final cfg = _getStatutBadge(_statut);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cfg['color'] as Color,
            borderRadius: BorderRadius.circular(20)),
          child: Text(cfg['label'] as String,
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Colors.white)),
        ),
        const Spacer(),
        Text(nomPrest,
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary)),
      ],
    );
  }

  // ── Barre de progression ───────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final etapes = _etapes;
    final cur    = _currentIdx;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(etapes.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Tiret connecteur
              final stepIdx = (i - 1) ~/ 2;
              final done    = stepIdx < cur;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  width: 24, height: 2,
                  margin: const EdgeInsets.only(top: 15),
                  color: done ? AppColors.green : AppColors.border,
                ),
              );
            }

            final stepIdx = i ~/ 2;
            final label   = _labelsEtapes[etapes[stepIdx]] ??
                            etapes[stepIdx].replaceAll('_', ' ');
            final isDone  = stepIdx < cur;
            final isCur   = stepIdx == cur;

            return Column(
              children: [
                // Cercle
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.green
                        : isCur
                            ? const Color(0xFFF97316)   // orange
                            : AppColors.border,
                    border: isCur
                        ? Border.all(
                            color: const Color(0xFFF97316), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : isCur
                            ? Text("$stepIdx",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700))
                            : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 6),
                // Label
                SizedBox(
                  width: 60,
                  child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: isCur
                          ? FontWeight.w700 : FontWeight.w400,
                      color: isDone
                          ? AppColors.green
                          : isCur
                              ? const Color(0xFFF97316)
                              : AppColors.textMuted)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Agent de collecte ──────────────────────────────────────────────────────
  Widget _buildAgentCard() {
    final nom    = _cmd['nomAgentCollecte']       as String? ?? '';
    final note   = _cmd['noteAgent']              as double? ?? 0.0;
    final tel    = _cmd['telephoneAgentCollecte'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          // Avatar initiale
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(
                nom.isNotEmpty ? nom[0].toUpperCase() : 'A',
                style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                  style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                Row(children: [
                  Text("Agent de collecte",
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecond)),
                  if (note > 0) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: Colors.amber, size: 13),
                    Text(" ${note.toStringAsFixed(1)}",
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecond)),
                  ],
                ]),
              ],
            ),
          ),

          // Bouton appel
          if (tel.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:$tel')),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ── Détail commande ────────────────────────────────────────────────────────
  Widget _buildDetailCard() {
    final lignes      = _cmd['lignes']       as List? ?? [];
    final montant     = (_cmd['montantTotal'] as num?)?.toInt() ?? 0;
    final modeDepot   = _cmd['modeDépôt']    as String? ?? '';
    final dateCmd     = _cmd['dateCommande'] as String? ?? '';

    String _modeDepotLabel(String mode) {
      switch (mode.toUpperCase()) {
        case 'COLLECTE_DOMICILE': return 'Collecte domicile';
        case 'DEPOT_BOUTIQUE':    return 'Dépôt boutique';
        default:                  return mode.isNotEmpty ? mode : '—';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Détail commande",
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          // Lignes prestations
          ...lignes.map((ligne) {
            final type = ligne['typePrestation'] as String? ?? '';
            final qte  = (ligne['quantite']     as num?)?.toInt() ?? 0;
            final mont = (ligne['montantLigne']  as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text("$type × $qte",
                      style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecond)),
                  ),
                  Text("${_fmt(mont)} FCFA",
                    style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                ],
              ),
            );
          }),

          // Mode dépôt
          if (modeDepot.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Mode dépôt",
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond)),
                Text(_modeDepotLabel(modeDepot),
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 16, color: AppColors.border),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total",
                style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              Text("${_fmt(montant)} FCFA",
                style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
            ],
          ),

          // Date
          if (dateCmd.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(dateCmd,
                  style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Zone d'action ──────────────────────────────────────────────────────────
  Widget _buildActionZone() {
    final id      = _cmd['id']            as int?    ?? 0;
    final montant = (_cmd['montantTotal'] as num?)?.toInt() ?? 0;

    switch (_statut) {

      // Statuts universels (couche 1)
      case 'CREE':
        return Column(
          children: [
            _infoBox(AppColors.primaryLight, AppColors.primary,
              Icons.hourglass_empty,
              "En attente de confirmation du prestataire..."),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => _annulerCommande(id),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text("Annuler la commande",
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );

      case 'CONFIRMEE':
        return _infoBox(AppColors.greenLight, AppColors.green,
          Icons.check_circle_outline,
          "Commande confirmée par le prestataire ✅");

      case 'EN_TRAITEMENT':
        return _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316),
          Icons.settings_outlined,
          "Votre commande est en cours de traitement ⚙️");

      case 'TRAITEMENT_TERMINE':
        return _buildNabooPayButton(id, montant);

      case 'CLOTUREE':
        return _infoBox(AppColors.greenLight, AppColors.green,
          Icons.check_circle, "Commande clôturée ✅ Merci de votre confiance !");

      case 'ANNULEE':
        return _infoBox(const Color(0xFFFCEBEB), Colors.red,
          Icons.cancel_outlined, "Commande annulée");

      case 'LITIGE':
        return _infoBox(const Color(0xFFFFF3E0), Colors.orange,
          Icons.warning_amber, "⚠️ Litige en cours de traitement");

      // Étapes métamodèle (couche 2)
      case 'EN_COLLECTE':
        return _infoBox(AppColors.primaryLight, AppColors.primary,
          Icons.delivery_dining,
          "🛵 L'agent de collecte est en route...");

      case 'EN_VERIFICATION':
        return _buildVerifPrixAction(id, montant);

      case 'EN_LIVRAISON':
        return _infoBox(AppColors.primaryLight, AppColors.primary,
          Icons.local_shipping_outlined,
          "📦 Votre commande est en livraison");

      case 'VERIFICATION_FINALE':
        return _buildVerifFinaleAction(id);

      case 'DIAGNOSTIC':
        return _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316),
          Icons.search_outlined,
          "🔍 Diagnostic de votre appareil en cours...");

      case 'DEVIS_ENVOYE':
        return _buildDevisAction(id, montant);

      case 'EN_REPARATION':
        return _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316),
          Icons.handyman_outlined,
          "🔧 Réparation en cours, nous vous tenons informé...");

      case 'REPARATION_TERMINEE':
        return _infoBox(AppColors.greenLight, AppColors.green,
          Icons.check_circle_outline,
          "✅ Réparation terminée — en cours de livraison");

      case 'PLANIFIEE':
        return _infoBox(AppColors.primaryLight, AppColors.primary,
          Icons.calendar_today_outlined,
          "📅 Votre intervention est planifiée");

      case 'EN_INTERVENTION':
        return _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316),
          Icons.handshake_rounded,
          "🏠 Intervention en cours à votre domicile");

      case 'INTERVENTION_TERMINEE':
        return _buildVerifFinaleAction(id);

      // ── Générique — étape dynamique inconnue ───────────────────────────
      default:
        if (_statut.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            _infoBox(const Color(0xFFFFF3E0),
              const Color(0xFFF97316),
              Icons.update_outlined,
              "Étape en cours : ${_labelEtape(_statut)}"),
            const SizedBox(height: 8),
            // Pas de bouton annuler (statut > CREE)
            _infoBox(const Color(0xFFFCEBEB), Colors.red,
              Icons.info_outline,
              "Pour annuler, la commande doit être en statut CREE"),
          ],
        );
    }
  }

  // ── Sous-actions ───────────────────────────────────────────────────────────
  Widget _buildNabooPayButton(int id, int montant) {
    return Column(
      children: [
        _infoBox(AppColors.primaryLight, AppColors.primary,
          Icons.check_circle_outline,
          "✅ Traitement terminé ! Procédez au paiement pour clôturer."),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
            onPressed: () =>
                _showNabooPayDialog(id, montant, _cmd),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: "Payer ${_fmt(montant)} FCFA via ",
                  style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Colors.white)),
                TextSpan(
                  text: "Naboo",
                  style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: const Color(0xFFFBBF24))),
                TextSpan(
                  text: "Pay",
                  style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifPrixAction(int id, int montant) {
    final prixFixe   = montant > 0;
    final dejAccepte = _cmd['prixAccepteClient'] == true;
    if (dejAccepte || !prixFixe) {
      return _infoBox(const Color(0xFFFFF3E0),
        const Color(0xFFF97316), Icons.info_outline,
        prixFixe
          ? "🔍 Vérification en cours..."
          : "⏳ Le prestataire vérifie vos articles");
    }
    return Column(
      children: [
        _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316), Icons.info_outline,
          "💰 Prix réel : ${_fmt(montant)} FCFA — Confirmez-vous ?"),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _accepterPrix(id, 'REFUSER'),
              icon: const Icon(Icons.close, size: 14),
              label: Text("Refuser",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _accepterPrix(id, 'ACCEPTER'),
              icon: const Icon(Icons.check, size: 14),
              label: Text("✅ Accepter",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildVerifFinaleAction(int id) {
    return Column(
      children: [
        _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316), Icons.info_outline,
          "Vérifiez bien tout avant de confirmer la réception !"),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _showLitigeDialog(id),
              icon: const Icon(Icons.warning_amber, size: 16),
              label: Text("⚠️ Signaler",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _confirmerReception(id),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text("✅ Tout est bon !",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildDevisAction(int id, int montant) {
    return Column(
      children: [
        _infoBox(const Color(0xFFFFF3E0),
          const Color(0xFFF97316), Icons.description_outlined,
          "📋 Devis reçu : ${_fmt(montant)} FCFA — Acceptez-vous ?"),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _accepterPrix(id, 'REFUSER'),
              child: Text("Refuser",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => _accepterPrix(id, 'ACCEPTER'),
              child: Text("✅ Accepter le devis",
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NABOOPAY DIALOG
  // ════════════════════════════════════════════════════════════════════════════
  void _showNabooPayDialog(
      int commandeId, int montant, Map<String, dynamic> cmd) {
    final numCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          bool pinVisible = false;
          bool paying     = false;

          final lignes = cmd['lignes'] as List? ?? [];
          final nomP   = cmd['nomPrestataire'] as String? ?? '';
          final typeS  = cmd['typeService']    as String? ?? '';

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Titre
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.payment_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text("Paiement",
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 16),

                  // Récapitulatif
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("RÉCAPITULATIF",
                          style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(typeS,
                              style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textSecond)),
                            Text(nomP,
                              style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...lignes.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${l['typePrestation']} "
                                "× ${(l['quantite'] as num).toInt()}",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecond)),
                              Text(
                                "${_fmt((l['montantLigne'] as num?)?.toInt() ?? 0)} FCFA",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecond)),
                            ],
                          ),
                        )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total",
                              style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                            Text("${_fmt(montant)} FCFA",
                              style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Branding NabooPay
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      RichText(text: TextSpan(children: [
                        TextSpan(text: "Naboo",
                          style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: const Color(0xFFF97316))),
                        TextSpan(text: "Pay",
                          style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: AppColors.green)),
                      ])),
                      const SizedBox(height: 4),
                      Text("Paiement mobile sécurisé au Sénégal",
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecond)),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // 3 étapes
                  Row(children: [
                    _nabooStep(1, "Entrez votre\nnuméro"),
                    _nabooStep(2, "Confirmez sur\nvotre téléphone"),
                    _nabooStep(3, "Paiement\nvalidé ✓"),
                  ]),
                  const SizedBox(height: 16),

                  // Numéro
                  TextField(
                    controller: numCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: "Numéro NabooPay",
                      hintText: "77 XXX XX XX",
                      labelStyle: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecond),
                      prefixIcon: const Icon(
                          Icons.phone_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // PIN
                  StatefulBuilder(
                    builder: (_, setPin) => TextField(
                      controller: pinCtrl,
                      obscureText: !pinVisible,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 18, letterSpacing: 6),
                      decoration: InputDecoration(
                        labelText: "Code PIN",
                        labelStyle: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecond),
                        prefixIcon: const Icon(
                            Icons.lock_outline, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            pinVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted, size: 18),
                          onPressed: () =>
                              setPin(() => pinVisible = !pinVisible),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bouton Payer
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: StatefulBuilder(
                      builder: (_, setPay) => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0),
                        onPressed: paying
                            ? null
                            : () async {
                                if (numCtrl.text.isEmpty ||
                                    pinCtrl.text.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Renseignez le numéro et le PIN",
                                        style: GoogleFonts.poppins(fontSize: 12)),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                setPay(() => paying = true);
                                await _processNabooPay(
                                  ctx, commandeId, montant,
                                  numCtrl.text.trim(), pinCtrl.text.trim(),
                                );
                                setPay(() => paying = false);
                              },
                        child: paying
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                    text: "Payer ${_fmt(montant)} FCFA via ",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                                  TextSpan(text: "Naboo",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w800,
                                      color: const Color(0xFFFBBF24))),
                                  TextSpan(text: "Pay",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14, fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                                ]),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      "🔒 Paiement sécurisé · Transaction chiffrée",
                      style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nabooStep(int n, String label) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: Center(
            child: Text("$n",
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10, color: AppColors.textSecond)),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APPELS API (JWT token préservé)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _processNabooPay(BuildContext ctx, int id,
      int montant, String numero, String pin) async {
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();
      if (token == null || userId == null) return;

      final r = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/paiement/nabbopay'
            '/commande/$id?montant=$montant&acteurId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'numeroNabooPay': numero, 'codePin': pin}),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        Navigator.pop(ctx);
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Paiement NabooPay enregistré !",
            style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ Paiement refusé (${r.statusCode})",
            style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint("NabooPay : $e");
    }
  }

  Future<void> _annulerCommande(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Annuler la commande ?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text("Cette action est irréversible.",
          style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Non",
              style: GoogleFonts.poppins(color: AppColors.textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Oui, annuler",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;

    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    if (token == null || userId == null) return;

    final r = await http.put(
      Uri.parse('${ApiConstants.commandes}/$id/statut'
          '?statut=ANNULEE&acteurId=$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 200) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Commande annulée.",
            style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _confirmerReception(int id) async {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    if (token == null || userId == null) return;
    final r = await http.put(
      Uri.parse('${ApiConstants.commandes}/$id/statut'
          '?statut=CLOTUREE&acteurId=$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 200) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Réception confirmée !",
            style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _accepterPrix(int id, String decision) async {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    if (token == null || userId == null) return;
    await http.put(
      Uri.parse('${ApiConstants.commandes}/$id/accepter-prix'
          '?decision=$decision&acteurId=$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _refresh();
  }

  void _showLitigeDialog(int id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Signaler un problème",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Décrivez le problème...",
            hintStyle: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textMuted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
              style: GoogleFonts.poppins(color: AppColors.textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              final token  = await AuthStorage.getToken();
              final userId = await AuthStorage.getUserId();
              if (token == null || userId == null) return;
              await http.put(
                Uri.parse('${ApiConstants.commandes}/$id/statut'
                    '?statut=LITIGE&acteurId=$userId'),
                headers: {'Authorization': 'Bearer $token'},
              );
              _refresh();
            },
            child: Text("Ouvrir un litige",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════
  // ── Badge statut : Couche 1 uniquement hardcodée ─────────────────────────
  // Couche 2 (étapes métier libres) → auto-formaté + orange "en cours"
  // Si le prestataire invente "EN_DEPOSE_ATELIER" → badge "En depose atelier 🔄"
  Map<String, dynamic> _getStatutBadge(String statut) {
    switch (statut) {
      // ── Couche 1 universels ─────────────────────
      case 'CREE':
        return {'label': 'En attente',  'color': AppColors.primary};
      case 'CONFIRMEE':
        return {'label': 'Confirmée',   'color': AppColors.green};
      case 'TRAITEMENT_TERMINE':
        return {'label': '💳 À payer',  'color': AppColors.primary};
      case 'CLOTUREE':
        return {'label': 'Clôturée ✅', 'color': AppColors.green};
      case 'ANNULEE':
        return {'label': 'Annulée',     'color': Colors.red};
      case 'LITIGE':
        return {'label': '⚠️ Litige',  'color': Colors.orange};
      // ── Couche 2 : formatage automatique ────────
      // Aucun cas hardcodé → générique pour tout prestataire
      default:
        return {
          'label': _labelEtape(statut), // "EN_COLLECTE" → "En collecte"
          'color': const Color(0xFFF97316), // orange = travail en cours
        };
    }
  }

  Widget _infoBox(Color bg, Color fg, IconData icon, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: fg, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
            style: GoogleFonts.poppins(fontSize: 11, color: fg))),
      ]),
    );
  }

  String _labelEtape(String s) =>
    s.replaceAll('_', ' ').toLowerCase()
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');

  /// Formatte un entier avec espace milliers : 3500 → "3 500"
  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final rem = s.length % 3;
    buf.write(s.substring(0, rem == 0 ? 3 : rem));
    for (var i = rem == 0 ? 3 : rem; i < s.length; i += 3) {
      buf.write(' ');   // espace insécable
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }

  void launchUrl(Uri parse) {}
}