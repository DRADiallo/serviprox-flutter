// lib/features/prestataire/prestataire_commandes_screen.dart
//
// ✅ ARCHITECTURE THÈSE : Zero if(typeService), openEHR deux couches
// COUCHE 1 : CREE, CONFIRMEE, EN_COURS, ATTENTE_PAIEMENT, CLOTUREE, ANNULEE, LITIGE
// COUCHE 2 : étapes OPAQUES dans etapesEffectives (noms définis par le prestataire)
// EN_COURS + etapeCourante = position dans les étapes Couche 2
// ATTENTE_PAIEMENT = étape universelle avant clôture
//
// COULEURS : AppColors.green (#27500A) pour le prestataire

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/commande_notifier.dart';

class PrestataireCommandesScreen extends StatefulWidget {
  const PrestataireCommandesScreen({super.key});

  @override
  State<PrestataireCommandesScreen> createState() =>
      _PrestataireCommandesScreenState();
}

class _PrestataireCommandesScreenState
    extends State<PrestataireCommandesScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _commandes = [];
  List<Map<String, dynamic>> _agents = [];

  /// Couche 2 : étapes dynamiques venant de la config prestataire (fallback)
  List<String> _configEtapes = [];

  /// exigeDevis et avecAgent viennent de ConfigPrestataireDTO
  bool _exigeDevis = false;
  bool _avecAgent = false;
  int _prestataireId = 0;

  VoidCallback? _fcmListener;

  // Couche 1 universels — NE JAMAIS ajouter des étapes métier ici
  static const Set<String> _couche1 = {
    'CREE', 'CONFIRMEE', 'EN_COURS', 'ATTENTE_PAIEMENT',
    'CLOTUREE', 'ANNULEE', 'LITIGE',
  };

  // ── Lire étapes Couche 2 depuis la commande (source de vérité) ──────────
  List<String> _getCommandeEtapes(Map<String, dynamic> cmd) {
    final raw = cmd['etapesEffectives'] as String?;
    if (raw == null || raw.isEmpty) return List.from(_configEtapes);
    try {
      final all = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      // Filtrer Couche 1 → garder seulement les étapes Couche 2 (opaques)
      return all.where((s) => !_couche1.contains(s)).toList();
    } catch (_) {
      return List.from(_configEtapes);
    }
  }

  String _filtreActif = 'Toutes';
  final List<String> _filtres = [
    'Toutes', 'Créées', 'Confirmées', 'En cours', 'Clôturées',
  ];
  
  
  @override
  void initState() {
    super.initState();
    _init();

    // FCM → refresh silencieux automatique
  _fcmListener = () {
    if (_prestataireId > 0 && mounted) _loadCommandes();
  };
  commandeRefreshTrigger.addListener(_fcmListener!);
  }

  @override
  void dispose() {
  if (_fcmListener != null) {
    commandeRefreshTrigger.removeListener(_fcmListener!);
  }
  super.dispose();
  }


  Future<void> _init() async {
  final id = await AuthStorage.getUserId();
  if (id == null) {
    if (mounted) setState(() { _error = 'Session expirée'; _loading = false; });
    return;
  }
  _prestataireId = id;
  await Future.wait([_loadConfig(), _loadCommandes()]);
  if (mounted) setState(() => _loading = false);  //  AJOUT CETTE LIGNE
}

  // ── Charger la configuration du prestataire ────────────────────────────
  Future<void> _loadConfig() async {
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConstants.prestataireConfig}/$_prestataireId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // ✅ FIX: lire depuis 'etapes' (List) ou 'etapesJson' (String)
        // PAS 'etapesEffectivesJson' qui n'existe pas dans ConfigPrestataireDTO
        List<String> etapes = [];
        final etapesRaw = data['etapes'];
        if (etapesRaw is List) {
          etapes = etapesRaw.map((e) => e.toString()).toList();
        } else {
          final etapesJson = data['etapesJson'] as String? ?? '[]';
          try {
            etapes = (jsonDecode(etapesJson) as List).cast<String>();
          } catch (_) {}
        }

        final avecAgent = data['avecAgent'] as bool? ?? false;
        final exigeDevis = data['exigeDevis'] as bool? ?? false;

        List<Map<String, dynamic>> agents = [];
        if (avecAgent) agents = await _fetchAgents(_prestataireId);

        if (mounted) {
          setState(() {
            _configEtapes = etapes;
            _avecAgent = avecAgent;
            _exigeDevis = exigeDevis;
            _agents = agents;
          });
        }
      }
    } catch (e) {
      debugPrint('Config error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAgents(int prestataireId) async {
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/agents/prestataire/$prestataireId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Agents error: $e');
    }
    return [];
  }

  // ── Charger les commandes du prestataire ───────────────────────────────
  Future<void> _loadCommandes() async {
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConstants.commandes}/prestataire/$_prestataireId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _commandes = list; }); // ← _loading géré par _init()
      } else {
      if (mounted) setState(() { _error = 'Erreur ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Connexion impossible'; _loading = false; });
    }
  }

  // ── Index dans la barre de progression ──────────────────────────────────
  // CREE=0, CONFIRMEE=1, EN_COURS → position selon etapeCourante Couche 2,
  // ATTENTE_PAIEMENT = avant-dernière, CLOTUREE = dernière
  int _getEtapeIndex(Map<String, dynamic> cmd) {
    final statut = cmd['statut'] as String? ?? 'CREE';
    if (statut == 'ANNULEE') return -1;
    final etapes = _getCommandeEtapes(cmd); // Couche 2 seulement
    switch (statut) {
      case 'CREE': return 0;
      case 'CONFIRMEE': return 1;
      case 'EN_COURS':
        final ec = (cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = etapes.indexOf(ec);
        return idx >= 0 ? 2 + idx : 2;
      case 'ATTENTE_PAIEMENT':
        return 2 + etapes.length; // après toutes les étapes Couche 2
      case 'CLOTUREE':
        return 3 + etapes.length; // dernière
      default: return 0;
    }
  }

  // ── Prochaine transition (architecture openEHR) ─────────────────────────
  Map<String, String?>? _getNextStep(Map<String, dynamic> cmd) {
    final statut = cmd['statut'] as String? ?? 'CREE';
    if (statut == 'CLOTUREE' || statut == 'ANNULEE' || statut == 'LITIGE') return null;
    // ATTENTE_PAIEMENT → le prestataire confirme paiement reçu → CLOTUREE
    if (statut == 'ATTENTE_PAIEMENT') return {'statut': 'CLOTUREE', 'etapeCourante': null};
    // devisEnAttente → attente client, pas de bouton avancer
    if (cmd['devisEnAttente'] == true) return null;

    final etapes = _getCommandeEtapes(cmd); // Couche 2 opaque

    switch (statut) {
      case 'CREE':
        return {'statut': 'CONFIRMEE', 'etapeCourante': null};
      case 'CONFIRMEE':
        if (etapes.isEmpty) return {'statut': 'ATTENTE_PAIEMENT', 'etapeCourante': null};
        return {'statut': 'EN_COURS', 'etapeCourante': etapes.first};
      case 'EN_COURS':
        final ec = (cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = etapes.indexOf(ec);
        if (idx < 0 || idx == etapes.length - 1) {
          return {'statut': 'ATTENTE_PAIEMENT', 'etapeCourante': null};
        }
        return {'statut': 'EN_COURS', 'etapeCourante': etapes[idx + 1]};
      default: return null;
    }
  }

  // ── PUT /api/commande/{id}/statut ────────────────────────────────────────
  Future<void> _avancerStatut(Map<String, dynamic> cmd) async {
    final nextStep = _getNextStep(cmd);
    if (nextStep == null) return;
    final id = cmd['id'];
    final token = await AuthStorage.getToken();

    var url = '${ApiConstants.commandes}/$id/statut'
        '?statut=${nextStep['statut']}'
        '&acteurId=$_prestataireId';
    if (nextStep['etapeCourante'] != null) {
      url += '&etapeCourante=${nextStep['etapeCourante']}';
    }

    try {
      final res = await http.put(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadCommandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Statut mis à jour',
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        _showSnack('Erreur ${res.statusCode}', isError: true);
      }
    } catch (_) {
      _showSnack('Connexion impossible', isError: true);
    }
  }

  // ── Confirmer paiement reçu (ATTENTE_PAIEMENT → CLOTUREE) ───────────────
  Future<void> _confirmerPaiementRecu(Map<String, dynamic> cmd) async {
    final commandeId = cmd['id'];
    final token = await AuthStorage.getToken();
    try {
      // 1. Récupérer le paiement
      final pRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/paiement/commande/$commandeId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (pRes.statusCode != 200) {
        _showSnack('Paiement introuvable', isError: true);
        return;
      }
      final paiementId = (jsonDecode(pRes.body) as Map<String, dynamic>)['id'];

      // 2. Confirmer côté prestataire → backend passe commande CLOTUREE
      final res = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/paiement/$paiementId/confirmer-prestataire'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadCommandes();
        _showSnack('✅ Paiement confirmé — commande clôturée !');
      } else {
        _showSnack('Erreur ${res.statusCode}', isError: true);
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

  // ── Filtrage ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _commandesFiltrees {
    if (_filtreActif == 'Toutes') return _commandes;
    switch (_filtreActif) {
      case 'Créées':    return _commandes.where((c) => c['statut'] == 'CREE').toList();
      case 'Confirmées':return _commandes.where((c) => c['statut'] == 'CONFIRMEE').toList();
      case 'En cours':  return _commandes.where((c) => c['statut'] == 'EN_COURS').toList();
      case 'Clôturées': return _commandes.where((c) =>
          c['statut'] == 'CLOTUREE' || c['statut'] == 'ATTENTE_PAIEMENT').toList();
      default: return _commandes;
    }
  }

  int _countByStatut(String statut) =>
      _commandes.where((c) => c['statut'] == statut).length;

  // ── Labels Couche 1 uniquement + générique pour Couche 2 ────────────────
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
    return map[s] ?? _cap(s.replaceAll('_', ' '));
  }

  // ── Couleurs Couche 1 uniquement ─────────────────────────────────────────
  Color _colorStatut(String s) {
    switch (s) {
      case 'CREE': return AppColors.primary;
      case 'CONFIRMEE': return AppColors.purple;
      case 'EN_COURS': return AppColors.amber;
      case 'ATTENTE_PAIEMENT': return Colors.orange;
      case 'CLOTUREE': return AppColors.green;
      case 'ANNULEE': return AppColors.red;
      case 'LITIGE': return AppColors.red;
      default: return AppColors.amber; // Couche 2 : même couleur qu'EN_COURS
    }
  }

  // ── Label du bouton — générique, PAS de noms Couche 2 hardcodés ─────────
  String _labelBouton(Map<String, dynamic> cmd) {
    final statut = cmd['statut'] as String? ?? 'CREE';
    switch (statut) {
      case 'CREE': return '✅ Confirmer';
      case 'CONFIRMEE': return ' Démarrer';
      case 'ATTENTE_PAIEMENT': return '💳 Confirmer paiement reçu';
      case 'EN_COURS':
        final etapes = _getCommandeEtapes(cmd);
        final ec = (cmd['etapeCourante'] as String? ?? '').toUpperCase();
        final idx = etapes.indexOf(ec);
        if (idx >= 0 && idx < etapes.length - 1) {
          return 'Passer à : ${_cap(etapes[idx + 1].replaceAll("_", " "))}';
        }
        return '💳 Envoyer pour paiement';
      default: return 'Avancer →';
    }
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _ouvrirDetail(Map<String, dynamic> cmd) async {
  await Future.delayed(const Duration(milliseconds: 80));
  if (!mounted) return;
  Navigator.pushNamed(context, '/commande-detail', arguments: {
    'commande': cmd,
    'etapesEffectives': _getCommandeEtapes(cmd),
    'agents': _agents,
    'prestataireId': _prestataireId,
    'avecAgent': _avecAgent,
  }).then((_) => _loadCommandes());
}

  // ── Fixer le prix réel (exigeDevis) ──────────────────────────────────────
  Future<void> _showFixerPrixDialog(Map<String, dynamic> cmd) async {
    final controller = TextEditingController();
    final prixActuel = cmd['montantTotal'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fixer le prix réel',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Commande #${cmd['id']}',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecond)),
          if (prixActuel != null) ...[
            const SizedBox(height: 4),
            Text('Prix estimé : ${prixActuel.toString()} FCFA',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecond)),
          ],
          const SizedBox(height: 16),
          Text('Prix réel (FCFA) :',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0.00', suffixText: 'FCFA',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text('Le client recevra un devis et devra accepter ou refuser.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecond)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: GoogleFonts.poppins(color: AppColors.textSecond)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Envoyer devis',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final prix = double.tryParse(controller.text.replaceAll(',', '.'));
    if (prix == null || prix <= 0) {
      _showSnack('Veuillez saisir un prix valide', isError: true);
      return;
    }

    final id = cmd['id'];
    final token = await AuthStorage.getToken();
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.commandes}/$id/fixer-prix'
            '?prix=$prix&acteurId=$_prestataireId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadCommandes();
        _showSnack('Devis envoyé au client ✓');
      } else {
        _showSnack('Erreur ${res.statusCode}', isError: true);
      }
    } catch (_) {
      _showSnack('Connexion impossible', isError: true);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Mes commandes',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _loadCommandes();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _error != null
              ? _buildError()
              : Column(children: [
                  _buildStats(),
                  _buildFiltres(),
                  Expanded(child: _buildListe()),
                ]),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 56,
            color: AppColors.red.withOpacity(0.6)),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.poppins(
            color: AppColors.textSecond, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            setState(() { _loading = true; _error = null; });
            _init();
          },
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: Text('Réessayer',
              style: GoogleFonts.poppins(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ]),
    ),
  );

  // ── Statistiques ─────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Container(
      color: AppColors.green,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(children: [
        _statBadge('En attente',
            _countByStatut('CREE') + _countByStatut('CONFIRMEE'),
            AppColors.amberLight, AppColors.amber),
        const SizedBox(width: 8),
        _statBadge('En cours', _countByStatut('EN_COURS'),
            const Color(0xFFFFF3E0), AppColors.amber),
        const SizedBox(width: 8),
        _statBadge('Paiement', _countByStatut('ATTENTE_PAIEMENT'),
            const Color(0xFFFFF8F0), Colors.orange),
        const SizedBox(width: 8),
        _statBadge('Clôturées', _countByStatut('CLOTUREE'),
            AppColors.greenLight, AppColors.green),
      ]),
    );
  }

  Widget _statBadge(String label, int count, Color bg, Color fg) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('$count', style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: fg),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  // ── Chips de filtre ───────────────────────────────────────────────────────
  Widget _buildFiltres() => Container(
    height: 48,
    color: Colors.white,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filtres.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filtres[i];
        final sel = f == _filtreActif;
        return GestureDetector(
          onTap: () => setState(() => _filtreActif = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? AppColors.green : AppColors.greenLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(f, style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: sel ? Colors.white : AppColors.green,
            )),
          ),
        );
      },
    ),
  );

  // ── Liste commandes ───────────────────────────────────────────────────────
  Widget _buildListe() {
    final liste = _commandesFiltrees;
    if (liste.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 56,
            color: AppColors.textSecond.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text('Aucune commande', style: GoogleFonts.poppins(
            color: AppColors.textSecond, fontSize: 15)),
      ]));
    }
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _loadCommandes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: liste.length,
        itemBuilder: (_, i) => _buildCommandeCard(liste[i]),
      ),
    );
  }

  // ── Carte commande ────────────────────────────────────────────────────────
  Widget _buildCommandeCard(Map<String, dynamic> cmd) {
    final statut = cmd['statut'] as String? ?? 'CREE';
    final etapes = _getCommandeEtapes(cmd); // Couche 2 opaque
    final etapeIdx = _getEtapeIndex(cmd);
    final total = etapes.length + 4; // CREE+CONFIRMEE+étapes+ATTENTE_PAIEMENT+CLOTUREE
    final nextStep = _getNextStep(cmd);
    final canAdvance = nextStep != null;
    final devisEnAttente = cmd['devisEnAttente'] == true;
    final isAttentePaiement = statut == 'ATTENTE_PAIEMENT';

    return GestureDetector(
      onTap: () => _ouvrirDetail(cmd),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── En-tête ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Commande #${cmd['id']}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(cmd['nomClient'] as String? ?? 'Client',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecond)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorStatut(statut).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_labelStatut(statut),
                    style: GoogleFonts.poppins(fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorStatut(statut))),
              ),
            ]),
          ),

          // ── Barre mini-étapes ─────────────────────────────────────────
          if (statut != 'ANNULEE')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildMiniEtapes(etapeIdx, total),
            ),

          // ── Étape Couche 2 courante ───────────────────────────────────
          if (statut == 'EN_COURS')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.amber)),
                const SizedBox(width: 6),
                Text(
                  _cap((cmd['etapeCourante'] as String? ?? 'En cours')
                      .replaceAll('_', ' ')),
                  style: GoogleFonts.poppins(fontSize: 12,
                      color: AppColors.amber, fontWeight: FontWeight.w500),
                ),
              ]),
            ),

          // ── Bandeau devis en attente ──────────────────────────────────
          if (devisEnAttente)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.purple.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, size: 14,
                      color: AppColors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('⏳ Devis envoyé — attente acceptation client',
                        style: GoogleFonts.poppins(fontSize: 11,
                            color: AppColors.purple,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ),

          // ── Bandeau attente paiement ──────────────────────────────────
          if (isAttentePaiement)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.payment_rounded, size: 14,
                      color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        '💳 Prestation terminée — en attente du paiement client',
                        style: GoogleFonts.poppins(fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),

          // ── Actions ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => _ouvrirDetail(cmd),
                icon: const Icon(Icons.visibility_outlined, size: 16,
                    color: AppColors.green),
                label: Text('Détails', style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.green)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              const Spacer(),

              // Bouton "Fixer prix" si exigeDevis et EN_COURS (et pas encore de devis)
              if (statut == 'EN_COURS' && _exigeDevis && !devisEnAttente)
                TextButton.icon(
                  onPressed: () => _showFixerPrixDialog(cmd),
                  icon: const Icon(Icons.attach_money, size: 15,
                      color: Colors.orange),
                  label: Text('Fixer prix', style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.orange,
                      fontWeight: FontWeight.w500)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),

              // Bouton confirmer paiement reçu (ATTENTE_PAIEMENT)
              if (isAttentePaiement)
                ElevatedButton.icon(
                  onPressed: () => _confirmerPaiementRecu(cmd),
                  icon: const Icon(Icons.verified_outlined, size: 15,
                      color: Colors.white),
                  label: Text('Confirmer paiement', style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.white,
                      fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                ),

              // Bouton standard pour les autres transitions
              if (canAdvance && !isAttentePaiement)
                ElevatedButton(
                  onPressed: () => _avancerStatut(cmd),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    elevation: 0,
                  ),
                  child: Text(_labelBouton(cmd),
                      style: GoogleFonts.poppins(fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  // Barre de progression miniature
  Widget _buildMiniEtapes(int currentIdx, int total) => Row(
    children: List.generate(total, (i) {
      final done = currentIdx >= 0 && i <= currentIdx;
      final current = i == currentIdx;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          height: 4,
          decoration: BoxDecoration(
            color: done
                ? (current ? AppColors.amber : AppColors.green)
                : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }),
  );
}