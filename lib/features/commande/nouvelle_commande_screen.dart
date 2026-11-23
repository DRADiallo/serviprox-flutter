// lib/features/commande/nouvelle_commande_screen.dart
//
// Formulaire de création d'une commande client
// - Reçoit le prestataire depuis FichePrestataireScreen
// - Sélecteurs quantité +/- par typePrestation
// - Sélection mode dépôt (COLLECTE_DOMICILE, DEPOT_MAGASIN, etc.)
// - Champ adresse conditionnel (si collecte domicile)
// - Récapitulatif total en temps réel
// - POST /api/commande/client/{clientId} avec JWT
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class NouvelleCommandeScreen extends StatefulWidget {
  final Map<String, dynamic> prestataire;

  const NouvelleCommandeScreen({super.key, required this.prestataire});

  @override
  State<NouvelleCommandeScreen> createState() =>
      _NouvelleCommandeScreenState();
}

class _NouvelleCommandeScreenState extends State<NouvelleCommandeScreen> {
  // ── State ────────────────────────────────────────────────
  final Map<int, int> _quantites = {}; // typePrestationId → quantité
  String? _selectedMode;
  final _adresseController = TextEditingController();
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  // ── Accesseurs ───────────────────────────────────────────
  Map<String, dynamic> get _p => widget.prestataire;

  String _str(String key) => _p[key]?.toString() ?? '';

  String get _nomPrestataire =>
      _str('nomCommercial').isNotEmpty ? _str('nomCommercial') : 'Prestataire';

  String get _icone {
    final i = _p['icone'] ?? _p['emoji'];
    if (i != null && i.toString().isNotEmpty) return i.toString();
    const map = {
      'pressing': '',
      'reparation': '🔧',
      'coiffure': '',
      'soins': '',
    };
    return map[_str('typeService').toLowerCase()] ?? '🏪';
  }

  /// Liste des types de prestation depuis le map prestataire
  List<Map<String, dynamic>> get _prestations {
    try {
      final raw = _p['typesPrestation'] ?? _p['prestationsAjoutees'];
      List items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is String && raw.isNotEmpty) {
        items = jsonDecode(raw) as List;
      }
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Modes de dépôt effectifs
  List<String> get _modesDepot {
    try {
      final m = _p['modesDepotEffectifs'];
      if (m is List) return m.map((e) => e.toString()).toList();
      if (m is String && m.isNotEmpty) {
        return (jsonDecode(m) as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return []; // null côté backend → section masquée
  }
  // List<String> get _modesDepot {
  //   try {
  //     final m = _p['modesDepotEffectifs'];
  //     if (m is List) return m.map((e) => e.toString()).toList();
  //     if (m is String && m.isNotEmpty) {
  //       return (jsonDecode(m) as List).map((e) => e.toString()).toList();
  //     }
  //   } catch (_) {}
  //   final avecAgent = _p['avecAgent'] as bool? ?? false;
  //   return ['DEPOT_MAGASIN', if (avecAgent) 'COLLECTE_DOMICILE'];
  // }

  /// Prix unitaire d'une prestation (gère prix ou prixUnitaire)
  int _prixUnitaire(Map<String, dynamic> p) {
    final v = p['prixUnitaire'] ?? p['prix'] ?? p['price'] ?? 0;
    return (v as num).toInt();
  }

  /// Quantité courante pour un id
  int _qte(int id) => _quantites[id] ?? 0;

  /// Libellé lisible d'un mode dépôt (clé API → texte FR)
  String _libelleModeDepot(String mode) {
    const labels = {
      'COLLECTE_DOMICILE': 'Collecte à domicile',
      'DEPOT_MAGASIN': 'Dépôt en magasin / atelier',
      'LIVRAISON_DOMICILE': 'Livraison à domicile',
      'DEPOT_POINT_RELAIS': 'Point relais',
    };
    if (labels.containsKey(mode)) return labels[mode]!;
    // Modes déjà lisibles (ex: 'Dépôt atelier')
    return mode.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  /// Icône pour un mode dépôt
  IconData _iconeModeDepot(String mode) {
    if (mode.contains('COLLECTE') || mode.toLowerCase().contains('domicile')) {
      return Icons.home_outlined;
    }
    if (mode.contains('MAGASIN') || mode.toLowerCase().contains('atelier')) {
      return Icons.storefront_outlined;
    }
    if (mode.contains('LIVRAISON')) return Icons.local_shipping_outlined;
    if (mode.contains('RELAIS')) return Icons.location_on_outlined;
    return Icons.swap_horiz_outlined;
  }

  /// Vrai si le mode sélectionné requiert une adresse
  bool get _needsAdresse {
    if (_selectedMode == null) return false;
    final m = _selectedMode!.toUpperCase();
    return m.contains('COLLECTE') || m.contains('DOMICILE');
  }

  /// Total calculé
 int get _total {
    int t = 0;
    final list = _prestations;
    for (int i = 0; i < list.length; i++) {
      final p = list[i];
      final id = p['id'] as int? ?? p['typePrestationId'] as int? ?? i;
      final qte = _qte(id);
      if (qte > 0) t += _prixUnitaire(p) * qte;
    }
    return t;
  }

  /// Au moins une prestation sélectionnée
  bool get _hasLignes =>
      _quantites.values.any((q) => q > 0);

  // ── Actions ──────────────────────────────────────────────

  void _incr(int id) => setState(() => _quantites[id] = (_qte(id)) + 1);

  void _decr(int id) {
    final v = _qte(id);
    if (v <= 0) return;
    setState(() {
      if (v == 1) {
        _quantites.remove(id);
      } else {
        _quantites[id] = v - 1;
      }
    });
  }

  Future<void> _soumettre() async {
    if (!_hasLignes) {
      _snack('Sélectionnez au moins une prestation.', isError: true);
      return;
    }
        // Si pas de modes configurés → dépôt atelier silencieux
    if (_selectedMode == null) {
      if (_modesDepot.isEmpty) {
        _selectedMode = 'DEPOT_MAGASIN';
      } else {
        _snack('Choisissez un mode de dépôt / collecte.', isError: true);
        return;
      }
    }
    if (_needsAdresse &&
        _adresseController.text.trim().isEmpty) {
      _snack('Saisissez votre adresse pour la collecte.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final prestataireId =
          _p['id'] as int? ?? _p['prestataireId'] as int? ?? 0;

      // Construction des lignes commande
       final lignes = <Map<String, dynamic>>[];
      final prestList = _prestations;
      for (int i = 0; i < prestList.length; i++) {
        final p = prestList[i];
        final id = p['id'] as int? ?? p['typePrestationId'] as int? ?? i;
        final qte = _qte(id);
        if (qte <= 0) continue;
        lignes.add({
          'typePrestationId': id,
          'typePrestation': p['nom']?.toString() ??
              p['label']?.toString() ??
              p['typePrestation']?.toString() ??
              '',
          'quantite': qte,
          'prixUnitaire': _prixUnitaire(p),
        });
      }

      final body = <String, dynamic>{
        'prestataireId': prestataireId,
        'lignes': lignes,
        'modeDepot': _selectedMode,
      };
      if (_needsAdresse && _adresseController.text.trim().isNotEmpty) {
        body['adresseCollecte'] = _adresseController.text.trim();
      }

      final uri = Uri.parse(
          '${ApiConstants.commandes}/client/$userId');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _showSuccessDialog();
      } else {
        final msg = _parseError(res.body);
        _snack(msg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _snack('Erreur réseau : $e', isError: true);
    }
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            'Erreur lors de la commande.';
      }
    } catch (_) {}
    return 'Erreur lors de la commande.';
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding:
            const EdgeInsets.fromLTRB(24, 32, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.green, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Commande envoyée !',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre commande a bien été transmise à $_nomPrestataire.'
              ' Vous pouvez suivre son avancement dans l\'onglet Commandes.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecond),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // ferme dialog
                // Dépile tous les écrans jusqu'au root (home)
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(
                'Voir mes commandes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: isError ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }


    @override
  void initState() {
    super.initState();
    // Auto-sélectionner si un seul mode disponible
    final modes = _modesDepot;
    if (modes.length == 1) {
      _selectedMode = modes.first;
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  void dispose() {
    _adresseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Récap prestataire ──────────────────────
              _buildPrestataireHeader(),
              const SizedBox(height: 24),

              // ── Prestations ───────────────────────────
              _buildSectionTitle('PRESTATIONS',
                  Icons.dry_cleaning_outlined),
              const SizedBox(height: 10),
              _buildPrestationsCard(),
              const SizedBox(height: 24),

              // ── Mode dépôt (masqué si prestataire n'a pas configuré) ──
              if (_modesDepot.isNotEmpty) ...[
                _buildSectionTitle('MODE DE DÉPÔT / COLLECTE',
                    Icons.local_shipping_outlined),
                const SizedBox(height: 10),
                _buildModesDepotCard(),
                const SizedBox(height: 8),
              ],

              // ── Adresse (conditionnel) ─────────────────
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _needsAdresse
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildAdresseField(),
                ),
                secondChild: const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // ── Récapitulatif total ───────────────────
              _buildRecap(),
            ],
          ),
        ),
      ),

      // ── Bouton commander ──────────────────────────────
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Widgets ──────────────────────────────────────────────

  AppBar _buildAppBar() => AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouvelle commande',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(_nomPrestataire,
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 12)),
          ],
        ),
        elevation: 0,
      );

  Widget _buildPrestataireHeader() {
    final note =
        (_p['moyenneNotes'] ?? _p['note'] ?? 0) as num;
    final nbAvis =
        (_p['nombreAvis'] ?? _p['nbAvis'] ?? 0) as num;
    final zone = _str('zone').isNotEmpty
        ? _str('zone')
        : _str('quartier');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(_icone,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomPrestataire,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (zone.isNotEmpty)
                  Text(
                    zone,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecond),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFB800), size: 15),
                    const SizedBox(width: 3),
                    Text(
                      note > 0
                          ? '${note.toStringAsFixed(1)} ($nbAvis avis)'
                          : 'Pas encore noté',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecond),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Disponible',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, IconData icon) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );

  Widget _buildPrestationsCard() {
    final prestations = _prestations;
    if (prestations.isEmpty) {
      return _emptyCard(
          'Aucune prestation configurée pour ce prestataire.');
    }

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < prestations.length; i++) ...[
            if (i > 0) _divider(),
            _buildPrestationRow(prestations[i], i),
          ],
        ],
      ),
    );
  }

  Widget _buildPrestationRow(Map<String, dynamic> p, int idx) {
    final id =
        p['id'] as int? ?? p['typePrestationId'] as int? ?? idx;
    final nom = p['nom']?.toString() ??
        p['label']?.toString() ??
        p['typePrestation']?.toString() ??
        '—';
    final unite = p['unite']?.toString() ?? 'pièce';
    final prix = _prixUnitaire(p);
    final qte = _qte(id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Nom + prix
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prix > 0
                      ? '${_formatPrix(prix)} FCFA / $unite'
                      : 'Sur devis',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.primary),
                ),
              ],
            ),
          ),

          // Compteur
          _buildQteSelector(id, qte),
        ],
      ),
    );
  }

  Widget _buildQteSelector(int id, int qte) {
    return Container(
      decoration: BoxDecoration(
        color: qte > 0 ? AppColors.primaryLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qte > 0 ? AppColors.primary : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton –
          GestureDetector(
            onTap: qte > 0 ? () => _decr(id) : null,
            child: Container(
              width: 36,
              height: 36,
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: qte > 0 ? AppColors.primary : AppColors.border,
              ),
            ),
          ),

          // Quantité
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '$qte',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: qte > 0 ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ),

          // Bouton +
          GestureDetector(
            onTap: () => _incr(id),
            child: Container(
              width: 36,
              height: 36,
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModesDepotCard() {
    final modes = _modesDepot;
    if (modes.isEmpty) {
      return _emptyCard('Aucun mode de dépôt configuré.');
    }

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < modes.length; i++) ...[
            if (i > 0) _divider(),
            _buildModeDepotRow(modes[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildModeDepotRow(String mode) {
    final selected = _selectedMode == mode;
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icône mode
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.greenLight
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.green : AppColors.border,
                  width: selected ? 1.2 : 0.5,
                ),
              ),
              child: Icon(
                _iconeModeDepot(mode),
                size: 20,
                color: selected ? AppColors.green : AppColors.textSecond,
              ),
            ),
            const SizedBox(width: 14),

            // Label
            Expanded(
              child: Text(
                _libelleModeDepot(mode),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecond,
                ),
              ),
            ),

            // Radio indicator
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.green : AppColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdresseField() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'ADRESSE DE COLLECTE',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _adresseController,
            maxLines: 3,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Ex : Villa 23, Almadies, près du rond-point…',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecap() {
    if (!_hasLignes) return const SizedBox.shrink();

    
    final lignes = <Map<String, dynamic>>[];
    final recapList = _prestations;
    for (int i = 0; i < recapList.length; i++) {
      final p = recapList[i];
      final id = p['id'] as int? ?? p['typePrestationId'] as int? ?? i;
      final qte = _qte(id);
      if (qte > 0) {
        lignes.add({
          'nom': p['nom']?.toString() ?? p['label']?.toString() ?? '—',
          'unite': p['unite']?.toString() ?? 'pièce',
          'qte': qte,
          'prix': _prixUnitaire(p),
        });
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'RÉCAPITULATIF',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lignes
          for (final l in lignes) ...[
            Row(
              children: [
                Text('${l['qte']}×',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l['nom'],
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                ),
                Text(
                  l['prix'] > 0
                      ? '${_formatPrix((l['prix'] as int) * (l['qte'] as int))} FCFA'
                      : 'Sur devis',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (_total > 0) ...[
            const Divider(color: AppColors.primary, thickness: 0.3),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total estimé',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(
                  '${_formatPrix(_total)} FCFA',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],

          if (_selectedMode != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_iconeModeDepot(_selectedMode!),
                    size: 14, color: AppColors.green),
                const SizedBox(width: 6),
                Text(
                  _libelleModeDepot(_selectedMode!),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _soumettre,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _total > 0
                          ? 'Commander · ${_formatPrix(_total)} FCFA'
                          : 'Commander',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers visuels ──────────────────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _divider() => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: AppColors.border,
      );

  Widget _emptyCard(String msg) => Container(
        decoration: _cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond),
              ),
            ),
          ],
        ),
      );

  String _formatPrix(int prix) {
    if (prix >= 1000) {
      final parts = prix.toString();
      final buffer = StringBuffer();
      final rem = parts.length % 3;
      for (int i = 0; i < parts.length; i++) {
        if (i > 0 && (i - rem) % 3 == 0) buffer.write(' ');
        buffer.write(parts[i]);
      }
      return buffer.toString();
    }
    return prix.toString();
  }
}

















// // nouvelle_commande_screen.dart
// // Formulaire de commande ENTIÈREMENT DYNAMIQUE — piloté par :
// //   • typesPrestation  → Section 1 : articles avec contrôles +/-
// //   • champsCommande   → Section 2 : champs TEXT / NUMBER / LIST
// //
// // ╔═══════════════════════════════════════════════════════╗
// // ║  PREUVE ARCHITECTURE : ZÉRO if(typeService) ici       ║
// // ║  Pressing 5 articles + 2 champs                       ║
// // ║  Réparation 3 articles + 3 champs                     ║
// // ║  Soins 4 articles + 1 champ                           ║
// // ║  → MÊME écran, rendu piloté 100% par l'API            ║
// // ╚═══════════════════════════════════════════════════════╝

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

// class NouvelleCommandeScreen extends StatefulWidget {
//   final Map<String, dynamic> prestataire;
//   final Map<String, dynamic> config;       // typesPrestation, champsCommande
//   final Color themeColor;
//   final int? clientId;

//   const NouvelleCommandeScreen({
//     super.key,
//     required this.prestataire,
//     required this.config,
//     required this.themeColor,
//     this.clientId,
//   });

//   @override
//   State<NouvelleCommandeScreen> createState() => _NouvelleCommandeScreenState();
// }

// class _NouvelleCommandeScreenState extends State<NouvelleCommandeScreen> {
//   static const String _baseUrl = 'http://localhost:7090';

//   // Section 1 : quantités par type de prestation
//   final Map<int, int> _quantites = {};  // prestationId → qté

//   // Section 2 : réponses aux champs dynamiques
//   final Map<int, dynamic> _reponses = {};  // champId → valeur

//   final _formKey = GlobalKey<FormState>();
//   bool _submitting = false;

//   List<Map<String, dynamic>> get _typesPrestation =>
//       (widget.config['typesPrestation'] as List? ?? [])
//           .cast<Map<String, dynamic>>();

//   List<Map<String, dynamic>> get _champsCommande =>
//       (widget.config['champsCommande'] as List? ?? [])
//           .cast<Map<String, dynamic>>();

//   // Calcul estimation totale
//   int get _totalEstime {
//     int total = 0;
//     for (final tp in _typesPrestation) {
//       final id = tp['id'] as int? ?? 0;
//       final qte = _quantites[id] ?? 0;
//       final prix = tp['prixUnitaire'] as int? ?? 0;
//       total += qte * prix;
//     }
//     return total;
//   }

//   bool get _hasArticles => _quantites.values.any((q) => q > 0);

//   Future<void> _confirmer() async {
//     if (!_hasArticles) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Veuillez sélectionner au moins un article.'),
//           backgroundColor: Color(0xFFEF4444),
//         ),
//       );
//       return;
//     }
//     if (!(_formKey.currentState?.validate() ?? true)) return;

//     setState(() => _submitting = true);

//     // Construire le corps de la commande
//     final articles = _typesPrestation
//         .where((tp) => (_quantites[tp['id'] as int? ?? 0] ?? 0) > 0)
//         .map((tp) => {
//               'prestationId': tp['id'],
//               'quantite': _quantites[tp['id'] as int? ?? 0],
//             })
//         .toList();

//     final body = jsonEncode({
//       'prestataireId': widget.prestataire['id'],
//       'clientId': widget.clientId ?? 1,
//       'articles': articles,
//       'champsFilles': _reponses,
//     });

//     try {
//       final res = await http.post(
//         Uri.parse('$_baseUrl/api/commandes'),
//         headers: {'Content-Type': 'application/json'},
//         body: body,
//       );

//       if (res.statusCode == 201 || res.statusCode == 200) {
//         final commande = jsonDecode(res.body) as Map<String, dynamic>;
//         if (mounted) {
//           setState(() => _submitting = false);
//           // Aller au paiement NabooPay
//           Navigator.pushNamed(
//             context,
//             '/naboo-pay',
//             arguments: {
//               'commande': commande,
//               'totalEstime': _totalEstime,
//               'prestataire': widget.prestataire,
//               'themeColor': widget.themeColor,
//             },
//           );
//         }
//       } else {
//         throw Exception('Erreur ${res.statusCode}');
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _submitting = false);
//         // Démo : naviguer quand même
//         Navigator.pushNamed(
//           context,
//           '/naboo-pay',
//           arguments: {
//             'commande': {'id': 42, 'statut': 'CREE'},
//             'totalEstime': _totalEstime,
//             'prestataire': widget.prestataire,
//             'themeColor': widget.themeColor,
//           },
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final nomPrestataire = widget.prestataire['nom'] as String? ?? '';

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         backgroundColor: widget.themeColor,
//         foregroundColor: Colors.white,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Nouvelle commande',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             Text(
//               nomPrestataire,
//               style: const TextStyle(
//                 fontSize: 12,
//                 color: Colors.white70,
//               ),
//             ),
//           ],
//         ),
//         elevation: 0,
//       ),
//       body: Form(
//         key: _formKey,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── SECTION 1 : Articles (typesPrestation) ──
//               _buildSectionHeader(
//                 '1',
//                 ' Sélectionnez vos articles',
//                 'Ajustez les quantités',
//               ),
//               const SizedBox(height: 12),
//               _buildSection1Articles(),

//               // ── SECTION 2 : Champs dynamiques (champsCommande) ──
//               if (_champsCommande.isNotEmpty) ...[
//                 const SizedBox(height: 24),
//                 _buildSectionHeader(
//                   '2',
//                   '📋 Informations complémentaires',
//                   'Renseignez les champs demandés',
//                 ),
//                 const SizedBox(height: 12),
//                 _buildSection2ChampsDynamiques(),
//               ],

//               const SizedBox(height: 100), // espace pour le footer
//             ],
//           ),
//         ),
//       ),
//       bottomNavigationBar: _buildFooter(),
//     );
//   }

//   Widget _buildSectionHeader(String numero, String titre, String sous) {
//     return Row(
//       children: [
//         Container(
//           width: 28,
//           height: 28,
//           decoration: BoxDecoration(
//             color: widget.themeColor,
//             shape: BoxShape.circle,
//           ),
//           child: Center(
//             child: Text(
//               numero,
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               titre,
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             Text(
//               sous,
//               style: const TextStyle(
//                 fontSize: 12,
//                 color: Color(0xFF94A3B8),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   // ── SECTION 1 : CARTE ARTICLE avec contrôles +/- ──────────────────────────
//   Widget _buildSection1Articles() {
//     return Container(
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
//         children: _typesPrestation.asMap().entries.map((entry) {
//           final idx = entry.key;
//           final tp = entry.value;
//           final id = tp['id'] as int? ?? idx;
//           final nom = tp['nom'] as String? ?? '';
//           final prix = tp['prixUnitaire'] as int? ?? 0;
//           final unite = tp['unite'] as String? ?? 'pièce';
//           final qte = _quantites[id] ?? 0;
//           final isLast = idx == _typesPrestation.length - 1;

//           return Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 14),
//                 child: Row(
//                   children: [
//                     // Nom + prix
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             nom,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w600,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                           const SizedBox(height: 2),
//                           Text(
//                             '$prix FCFA / $unite',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: widget.themeColor,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Contrôle quantité
//                     Row(
//                       children: [
//                         _buildQtyButton(
//                           icon: Icons.remove,
//                           onPressed: qte > 0
//                               ? () => setState(() => _quantites[id] = qte - 1)
//                               : null,
//                           color: widget.themeColor,
//                         ),
//                         AnimatedContainer(
//                           duration: const Duration(milliseconds: 150),
//                           width: 36,
//                           alignment: Alignment.center,
//                           child: Text(
//                             '$qte',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w800,
//                               color: qte > 0
//                                   ? widget.themeColor
//                                   : const Color(0xFFCBD5E1),
//                             ),
//                           ),
//                         ),
//                         _buildQtyButton(
//                           icon: Icons.add,
//                           onPressed: () =>
//                               setState(() => _quantites[id] = qte + 1),
//                           color: widget.themeColor,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               if (!isLast)
//                 const Divider(height: 1, indent: 16, endIndent: 16),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildQtyButton({
//     required IconData icon,
//     required VoidCallback? onPressed,
//     required Color color,
//   }) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 150),
//         width: 32,
//         height: 32,
//         decoration: BoxDecoration(
//           color: onPressed != null
//               ? color.withValues(alpha: 0.1)
//               : const Color(0xFFF1F5F9),
//           shape: BoxShape.circle,
//         ),
//         child: Icon(
//           icon,
//           size: 16,
//           color: onPressed != null ? color : const Color(0xFFCBD5E1),
//         ),
//       ),
//     );
//   }

//   // ── SECTION 2 : CHAMPS DYNAMIQUES ─────────────────────────────────────────
//   // Rendu de chaque champ selon son type : TEXT, NUMBER, LIST
//   // => ZÉRO if(typeService) : le type vient de l'API
//   Widget _buildSection2ChampsDynamiques() {
//     return Container(
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
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: _champsCommande.asMap().entries.map((entry) {
//           final idx = entry.key;
//           final champ = entry.value;
//           final isLast = idx == _champsCommande.length - 1;
//           return Column(
//             children: [
//               _buildChampDynamique(champ),
//               if (!isLast) const SizedBox(height: 16),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }

//   /// Rendu d'un champ selon son type (TEXT / NUMBER / LIST)
//   /// C'est ICI que se démontre le zéro if(typeService) :
//   /// le TYPE du champ décide du widget rendu, pas le typeService.
//   Widget _buildChampDynamique(Map<String, dynamic> champ) {
//     final id = champ['id'] as int? ?? 0;
//     final label = champ['label'] as String? ?? '';
//     final type = (champ['type'] as String? ?? 'TEXT').toUpperCase();
//     final requis = champ['requis'] as bool? ?? false;
//     final placeholder = champ['placeholder'] as String? ?? '';

//     switch (type) {
//       case 'LIST':
//         return _buildChampList(
//           id: id,
//           label: label,
//           options: (champ['options'] as List? ?? []).cast<String>(),
//           requis: requis,
//         );
//       case 'NUMBER':
//         return _buildChampNumber(
//           id: id,
//           label: label,
//           placeholder: placeholder,
//           requis: requis,
//         );
//       case 'TEXT':
//       default:
//         return _buildChampText(
//           id: id,
//           label: label,
//           placeholder: placeholder,
//           requis: requis,
//         );
//     }
//   }

//   Widget _buildChampLabel(String label, bool requis) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//           if (requis) ...[
//             const SizedBox(width: 4),
//             const Text(
//               '*',
//               style: TextStyle(
//                 color: Color(0xFFEF4444),
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildChampText({
//     required int id,
//     required String label,
//     required String placeholder,
//     required bool requis,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildChampLabel(label, requis),
//         TextFormField(
//           onChanged: (v) => _reponses[id] = v,
//           validator: requis
//               ? (v) => (v == null || v.isEmpty) ? 'Ce champ est requis' : null
//               : null,
//           decoration: InputDecoration(
//             hintText: placeholder.isNotEmpty ? placeholder : 'Saisissez...',
//             hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: widget.themeColor, width: 2),
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 14, vertical: 12),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildChampNumber({
//     required int id,
//     required String label,
//     required String placeholder,
//     required bool requis,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildChampLabel(label, requis),
//         TextFormField(
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           onChanged: (v) => _reponses[id] = int.tryParse(v) ?? 0,
//           validator: requis
//               ? (v) => (v == null || v.isEmpty) ? 'Ce champ est requis' : null
//               : null,
//           decoration: InputDecoration(
//             hintText: placeholder.isNotEmpty ? placeholder : '0',
//             hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: widget.themeColor, width: 2),
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 14, vertical: 12),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildChampList({
//     required int id,
//     required String label,
//     required List<String> options,
//     required bool requis,
//   }) {
//     final selected = _reponses[id] as String?;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildChampLabel(label, requis),
//         DropdownButtonFormField<String>(
//           value: selected,
//           onChanged: (v) => setState(() => _reponses[id] = v),
//           validator: requis
//               ? (v) => (v == null || v.isEmpty) ? 'Veuillez choisir une option' : null
//               : null,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: widget.themeColor, width: 2),
//             ),
//             contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 14, vertical: 4),
//           ),
//           hint: const Text(
//             'Sélectionner...',
//             style: TextStyle(color: Color(0xFFCBD5E1)),
//           ),
//           items: options.map((o) => DropdownMenuItem(
//             value: o,
//             child: Text(o),
//           )).toList(),
//         ),
//       ],
//     );
//   }

//   // ── FOOTER : ESTIMATION + BOUTON CONFIRMER ────────────────────────────────
//   Widget _buildFooter() {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 16,
//         bottom: MediaQuery.of(context).padding.bottom + 16,
//       ),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.08),
//             blurRadius: 16,
//             offset: const Offset(0, -4),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Estimation
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Estimation totale',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Color(0xFF64748B),
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               Text(
//                 '$_totalEstime FCFA',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                   color: _totalEstime > 0
//                       ? widget.themeColor
//                       : const Color(0xFFCBD5E1),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),

//           // Bouton confirmer
//           ElevatedButton(
//             onPressed: _submitting ? null : _confirmer,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: widget.themeColor,
//               foregroundColor: Colors.white,
//               disabledBackgroundColor: const Color(0xFFE2E8F0),
//               minimumSize: const Size(double.infinity, 52),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(14),
//               ),
//               elevation: 0,
//             ),
//             child: _submitting
//                 ? const SizedBox(
//                     width: 22,
//                     height: 22,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2.5,
//                       color: Colors.white,
//                     ),
//                   )
//                 : const Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         '✅ Confirmer la commande',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                       SizedBox(width: 8),
//                       Icon(Icons.arrow_forward_rounded, size: 18),
//                     ],
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }