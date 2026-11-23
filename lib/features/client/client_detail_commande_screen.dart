// lib/features/client/client_detail_commande_screen.dart
//
// ✅ ARCHITECTURE THÈSE : Zero if(typeService), openEHR deux couches
// COUCHE 1 : CREE, CONFIRMEE, EN_COURS, ATTENTE_PAIEMENT, CLOTUREE, ANNULEE, LITIGE
// COUCHE 2 : étapes OPAQUES dans etapesEffectives + etapeCourante (prestataire-defined)
// EN_COURS + etapeCourante = position dans les étapes Couche 2
// ATTENTE_PAIEMENT = client paie via PaiementBottomSheet

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import '../commande/paiement_bottom_sheet.dart';

// ── Fallback si etapesEffectives absent ──────────────────────────────────────
const List<String> _etapesFallback = [
  'CREE', 'CONFIRMEE', 'ATTENTE_PAIEMENT', 'CLOTUREE',
];

// ── Labels Couche 1 uniquement — Couche 2 formatée par _labelEtape() ─────────
const Map<String, String> _labelsEtapes = {
  'CREE':             'Créée',
  'CONFIRMEE':        'Confirmée',
  'EN_COURS':         'En cours',
  'ATTENTE_PAIEMENT': 'Paiement',
  'CLOTUREE':         'Clôturée',
  'ANNULEE':          'Annulée',
  'LITIGE':           'Litige',
};

class ClientDetailCommandeScreen extends StatefulWidget {
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommande();
  }

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

  Future<void> _refresh() => _loadCommande(silent: true);

  // ── Couche 1 universels ──────────────────────────────────────────────────
  static const Set<String> _couche1 = {
    'CREE', 'CONFIRMEE', 'EN_COURS', 'ATTENTE_PAIEMENT',
    'CLOTUREE', 'ANNULEE', 'LITIGE',
  };

  // ── Étapes Couche 2 seulement (opaques, depuis la commande) ─────────────
  List<String> get _etapes2 {
    if (_cmd['etapesEffectives'] != null) {
      try {
        final raw = _cmd['etapesEffectives'];
        final all = raw is List
            ? List<String>.from(raw)
            : List<String>.from(jsonDecode(raw as String) as List);
        return all.where((s) => !_couche1.contains(s)).toList();
      } catch (_) {}
    }
    return [];
  }

  // ── Toutes les étapes pour la barre de progression ───────────────────────
  List<String> get _etapes {
    final etapes2 = _etapes2;
    if (etapes2.isEmpty) return _etapesFallback;
    return ['CREE', 'CONFIRMEE', ...etapes2, 'ATTENTE_PAIEMENT', 'CLOTUREE'];
  }

  String get _statut => _cmd['statut'] as String? ?? '';

  // ── Index dans la barre de progression (openEHR deux couches) ───────────
  int get _currentIdx {
    switch (_statut) {
      case 'CREE': return 0;
      case 'CONFIRMEE': return 1;
      case 'EN_COURS':
        final ec = (_cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = _etapes2.indexOf(ec);
        return idx >= 0 ? 2 + idx : 2;
      case 'ATTENTE_PAIEMENT': return 2 + _etapes2.length;
      case 'CLOTUREE': return 3 + _etapes2.length;
      case 'ANNULEE': return -1;
      default: return 0;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
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
              child: SizedBox(width: 20, height: 20,
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
              _buildStatutRow(nomPrest),
              const SizedBox(height: 14),
              _buildProgressBar(),
              const SizedBox(height: 14),
              if (_cmd['avecAgent'] == true &&
                  _cmd['nomAgentCollecte'] != null) ...[
                _buildAgentCard(),
                const SizedBox(height: 14),
              ],
              _buildDetailCard(),
              const SizedBox(height: 14),
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
    return Row(children: [
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
    ]);
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
              final stepIdx = (i - 1) ~/ 2;
              final done    = cur >= 0 && stepIdx < cur;
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
            // Label : Couche 1 → map, Couche 2 → formatage automatique
            final label   = _labelsEtapes[etapes[stepIdx]] ??
                            _labelEtape(etapes[stepIdx]);
            final isDone  = cur >= 0 && stepIdx < cur;
            final isCur   = cur >= 0 && stepIdx == cur;

            return Column(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.green
                      : isCur ? const Color(0xFFF97316) : AppColors.border,
                  border: isCur
                      ? Border.all(color: const Color(0xFFF97316), width: 2)
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : isCur
                          ? Text("$stepIdx",
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w700))
                          : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: Text(label,
                    textAlign: TextAlign.center, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: isCur ? FontWeight.w700 : FontWeight.w400,
                        color: isDone
                            ? AppColors.green
                            : isCur
                                ? const Color(0xFFF97316)
                                : AppColors.textMuted)),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  // ── Agent ──────────────────────────────────────────────────────────────────
  Widget _buildAgentCard() {
    final nom  = _cmd['nomAgentCollecte']       as String? ?? '';
    final note = _cmd['noteAgent']              as double? ?? 0.0;
    final tel  = _cmd['telephoneAgentCollecte'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(
              nom.isNotEmpty ? nom[0].toUpperCase() : 'A',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nom, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          Row(children: [
            Text("Agent de collecte", style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecond)),
            if (note > 0) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, color: Colors.amber, size: 13),
              Text(" ${note.toStringAsFixed(1)}", style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textSecond)),
            ],
          ]),
        ])),
        if (tel.isNotEmpty)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone, color: Colors.white, size: 20),
          ),
      ]),
    );
  }

  // ── Détail commande ────────────────────────────────────────────────────────
  Widget _buildDetailCard() {
    final lignes  = _cmd['lignes']       as List? ?? [];
    final montant = (_cmd['montantTotal'] as num?)?.toInt() ?? 0;
    final modeDepot = _cmd['modeDépôt']  as String? ?? '';
    final dateCmd = _cmd['dateCommande'] as String? ?? '';

    String modeDepotLabel(String mode) {
      switch (mode.toUpperCase()) {
        case 'COLLECTE_DOMICILE': return 'Collecte domicile';
        case 'DEPOT_BOUTIQUE':    return 'Dépôt boutique';
        default: return mode.isNotEmpty ? mode : '—';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Détail commande", style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...lignes.map((ligne) {
          final type = ligne['typePrestation'] as String? ?? '';
          final qte  = (ligne['quantite']     as num?)?.toInt() ?? 0;
          final mont = (ligne['montantLigne']  as num?)?.toInt() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("$type × $qte",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecond))),
                Text("${_fmt(mont)} FCFA", style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              ],
            ),
          );
        }),
        if (modeDepot.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Mode dépôt", style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecond)),
            Text(modeDepotLabel(modeDepot), style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 8),
        ],
        const Divider(height: 16, color: AppColors.border),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Total", style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          Text("${_fmt(montant)} FCFA", style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: AppColors.primary)),
        ]),
        if (dateCmd.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(dateCmd, style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textMuted)),
          ]),
        ],
      ]),
    );
  }

  // ── Zone d'action ──────────────────────────────────────────────────────────
  // ✅ Couche 1 uniquement — ZERO noms Couche 2 hardcodés
  Widget _buildActionZone() {
    final id      = _cmd['id']            as int?    ?? 0;
    final montant = (_cmd['montantTotal'] as num?)?.toInt() ?? 0;
    final devisEnAttente = _cmd['devisEnAttente'] == true;

    switch (_statut) {

      case 'CREE':
        return Column(children: [
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
        ]);

      case 'CONFIRMEE':
        return _infoBox(AppColors.greenLight, AppColors.green,
            Icons.check_circle_outline,
            "Commande confirmée par le prestataire ✅");

      case 'EN_COURS':
        // Devis en attente → client doit accepter ou refuser
        if (devisEnAttente) return _buildDevisAction(id, montant);
        // Étape Couche 2 en cours → affichage générique (OPAQUE)
        final etapeCourante = (_cmd['etapeCourante'] as String? ?? '');
        final labelEtape = etapeCourante.isNotEmpty
            ? etapeCourante[0].toUpperCase() +
              etapeCourante.substring(1).toLowerCase().replaceAll('_', ' ')
            : 'En cours';
        return _infoBox(const Color(0xFFFFF3E0), const Color(0xFFF97316),
            Icons.settings_outlined,
            "⚙️ Étape en cours : $labelEtape");

      // ── ATTENTE_PAIEMENT : le client doit payer ────────────────────────
      case 'ATTENTE_PAIEMENT':
        return _buildPaiementButton(id, montant);

      case 'CLOTUREE':
        return _infoBox(AppColors.greenLight, AppColors.green,
            Icons.check_circle,
            "Commande clôturée ✅ Merci de votre confiance !");

      case 'ANNULEE':
        return _infoBox(const Color(0xFFFCEBEB), Colors.red,
            Icons.cancel_outlined, "Commande annulée");

      case 'LITIGE':
        return _infoBox(const Color(0xFFFFF3E0), Colors.orange,
            Icons.warning_amber, "⚠️ Litige en cours de traitement");

      default:
        if (_statut.isEmpty) return const SizedBox.shrink();
        return _infoBox(const Color(0xFFFFF3E0), const Color(0xFFF97316),
            Icons.update_outlined,
            "Étape en cours : ${_labelEtape(_statut)}");
    }
  }

  // ── 💳 Bouton payer (ATTENTE_PAIEMENT) ─────────────────────────────────────
  Widget _buildPaiementButton(int id, int montant) {
    return Column(children: [
      _infoBox(const Color(0xFFFFF8F0), Colors.orange,
          Icons.payment_rounded,
          "💳 Prestation terminée ! Procédez au paiement pour clôturer votre commande."),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
          onPressed: () => _showPaiementSheet(id, montant),
          icon: const Icon(Icons.payment_rounded, size: 20),
          label: Text("Payer ${_fmt(montant)} FCFA",
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    ]);
  }

  // ── PaiementBottomSheet (WAVE, ORANGE_MONEY, YAS) ──────────────────────────
  Future<void> _showPaiementSheet(int commandeId, int montant) async {
    final result = await PaiementBottomSheet.show(
      context,
      montant: montant.toDouble(),
      commandeId: commandeId,
    );
    if (result == null) return;
    final token = await AuthStorage.getToken();
    try {
      final res = await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}/paiement/commande/$commandeId'
          '?montant=${result['montant']}'
          '&modePaiement=${result['operateur']}'
          '&reference=${Uri.encodeComponent(result['transactionId'] ?? '')}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Paiement enregistré !',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ));
        await _loadCommande(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur ${res.statusCode}',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connexion impossible',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Devis (exigeDevis=true → prestataire envoie prix réel) ────────────────
  Widget _buildDevisAction(int id, int montant) {
    return Column(children: [
      _infoBox(const Color(0xFFFFF3E0), const Color(0xFFF97316),
          Icons.description_outlined,
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
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APPELS API
  // ════════════════════════════════════════════════════════════════════════════
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
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
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

  // ── Badge statut : Couche 1 uniquement ──────────────────────────────────
  Map<String, dynamic> _getStatutBadge(String statut) {
    switch (statut) {
      case 'CREE':
        return {'label': 'En attente',      'color': AppColors.primary};
      case 'CONFIRMEE':
        return {'label': 'Confirmée',        'color': AppColors.green};
      case 'EN_COURS':
        return {'label': '⚙️ En cours',      'color': const Color(0xFFF97316)};
      case 'ATTENTE_PAIEMENT':
        return {'label': '💳 À payer',       'color': Colors.orange};
      case 'CLOTUREE':
        return {'label': 'Clôturée ✅',      'color': AppColors.green};
      case 'ANNULEE':
        return {'label': 'Annulée',          'color': Colors.red};
      case 'LITIGE':
        return {'label': '⚠️ Litige',        'color': Colors.orange};
      // Couche 2 : formatage automatique (ne devrait plus arriver en badge)
      default:
        return {'label': _labelEtape(statut), 'color': const Color(0xFFF97316)};
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
        Expanded(child: Text(msg,
            style: GoogleFonts.poppins(fontSize: 11, color: fg))),
      ]),
    );
  }

  String _labelEtape(String s) =>
      s.replaceAll('_', ' ').toLowerCase()
          .split(' ')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');

  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final rem = s.length % 3;
    buf.write(s.substring(0, rem == 0 ? 3 : rem));
    for (var i = rem == 0 ? 3 : rem; i < s.length; i += 3) {
      buf.write(' ');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }
}