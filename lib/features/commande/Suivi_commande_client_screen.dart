// lib/features/commande/suivi_commande_client_screen.dart   ← NOM CORRIGÉ (s minuscule)
//
// ✅ ARCHITECTURE THÈSE : Zéro if(typeService)
// Vue CLIENT : suivi de l'avancement d'une commande + paiement
//
// FLUX :
//   CREE → CONFIRMEE (facture visible) → EN_COURS → ATTENTE_PAIEMENT
//   → Client paie (Wave / Orange Money / Yas) → CLOTUREE + trace
//   → ou LITIGE si problème
//
// COULEURS : AppColors.primary (bleu) pour le client
// AppColors.purple ✅ CORRIGÉ (n'était pas défini localement — on utilise AppColors directement)
// _etapeIndex : .toUpperCase() ✅ CORRIGÉ

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_storage.dart';
import 'paiement_bottom_sheet.dart';
// ✅ Widget barre de progression partagé — rollback = retirer cet import
import 'commande_progress_bar.dart';

class SuiviCommandeClientScreen extends StatefulWidget {
  final Map<String, dynamic> commande;

  /// Étapes effectives issues de la config du prestataire
  final List<String> etapesEffectives;

  const SuiviCommandeClientScreen({
    super.key,
    required this.commande,
    required this.etapesEffectives,
  });

  @override
  State<SuiviCommandeClientScreen> createState() =>
      _SuiviCommandeClientScreenState();
}

class _SuiviCommandeClientScreenState
    extends State<SuiviCommandeClientScreen> {
  late Map<String, dynamic> _cmd;
  late List<String> _configEtapes;
  bool _loading = false;
  bool _paying = false;

  // ── Étapes complètes ─────────────────────────────────────────────────────
  List<String> get _fullEtapes {
    List<String> base;
    if (_configEtapes.isEmpty) {
      base = ['CREE', 'CONFIRMEE', 'CLOTUREE'];
    } else if (_configEtapes.contains('CREE')) {
      base = List<String>.from(_configEtapes);
    } else {
      base = ['CREE', 'CONFIRMEE', ..._configEtapes, 'CLOTUREE'];
    }
    final clotIdx = base.indexOf('CLOTUREE');
    if (clotIdx >= 0 && !base.contains('ATTENTE_PAIEMENT')) {
      base.insert(clotIdx, 'ATTENTE_PAIEMENT');
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _cmd = Map<String, dynamic>.from(widget.commande);
    _configEtapes = List<String>.from(widget.etapesEffectives);
  }

  // ── Rafraîchir la commande ────────────────────────────────────────────────
  Future<void> _refresh() async {
    setState(() => _loading = true);
    final token = await AuthStorage.getToken();
    final id = _cmd['id'];
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.commandes}/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _cmd = updated;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
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
      case 'ATTENTE_PAIEMENT':
        final idx = full.indexOf('ATTENTE_PAIEMENT');
        return idx >= 0 ? idx : full.length - 2;
      case 'CLOTUREE':
        return full.indexOf('CLOTUREE').clamp(0, full.length - 1);
      case 'ANNULEE':
        return -1;
      case 'EN_COURS':
        final ec =
            (_cmd['etapeCourante'] as String? ?? '').toUpperCase(); // FIX
        final mid = full
            .where((e) =>
                e != 'CREE' &&
                e != 'CONFIRMEE' &&
                e != 'ATTENTE_PAIEMENT' &&
                e != 'CLOTUREE')
            .toList();
        final idx = mid.indexOf(ec);
        final confirmIdx = full.indexOf('CONFIRMEE');
        return idx >= 0 ? confirmIdx + 1 + idx : confirmIdx + 1;
      default:
        return 0;
    }
  }

  // ── Payer la commande ─────────────────────────────────────────────────────
  Future<void> _payerCommande() async {
    final montant = _getMontant();
    if (montant <= 0) {
      _showSnack('Montant non disponible', isError: true);
      return;
    }

    final result = await PaiementBottomSheet.show(
      context,
      montant: montant,
      commandeId: _cmd['id'] as int,
    );
    if (result == null) return; // annulé

    setState(() => _paying = true);
    final token = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    final id = _cmd['id'];

    // Enregistrer le paiement → CLOTUREE
    final url = '${ApiConstants.commandes}/$id/statut'
        '?statut=CLOTUREE'
        '&acteurId=$userId'
        '&operateurPaiement=${result['operateur']}'
        '&transactionId=${result['transactionId']}'
        '&montantPaye=${montant.toStringAsFixed(0)}'
        '&telephonePaiement=${result['telephone']}';

    try {
      final res = await http.put(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() { _cmd = updated; _paying = false; });
        _showSnack('Paiement enregistré ✓ Commande clôturée');
      } else {
        setState(() => _paying = false);
        _showSnack('Erreur ${res.statusCode}', isError: true);
      }
    } catch (_) {
      setState(() => _paying = false);
      _showSnack('Connexion impossible', isError: true);
    }
  }

  // ── Signaler un litige ────────────────────────────────────────────────────
  Future<void> _signalerLitige() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Signaler un litige',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'Confirmez-vous un problème avec cette commande ?',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler',
                  style: GoogleFonts.poppins(color: AppColors.textSecond))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Confirmer',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();
    final id = _cmd['id'];
    try {
      final res = await http.put(
        Uri.parse(
            '${ApiConstants.commandes}/$id/statut?statut=LITIGE&acteurId=$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _cmd = jsonDecode(res.body) as Map<String, dynamic>);
        _showSnack('Litige signalé');
      }
    } catch (_) {
      _showSnack('Connexion impossible', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _getMontant() {
    return ((_cmd['montantTotal'] ?? _cmd['montant']) as num?)?.toDouble() ??
        0.0;
  }

  String _labelStatut(String s) {
    const map = {
      'CREE': 'Créée',
      'CONFIRMEE': 'Confirmée',
      'EN_COURS': 'En cours',
      'ATTENTE_PAIEMENT': 'À payer',
      'CLOTUREE': 'Clôturée',
      'ANNULEE': 'Annulée',
      'LITIGE': 'Litige',
    };
    return map[s] ?? s;
  }

  Color _colorStatut(String s) {
    switch (s) {
      case 'CREE':             return AppColors.primary;
      case 'CONFIRMEE':        return AppColors.purple; // ✅ FIX (AppColors.purple existe)
      case 'EN_COURS':         return AppColors.amber;
      case 'ATTENTE_PAIEMENT': return AppColors.amber;
      case 'CLOTUREE':         return AppColors.green;
      case 'ANNULEE':          return AppColors.red;
      case 'LITIGE':           return AppColors.red;
      default:                 return AppColors.textSecond;
    }
  }

  // _labelEtapeProgress → déplacé dans CommandeProgressBar.labelEtape()

  String _fmt(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return '${buf.toString()} FCFA';
  }

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

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    final ec = _cmd['etapeCourante'] as String?;
    final montant = _getMontant();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Commande #${_cmd['id']}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Carte progression ─────────────────────────────────────
            _buildProgressCard(statut, ec),
            const SizedBox(height: 16),

            // ── Montant + facture (dès CONFIRMEE) ─────────────────────
            if (montant > 0 || statut == 'CONFIRMEE') ...[
              _buildMontantCard(montant, statut),
              const SizedBox(height: 16),
            ],

            // ── Infos commande ────────────────────────────────────────
            _buildInfoCard(),
            const SizedBox(height: 16),

            // ── Champs personnalisés ──────────────────────────────────
            if (_getChampsCommande().isNotEmpty) ...[
              _buildChampsCard(),
              const SizedBox(height: 16),
            ],

            // ── Carte paiement (ATTENTE_PAIEMENT) ─────────────────────
            if (statut == 'ATTENTE_PAIEMENT') ...[
              _buildPaiementCard(montant),
              const SizedBox(height: 16),
            ],

            // ── Trace paiement (CLOTUREE) ─────────────────────────────
            if (statut == 'CLOTUREE' && _hasPaiementTrace()) ...[
              _buildTraceCard(),
              const SizedBox(height: 16),
            ],

            // ── Litige (CLOTUREE seulement) ───────────────────────────
            if (statut == 'ATTENTE_PAIEMENT') ...[
              _buildLitigeButton(),
              const SizedBox(height: 20),
            ],
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
          // Badge statut
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
              Flexible(
                child: Text(
                  '· ${ec[0].toUpperCase()}${ec.substring(1).toLowerCase()}',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ]),

          if (statut != 'ANNULEE') ...[
            const SizedBox(height: 20),
            _buildEtapesProgress(),
          ],

          // Message contextuel
          const SizedBox(height: 12),
          _buildContextMessage(statut),
        ],
      ),
    );
  }

  // ✅ Délègue à CommandeProgressBar (commande_progress_bar.dart)
  Widget _buildEtapesProgress() {
    final statut = _cmd['statut'] as String? ?? 'CREE';
    return CommandeProgressBar(
      fullEtapes   : _fullEtapes,
      currentIndex : _etapeIndex,
      accentColor  : _colorStatut(statut),  // couleur dynamique selon le statut
      doneColor    : AppColors.primary,     // bleu client pour les étapes passées
    );
  }

  Widget _buildContextMessage(String statut) {
    String msg;
    IconData icon;
    Color color;
    switch (statut) {
      case 'CREE':
        msg = 'En attente de confirmation par le prestataire.';
        icon = Icons.hourglass_empty_rounded;
        color = AppColors.primary;
        break;
      case 'CONFIRMEE':
        msg = 'Votre commande est confirmée. Le bilan vous a été transmis.';
        icon = Icons.check_circle_outline;
        color = AppColors.purple;
        break;
      case 'EN_COURS':
        msg = 'La prestation est en cours de traitement.';
        icon = Icons.engineering_outlined;
        color = AppColors.amber;
        break;
      case 'ATTENTE_PAIEMENT':
        msg = 'La prestation est terminée. Procédez au paiement.';
        icon = Icons.payment_outlined;
        color = AppColors.amber;
        break;
      case 'CLOTUREE':
        msg = 'Commande clôturée. Merci !';
        icon = Icons.verified_rounded;
        color = AppColors.green;
        break;
      case 'LITIGE':
        msg = 'Litige en cours de traitement.';
        icon = Icons.report_problem_outlined;
        color = AppColors.red;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(msg,
            style: GoogleFonts.poppins(
                fontSize: 12, color: color, fontStyle: FontStyle.italic)),
      ),
    ]);
  }

  // ── Carte montant ──────────────────────────────────────────────────────────
  Widget _buildMontantCard(double montant, String statut) {
    final fraisLivraison =
        ((_cmd['fraisLivraison'] ?? _cmd['frais_livraison']) as num?)
                ?.toDouble() ??
            0.0;
    final total = montant + fraisLivraison;

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Facture',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),

        // Services
        if (_getPrestations().isNotEmpty) ...[
          ..._getPrestations().map((p) {
            final nom = (p['nom'] ?? p['typePrestation'] ?? 'Service').toString();
            final qte = ((p['quantite'] ?? p['qte'] ?? 1) as num).toInt();
            final prix = ((p['prixUnitaire'] ?? p['prix'] ?? p['montant'] ?? 0) as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('$nom × $qte',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecond)),
                  ),
                  Text('${(prix * qte).toStringAsFixed(0)} FCFA',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textPrimary)),
                ],
              ),
            );
          }),
          const Divider(height: 16),
        ],

        // Montant de base
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Sous-total',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecond)),
          Text(montant > 0 ? _fmt(montant) : '—',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textPrimary)),
        ]),

        // Frais livraison si applicable
        if (fraisLivraison > 0) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Frais de livraison',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond)),
            Text(_fmt(fraisLivraison),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.amber)),
          ]),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(_fmt(total),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
        ] else ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(montant > 0 ? _fmt(montant) : 'En attente',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: montant > 0 ? AppColors.primary : AppColors.textMuted)),
          ]),
        ],
      ]),
    );
  }

  // ── Carte paiement (ATTENTE_PAIEMENT) ─────────────────────────────────────
  Widget _buildPaiementCard(double montant) {
    final fraisLivraison =
        ((_cmd['fraisLivraison'] ?? _cmd['frais_livraison']) as num?)
                ?.toDouble() ??
            0.0;
    final total = montant + fraisLivraison;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, const Color(0xFFCCE0F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.payment_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('Paiement requis',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 8),
        Text(
          'Votre prestation est terminée.\nPayez pour clôturer la commande.',
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textSecond, height: 1.5),
        ),
        const SizedBox(height: 14),

        // Montant total à payer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text('Montant à régler',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecond)),
            Text(_fmt(total > 0 ? total : montant),
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
        ),
        const SizedBox(height: 14),

        // Bouton payer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _paying ? null : _payerCommande,
            icon: _paying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 18),
            label: Text('Payer maintenant',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Trace paiement (CLOTUREE) ──────────────────────────────────────────────
  bool _hasPaiementTrace() {
    return _cmd['transactionId'] != null ||
        _cmd['operateurPaiement'] != null;
  }

  Widget _buildTraceCard() {
    final operateur = _cmd['operateurPaiement'] as String? ?? '-';
    final txId = _cmd['transactionId'] as String? ?? '-';
    final date = _cmd['datePaiement'] as String?;
    final montantPaye =
        ((_cmd['montantPaye'] ?? _cmd['montantTotal'] ?? _cmd['montant']) as num?)
                ?.toDouble() ??
            0.0;

    final Map<String, Color> opColors = {
      'WAVE': const Color(0xFF0A85E0),
      'ORANGE_MONEY': const Color(0xFFFF6600),
      'YAS': const Color(0xFF8B00C8),
    };
    final Map<String, String> opLabels = {
      'WAVE': 'Wave',
      'ORANGE_MONEY': 'Orange Money',
      'YAS': 'Yas',
    };
    final opColor = opColors[operateur] ?? AppColors.green;
    final opLabel = opLabels[operateur] ?? operateur;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_rounded, color: AppColors.green, size: 20),
          const SizedBox(width: 8),
          Text('Paiement effectué',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.green)),
        ]),
        const SizedBox(height: 12),

        // Opérateur
        _traceRow(Icons.payment_outlined, 'Opérateur',
            opLabel, opColor),
        // Montant
        if (montantPaye > 0)
          _traceRow(Icons.attach_money_rounded, 'Montant payé',
              _fmt(montantPaye), AppColors.textPrimary),
        // Transaction ID
        _traceRow(Icons.tag_rounded, 'N° transaction',
            txId, AppColors.textSecond),
        // Date
        if (date != null)
          _traceRow(Icons.calendar_today_outlined, 'Date',
              _formatDate(date), AppColors.textSecond),
      ]),
    );
  }

  Widget _traceRow(IconData icon, String label, String value, Color valColor) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label : ',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecond)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: valColor,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  // ── Bouton litige ──────────────────────────────────────────────────────────
  Widget _buildLitigeButton() => TextButton.icon(
        onPressed: _signalerLitige,
        icon: Icon(Icons.report_problem_outlined,
            size: 16, color: AppColors.red),
        label: Text('Signaler un problème',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.red)),
      );

  // ── Infos commande ─────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return _card(
      title: 'Ma commande',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.store_outlined, 'Prestataire',
              _cmd['prestataireNom'] as String? ?? '-'),
          _infoRow(Icons.location_on_outlined, 'Adresse',
              _cmd['adresse'] as String? ?? 'Non précisée'),
          if (_cmd['dateCreation'] != null)
            _infoRow(Icons.calendar_today_outlined, 'Date',
                _formatDate(_cmd['dateCreation'] as String)),
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

  List<dynamic> _getPrestations() {
    return _cmd['prestations'] as List? ??
        _cmd['typesPrestation'] as List? ??
        [];
  }

  Widget _buildChampsCard() {
    final champs = _getChampsCommande();
    return _card(
      title: 'Détails de la prestation',
      child: Column(
        children: champs.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.key} : ',
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

  // ── Conteneur carte réutilisable ───────────────────────────────────────────
  Widget _card({required String title, required Widget child}) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}








// // suivi_commande_client_screen.dart
// // Écran de suivi pour le CLIENT — générique pour tous types de services.
// // • Cercles 26px avec labels en dessous (plus grands que côté prestataire)
// // • Carte agent si avecAgent = true (dynamique, piloté par l'API)
// // • Récapitulatif articles
// // • Note d'annulation si statut == 'CREE'
// // => ZÉRO if(typeService)

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class Suivi_commande_client_screen extends StatefulWidget {
//   final int commandeId;
//   final Color themeColor;

//   const Suivi_commande_client_screen({
//     super.key,
//     required this.commandeId,
//     required this.themeColor,
//   });

//   @override
//   State<Suivi_commande_client_screen> createState() =>
//       _Suivi_commande_client_screenState();
// }

// class _Suivi_commande_client_screenState
//     extends State<Suivi_commande_client_screen> {
//   static const String _baseUrl = 'http://localhost:7090';

//   Map<String, dynamic> _commande = {};
//   List<String> _etapesEffectives = [];
//   bool _avecAgent = false;
//   bool _loading = true;
//   Timer? _refreshTimer;

//   @override
//   void initState() {
//     super.initState();
//     _loadCommande();
//     // Rafraîchissement automatique toutes les 30 secondes
//     _refreshTimer = Timer.periodic(
//       const Duration(seconds: 30),
//       (_) => _loadCommande(),
//     );
//   }

//   @override
//   void dispose() {
//     _refreshTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _loadCommande() async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/commande/${widget.commandeId}'),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body) as Map<String, dynamic>;
//         // Charger la config du prestataire pour etapesEffectives et avecAgent
//         final prestataireId = data['prestataireId'];
//         if (prestataireId != null) {
//           await _loadConfig(prestataireId, data);
//         } else {
//           setState(() { _commande = data; _loading = false; });
//         }
//       } else {
//         setState(() { _commande = _demoCommande(); _loading = false; _appliquerDemoConfig(); });
//       }
//     } catch (_) {
//       setState(() { _commande = _demoCommande(); _loading = false; _appliquerDemoConfig(); });
//     }
//   }

//   Future<void> _loadConfig(dynamic prestataireId, Map<String, dynamic> commande) async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/$prestataireId'),
//       );
//       if (res.statusCode == 200) {
//         final config = jsonDecode(res.body) as Map<String, dynamic>;
//         setState(() {
//           _commande = commande;
//           _etapesEffectives =
//               (config['etapesEffectives'] as List? ?? []).cast<String>();
//           _avecAgent = config['avecAgent'] as bool? ?? false;
//           _loading = false;
//         });
//       } else {
//         setState(() { _commande = commande; _loading = false; _appliquerDemoConfig(); });
//       }
//     } catch (_) {
//       setState(() { _commande = commande; _loading = false; _appliquerDemoConfig(); });
//     }
//   }

//   void _appliquerDemoConfig() {
//     _etapesEffectives = [
//       'CREE', 'CONFIRMEE', 'EN_COLLECTE', 'EN_TRAITEMENT', 'EN_LIVRAISON', 'CLOTUREE'
//     ];
//     _avecAgent = false;
//   }

//   Map<String, dynamic> _demoCommande() => {
//     'id': widget.commandeId,
//     'numero': '042',
//     'statut': 'EN_TRAITEMENT',
//     'prestataireId': 1,
//     'prestataireNom': 'Express Laverie Pro',
//     'dateCommande': '2024-01-15T10:30:00',
//     'articles': [
//       {'nom': 'Chemise', 'quantite': 3, 'prixUnitaire': 500},
//       {'nom': 'Pantalon', 'quantite': 2, 'prixUnitaire': 800},
//     ],
//     'totalEstime': 3100,
//     'agent': {
//       'nom': 'Moussa Diallo',
//       'role': 'Agent de collecte',
//       'telephone': '+221 77 123 45 67',
//     },
//     'adresseCollecte': 'Quartier Liberté, Dakar',
//   };

//   String _labelStatut(String statut) {
//     const labels = {
//       'CREE': 'Créée',
//       'CONFIRMEE': 'Confirmée',
//       'EN_COLLECTE': 'Collecte',
//       'EN_TRAITEMENT': 'Traitement',
//       'EN_LIVRAISON': 'Livraison',
//       'CLOTUREE': 'Clôturée',
//       'ANNULEE': 'Annulée',
//     };
//     return labels[statut] ?? statut;
//   }

//   Map<String, dynamic> _statutConfig(String statut) {
//     const configs = {
//       'CREE': {'label': 'En attente', 'color': 0xFFF59E0B, 'bg': 0xFFFEF3C7, 'icon': '⏳'},
//       'CONFIRMEE': {'label': 'Confirmée', 'color': 0xFF3B82F6, 'bg': 0xFFEFF6FF, 'icon': '✅'},
//       'EN_COLLECTE': {'label': 'En collecte', 'color': 0xFF8B5CF6, 'bg': 0xFFF5F3FF, 'icon': '🚗'},
//       'EN_TRAITEMENT': {'label': 'En traitement', 'color': 0xFFF97316, 'bg': 0xFFFFF7ED, 'icon': '⚙️'},
//       'EN_LIVRAISON': {'label': 'En livraison', 'color': 0xFF06B6D4, 'bg': 0xFFECFEFF, 'icon': '📦'},
//       'CLOTUREE': {'label': 'Terminée ✓', 'color': 0xFF16A34A, 'bg': 0xFFDCFCE7, 'icon': '🎉'},
//       'ANNULEE': {'label': 'Annulée', 'color': 0xFFDC2626, 'bg': 0xFFFEE2E2, 'icon': '❌'},
//     };
//     return configs[statut] ?? {'label': statut, 'color': 0xFF94A3B8, 'bg': 0xFFF1F5F9, 'icon': '•'};
//   }

//   int get _currentIdx {
//     final statut = _commande['statut'] as String? ?? '';
//     return _etapesEffectives.indexOf(statut);
//   }

//   Future<void> _annulerCommande() async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Annuler la commande ?'),
//         content: const Text(
//           'Cette action est irréversible. Votre commande sera annulée.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text('Non, garder'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFFDC2626),
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Oui, annuler'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       try {
//         await http.put(
//           Uri.parse(
//               '$_baseUrl/api/commande/${widget.commandeId}/statut?statut=ANNULEE'),
//         );
//         _loadCommande();
//       } catch (_) {
//         setState(() => _commande['statut'] = 'ANNULEE');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return Scaffold(
//         appBar: AppBar(
//           backgroundColor: widget.themeColor,
//           foregroundColor: Colors.white,
//           title: const Text('Chargement...'),
//         ),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     final numero = _commande['numero']?.toString() ?? widget.commandeId.toString();
//     final statut = _commande['statut'] as String? ?? '';
//     final sConfig = _statutConfig(statut);
//     final articles = (_commande['articles'] as List? ?? []).cast<Map<String, dynamic>>();
//     final total = _commande['totalEstime'] as int? ?? 0;
//     final agent = _commande['agent'] as Map<String, dynamic>?;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         backgroundColor: widget.themeColor,
//         foregroundColor: Colors.white,
//         title: Text(
//           'Commande #$numero',
//           style: const TextStyle(fontWeight: FontWeight.w700),
//         ),
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh_rounded),
//             onPressed: _loadCommande,
//             tooltip: 'Actualiser',
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── CARTE STATUT ──────────────────────────────────────────────
//             _buildCarteStatut(statut, sConfig, numero),

//             const SizedBox(height: 16),

//             // ── CARTE AGENT (si avecAgent = true, depuis API) ─────────────
//             if (_avecAgent && agent != null) ...[
//               _buildCarteAgent(agent),
//               const SizedBox(height: 16),
//             ],

//             // ── RÉCAP ARTICLES ────────────────────────────────────────────
//             _buildRecapArticles(articles, total),

//             const SizedBox(height: 16),

//             // ── BOUTON ANNULATION (seulement si CREE) ─────────────────────
//             if (statut == 'CREE') _buildNoteAnnulation(),

//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCarteStatut(
//     String statut,
//     Map<String, dynamic> sConfig,
//     String numero,
//   ) {
//     final color = Color(sConfig['color'] as int);
//     final bg = Color(sConfig['bg'] as int);
//     final label = sConfig['label'] as String;
//     final icon = sConfig['icon'] as String;
//     final prestataireNom = _commande['prestataireNom'] as String? ?? '';

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 16,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Badge statut + prestataire
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: bg,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(icon, style: const TextStyle(fontSize: 14)),
//                     const SizedBox(width: 6),
//                     Text(
//                       label,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.w700,
//                         color: color,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Spacer(),
//               if (prestataireNom.isNotEmpty)
//                 Text(
//                   prestataireNom,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     color: Color(0xFF94A3B8),
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//             ],
//           ),

//           const SizedBox(height: 24),

//           // Progression avec cercles 26px + labels en dessous
//           _buildEtapesCerclesAvecLabels(color),
//         ],
//       ),
//     );
//   }

//   /// Cercles 26px avec labels en dessous — maquette suivi client
//   Widget _buildEtapesCerclesAvecLabels(Color currentColor) {
//     final count = _etapesEffectives.length;
//     if (count == 0) return const SizedBox.shrink();

//     final idx = _currentIdx;

//     return Column(
//       children: [
//         // Ligne des cercles + connecteurs
//         Row(
//           children: List.generate(count * 2 - 1, (i) {
//             if (i.isOdd) {
//               final segIdx = i ~/ 2;
//               final done = segIdx < idx;
//               return Expanded(
//                 child: Container(
//                   height: 3,
//                   color: done
//                       ? const Color(0xFF16A34A)
//                       : const Color(0xFFE2E8F0),
//                 ),
//               );
//             }
//             final circleIdx = i ~/ 2;
//             final done = circleIdx < idx;
//             final current = circleIdx == idx;
//             Color circleColor;
//             if (done) {
//               circleColor = const Color(0xFF16A34A);
//             } else if (current) {
//               circleColor = currentColor;
//             } else {
//               circleColor = const Color(0xFFE2E8F0);
//             }

//             return Container(
//               width: 26,
//               height: 26,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: circleColor,
//                 boxShadow: current
//                     ? [
//                         BoxShadow(
//                           color: currentColor.withValues(alpha: 0.3),
//                           spreadRadius: 4,
//                           blurRadius: 0,
//                         )
//                       ]
//                     : null,
//               ),
//               child: Center(
//                 child: done
//                     ? const Icon(Icons.check_rounded,
//                         size: 14, color: Colors.white)
//                     : Text(
//                         '${circleIdx + 1}',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w800,
//                           color: current ? Colors.white : const Color(0xFF94A3B8),
//                         ),
//                       ),
//               ),
//             );
//           }),
//         ),

//         // Labels en dessous de chaque cercle
//         const SizedBox(height: 6),
//         Row(
//           children: List.generate(count * 2 - 1, (i) {
//             if (i.isOdd) return const Expanded(child: SizedBox());
//             final circleIdx = i ~/ 2;
//             final done = circleIdx < idx;
//             final current = circleIdx == idx;
//             final etape = _etapesEffectives[circleIdx];
//             final label = _labelStatut(etape);

//             return SizedBox(
//               width: 26,
//               child: Tooltip(
//                 message: label,
//                 child: Text(
//                   label.length > 5 ? '${label.substring(0, 4)}.' : label,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: current ? FontWeight.w800 : FontWeight.w400,
//                     color: done
//                         ? const Color(0xFF16A34A)
//                         : current
//                             ? const Color(0xFF1E293B)
//                             : const Color(0xFF94A3B8),
//                   ),
//                 ),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildCarteAgent(Map<String, dynamic> agent) {
//     final nom = agent['nom'] as String? ?? '';
//     final role = agent['role'] as String? ?? 'Agent';
//     final telephone = agent['telephone'] as String? ?? '';
//     final initiale = nom.isNotEmpty ? nom[0].toUpperCase() : 'A';

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFEFF6FF),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 48,
//             height: 48,
//             decoration: BoxDecoration(
//               color: widget.themeColor,
//               shape: BoxShape.circle,
//             ),
//             child: Center(
//               child: Text(
//                 initiale,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   nom,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 Text(
//                   role,
//                   style: const TextStyle(
//                     fontSize: 12,
//                     color: Color(0xFF64748B),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (telephone.isNotEmpty)
//             GestureDetector(
//               onTap: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Appel : $telephone')),
//                 );
//               },
//               child: Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: widget.themeColor,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.phone_rounded,
//                   size: 18,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRecapArticles(
//     List<Map<String, dynamic>> articles,
//     int total,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             '📋 Récapitulatif',
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//           const SizedBox(height: 12),
//           if (articles.isEmpty)
//             const Text(
//               'Aucun article renseigné',
//               style: TextStyle(color: Color(0xFF94A3B8)),
//             )
//           else
//             ...articles.map((art) {
//               final nom = art['nom'] as String? ?? '';
//               final qte = art['quantite'] as int? ?? 0;
//               final prix = art['prixUnitaire'] as int? ?? 0;
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Text(
//                       '$nom × $qte',
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Color(0xFF1E293B),
//                       ),
//                     ),
//                     const Spacer(),
//                     Text(
//                       '${prix * qte} FCFA',
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF1E293B),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }),
//           const Divider(height: 20),
//           Row(
//             children: [
//               const Text(
//                 'Total estimé',
//                 style: TextStyle(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF1E293B),
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 '$total FCFA',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w800,
//                   color: widget.themeColor,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNoteAnnulation() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFF7ED),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: const Color(0xFFFED7AA),
//           width: 1.5,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.info_outline_rounded,
//                   color: Color(0xFFF97316), size: 18),
//               SizedBox(width: 8),
//               Text(
//                 'Annulation possible',
//                 style: TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 14,
//                   color: Color(0xFFF97316),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Vous pouvez annuler cette commande tant qu\'elle n\'a pas été confirmée par le prestataire.',
//             style: TextStyle(
//               fontSize: 13,
//               color: Color(0xFF92400E),
//               height: 1.4,
//             ),
//           ),
//           const SizedBox(height: 12),
//           SizedBox(
//             width: double.infinity,
//             child: OutlinedButton(
//               onPressed: _annulerCommande,
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: const Color(0xFFDC2626),
//                 side: const BorderSide(
//                     color: Color(0xFFDC2626), width: 1.5),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//               ),
//               child: const Text(
//                 '❌ Annuler la commande',
//                 style: TextStyle(fontWeight: FontWeight.w700),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }