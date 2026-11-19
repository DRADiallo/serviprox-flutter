// lib/features/client/fiche_prestataire_screen.dart
//
// Fiche détaillée d'un prestataire (pressing, coiffure, réparation…)
// Tout le contenu vient de l'objet `prestataire` (API) — aucun switch(typeService)
// Tabs: Prestations | Informations
// ─────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/commande/nouvelle_commande_screen.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';


class FichePrestataireScreen extends StatefulWidget {
  final Map<String, dynamic> prestataire;

  const FichePrestataireScreen({super.key, required this.prestataire});

  @override
  State<FichePrestataireScreen> createState() =>
      _FichePrestataireScreenState();
}

class _FichePrestataireScreenState
    extends State<FichePrestataireScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;

  // Config chargée depuis /api/prestataire/config/{id}
  Map<String, dynamic> _config = {};
  bool _configLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  /// Charge la configuration du prestataire (prestations, options, modes dépôt)
  Future<void> _loadConfig() async {
    final id = widget.prestataire['id'];
    if (id == null) {
      if (mounted) setState(() => _configLoading = false);
      return;
    }
    try {
      final token = await AuthStorage.getToken();
      final uri = Uri.parse('${ApiConstants.prestataireConfig}/$id');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _config = data;
          _configLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _configLoading = false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────

  Map<String, dynamic> get _p => widget.prestataire;

  String _str(String key) => _p[key]?.toString() ?? '';

  bool get _disponible => _p['disponible'] as bool? ?? true;

  String get _nom =>
      _str('nomCommercial').isNotEmpty ? _str('nomCommercial') : 'Prestataire';

  num get _note => (_p['moyenneNotes'] ?? _p['note'] ?? 0) as num;
  num get _nbAvis =>
      (_p['nombreAvis'] ?? _p['nbAvis'] ?? 0) as num;

  /// Emoji du prestataire (API ou fallback cosmétique)
  String get _icone {
    final i = _p['icone'] ?? _p['emoji'];
    if (i != null && i.toString().isNotEmpty) return i.toString();
    const map = {
      'pressing':   '🧺',
      'reparation': '🔧',
      'coiffure':   '💇',
      'soins':      '💆',
    };
    return map[_str('typeService').toLowerCase()] ?? '🏪';
  }

  /// Prestations depuis la config chargée (prestationsAjoutees) ou l'API (typesPrestation)
  List<Map<String, dynamic>> get _prestations {
    // 1) Depuis la config chargée — backend retourne une String JSON
    final fromConfig = _config['prestationsAjoutees'];
    if (fromConfig != null) {
      try {
        List items = fromConfig is String
            ? (jsonDecode(fromConfig) as List)
            : (fromConfig as List);
        final result = items
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    // 2) Fallback sur les données passées depuis la liste
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

  /// Options activées (express, collecte…)
  Map<String, dynamic> get _opts {
    // Depuis la config chargée en priorité
    final fromConfig = _config['optionsActives'];
    if (fromConfig != null) {
      try {
        if (fromConfig is Map) return fromConfig.cast<String, dynamic>();
        if (fromConfig is String && fromConfig.isNotEmpty) {
          return (jsonDecode(fromConfig) as Map).cast<String, dynamic>();
        }
      } catch (_) {}
    }
    try {
      final o = _p['optionsActives'];
      if (o is Map) return o.cast<String, dynamic>();
      if (o is String && o.isNotEmpty) {
        return (jsonDecode(o) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return {};
  }

  /// Modes de dépôt effectifs depuis l'API
  List<String> get _modesDepot {
    // Depuis la config chargée en priorité (modesDepotAcceptes)
    final fromConfig = _config['modesDepotAcceptes'];
    if (fromConfig != null) {
      try {
        List items = fromConfig is String
            ? (jsonDecode(fromConfig) as List)
            : (fromConfig as List);
        final result = items.map((e) => e.toString()).toList();
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    try {
      final m = _p['modesDepotEffectifs'];
      if (m is List) {
        return m.map((e) => e.toString()).toList();
      }
      if (m is String && m.isNotEmpty) {
        return (jsonDecode(m) as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}

    // Fallback basé sur avecAgent
    final avecAgent = (_config['avecAgent'] ?? _p['avecAgent']) as bool? ?? false;
    return [
      'Dépôt atelier',
      if (avecAgent) 'Collecte à domicile',
    ];
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Hero AppBar ──────────────────────────────────
          _buildHero(),

          // ── Tabs ─────────────────────────────────────────
          _buildTabBar(),

          // ── Contenu ──────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildTabPrestations(),
                _buildTabInfos(),
              ],
            ),
          ),

          // ── Bouton bas ───────────────────────────────────
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 14, right: 14, bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton retour
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white, size: 16,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Avatar + nom + badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(_icone,
                    style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge dispo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _disponible
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.red.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _disponible
                            ? 'Ouvert · Ferme à 20h'
                            : 'Fermé',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Nom
                    Text(_nom,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Note + zone
                    Row(
                      children: [
                        if (_note > 0) ...[
                          const Icon(Icons.star_rounded,
                              color: AppColors.amber, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            '${_note.toStringAsFixed(1)} (${_nbAvis.toInt()} avis)',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (_str('zoneCouverture').isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white70, size: 11),
                          const SizedBox(width: 2),
                          Text(
                            _str('zoneCouverture'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TabBar ────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabs,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecond,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        tabs: const [
          Tab(text: 'Prestations'),
          Tab(text: 'Informations'),
        ],
      ),
    );
  }

  // ── Tab Prestations ───────────────────────────────────────
  Widget _buildTabPrestations() {
    // Chargement en cours
    if (_configLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final prestations = _prestations;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Tarifs depuis l'API
        if (prestations.isNotEmpty)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Tarifs', subtitle: 'depuis la config API'),
                ...prestations.map((p) => _prestationRow(p)).toList(),
              ],
            ),
          ),

        if (prestations.isEmpty)
          _card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aucune prestation configurée',
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Modes de dépôt
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🚗 Modes de dépôt',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              ..._modesDepot.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(m,
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
              )).toList(),

              // Badge Express
              if (_opts['express'] == true) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.bolt_outlined,
                        color: AppColors.amber, size: 14),
                    const SizedBox(width: 6),
                    Text('Express disponible',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber,
                      )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab Informations ──────────────────────────────────────
  Widget _buildTabInfos() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          child: Column(
            children: [
              _infoRow(Icons.location_on_outlined,
                  _str('adresse').isNotEmpty
                      ? _str('adresse')
                      : '${_str('zoneCouverture')} · Sénégal'),
              const Divider(height: 1, color: AppColors.border),
              _infoRow(Icons.access_time_outlined, 'Lun–Sam : 7h00 – 20h00'),
              const Divider(height: 1, color: AppColors.border),
              _infoRow(Icons.phone_outlined,
                  _str('telephone').isNotEmpty
                      ? _str('telephone')
                      : 'Non renseigné'),
            ],
          ),
        ),

        if (_str('description').isNotEmpty) ...[
          const SizedBox(height: 8),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('À propos'),
                Text(
                  _str('description'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecond,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 11, 12, MediaQuery.of(context).padding.bottom + 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _disponible
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NouvelleCommandeScreen(prestataire: _p),
                    ),
                  )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _disponible ? AppColors.primary : AppColors.border,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            _disponible
                ? 'Commander chez ce prestataire'
                : 'Prestataire fermé',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _sectionTitle(String label, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _prestationRow(Map<String, dynamic> p) {
    final nom     = p['nom']?.toString() ?? p['label']?.toString() ?? '—';
    final prix    = p['prix'];
    final unite   = p['unite']?.toString() ?? 'pièce';
    final prixStr = prix != null
        ? '${(prix as num).toInt()} FCFA / $unite'
        : 'Sur devis';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(nom,
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
              ),
              Text(prixStr,
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
              style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
















// // fiche_prestataire_screen.dart
// // Fiche détail d'un prestataire — GÉNÉRIQUE pour tous types de services.
// // Charge la config depuis l'API : typesPrestation, champsCommande, etapesEffectives.
// // => ZÉRO if(typeService) dans ce fichier.

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class Fiche_prestataires_screen extends StatefulWidget {
//   final Map<String, dynamic> prestataire;
//   final Color themeColor;

//   const Fiche_prestataires_screen({
//     super.key,
//     required this.prestataire,
//     required this.themeColor,
//   });

//   @override
//   State<Fiche_prestataires_screen> createState() => _Fiche_prestataires_screenState();
// }

// class _Fiche_prestataires_screenState extends State<Fiche_prestataires_screen>
//     with SingleTickerProviderStateMixin {
//   static const String _baseUrl = 'http://localhost:7090';

//   late TabController _tabController;
//   Map<String, dynamic> _config = {};
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadConfig();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadConfig() async {
//     final id = widget.prestataire['id'];
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/$id'),
//       );
//       if (res.statusCode == 200) {
//         setState(() {
//           _config = jsonDecode(res.body) as Map<String, dynamic>;
//           _loading = false;
//         });
//       } else {
//         setState(() { _config = _demoConfig(); _loading = false; });
//       }
//     } catch (_) {
//       setState(() { _config = _demoConfig(); _loading = false; });
//     }
//   }

//   Map<String, dynamic> _demoConfig() => {
//     'typesPrestation': [
//       {'id': 1, 'nom': 'Chemise', 'prixUnitaire': 500, 'unite': 'pièce'},
//       {'id': 2, 'nom': 'Pantalon', 'prixUnitaire': 800, 'unite': 'pièce'},
//       {'id': 3, 'nom': 'Robe / Boubou', 'prixUnitaire': 1500, 'unite': 'pièce'},
//       {'id': 4, 'nom': 'Costume complet', 'prixUnitaire': 3000, 'unite': 'ensemble'},
//       {'id': 5, 'nom': 'Couverture / Drap', 'prixUnitaire': 1200, 'unite': 'pièce'},
//     ],
//     'champsCommande': [
//       {
//         'id': 1,
//         'label': 'Mode de dépôt',
//         'type': 'LIST',
//         'options': ['🚗 Collecte à domicile', '🏪 Dépôt en atelier'],
//         'requis': true,
//       },
//       {
//         'id': 2,
//         'label': 'Adresse de collecte',
//         'type': 'TEXT',
//         'placeholder': 'Ex: Quartier Tilène, rue 14',
//         'requis': false,
//       },
//     ],
//     'avecAgent': false,
//     'horaires': 'Lun–Sam : 8h–20h · Dim : 9h–14h',
//     'adresse': 'Quartier Liberté, Dakar',
//   };

//   List<Map<String, dynamic>> get _typesPrestation =>
//       (_config['typesPrestation'] as List? ?? []).cast<Map<String, dynamic>>();

//   List<Map<String, dynamic>> get _champsCommande =>
//       (_config['champsCommande'] as List? ?? []).cast<Map<String, dynamic>>();

//   /// Extrait les options du champ de type LIST pour la section "Modes de dépôt"
//   List<String> get _modesDepot {
//     for (final c in _champsCommande) {
//       if ((c['type'] as String? ?? '') == 'LIST') {
//         return (c['options'] as List? ?? []).cast<String>();
//       }
//     }
//     return [];
//   }

//   @override
//   Widget build(BuildContext context) {
//     final p = widget.prestataire;
//     final nom = p['nom'] as String? ?? '';
//     final description = p['description'] as String? ?? '';
//     final note = (p['note'] as num? ?? 0.0).toDouble();
//     final nAvis = p['nombreAvis'] as int? ?? 0;
//     final distance = (p['distanceKm'] as num? ?? 0.0).toDouble();
//     final ouvert = p['ouvert'] as bool? ?? false;
//     final initiale = (p['avatarInitiale'] as String?) ?? (nom.isNotEmpty ? nom[0] : '?');

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       body: NestedScrollView(
//         headerSliverBuilder: (context, innerBoxIsScrolled) => [
//           SliverAppBar(
//             expandedHeight: 220,
//             pinned: true,
//             backgroundColor: widget.themeColor,
//             foregroundColor: Colors.white,
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.share_outlined),
//                 onPressed: () {},
//               ),
//             ],
//             flexibleSpace: FlexibleSpaceBar(
//               background: _buildHero(
//                 nom, description, note, nAvis, distance, ouvert, initiale),
//             ),
//             bottom: TabBar(
//               controller: _tabController,
//               indicatorColor: Colors.white,
//               indicatorWeight: 3,
//               labelColor: Colors.white,
//               unselectedLabelColor: Colors.white70,
//               labelStyle: const TextStyle(
//                 fontWeight: FontWeight.w700,
//                 fontSize: 14,
//               ),
//               tabs: const [
//                 Tab(text: 'Prestations'),
//                 Tab(text: 'Informations'),
//               ],
//             ),
//           ),
//         ],
//         body: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : TabBarView(
//                 controller: _tabController,
//                 children: [
//                   _buildTabPrestations(),
//                   _buildTabInformations(),
//                 ],
//               ),
//       ),
//       bottomNavigationBar: _buildFooter(nom),
//     );
//   }

//   Widget _buildHero(String nom, String description, double note, int nAvis,
//       double distance, bool ouvert, String initiale) {
//     return Container(
//       color: widget.themeColor,
//       padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Center(
//                   child: Text(
//                     initiale.toUpperCase(),
//                     style: const TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nom,
//                             style: const TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 3),
//                           decoration: BoxDecoration(
//                             color: ouvert
//                                 ? const Color(0xFF16A34A)
//                                 : const Color(0xFFDC2626),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             ouvert ? '● Ouvert' : '● Fermé',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       description,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withValues(alpha: 0.85),
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.star_rounded,
//                             size: 14, color: Color(0xFFFBBF24)),
//                         Text(
//                           ' ${note.toStringAsFixed(1)}',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.white,
//                           ),
//                         ),
//                         Text(
//                           ' ($nAvis avis)',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.7),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Icon(Icons.location_on_outlined,
//                             size: 13, color: Colors.white70),
//                         Text(
//                           ' ${distance.toStringAsFixed(1)} km',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.85),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTabPrestations() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         // Section typesPrestation
//         _buildSectionTitle(' Tarifs des prestations'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             children: _typesPrestation.asMap().entries.map((entry) {
//               final idx = entry.key;
//               final tp = entry.value;
//               final isLast = idx == _typesPrestation.length - 1;
//               final prix = tp['prixUnitaire'] as int? ?? 0;
//               final unite = tp['unite'] as String? ?? 'pièce';
//               final nomPresta = tp['nom'] as String? ?? '';
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 14),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nomPresta,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w500,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ),
//                         RichText(
//                           text: TextSpan(
//                             children: [
//                               TextSpan(
//                                 text: '$prix FCFA',
//                                 style: TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w800,
//                                   color: widget.themeColor,
//                                 ),
//                               ),
//                               TextSpan(
//                                 text: ' / $unite',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFF94A3B8),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (!isLast)
//                     const Divider(height: 1, indent: 16, endIndent: 16),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),

//         // Section modes (depuis champsCommande LIST)
//         if (_modesDepot.isNotEmpty) ...[
//           const SizedBox(height: 24),
//           _buildSectionTitle('📦 Modes disponibles'),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: _modesDepot.asMap().entries.map((entry) {
//                 final idx = entry.key;
//                 final mode = entry.value;
//                 final isLast = idx == _modesDepot.length - 1;
//                 return Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 14),
//                       child: Row(
//                         children: [
//                           Icon(Icons.check_circle_outline_rounded,
//                               size: 18, color: widget.themeColor),
//                           const SizedBox(width: 10),
//                           Text(
//                             mode,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (!isLast)
//                       const Divider(height: 1, indent: 16, endIndent: 16),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildTabInformations() {
//     final horaires = _config['horaires'] as String? ?? 'Non renseigné';
//     final adresse = _config['adresse'] as String? ??
//         widget.prestataire['adresse'] as String? ?? 'Non renseignée';

//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         _buildInfoCard(
//           icon: Icons.location_on_rounded,
//           title: 'Adresse',
//           value: adresse,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.schedule_rounded,
//           title: 'Horaires',
//           value: horaires,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.delivery_dining_rounded,
//           title: 'Délai moyen',
//           value: '${widget.prestataire['delaiHeures'] ?? 24} heures',
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.support_agent_rounded,
//           title: 'Agent disponible',
//           value: (_config['avecAgent'] as bool? ?? false) ? 'Oui' : 'Non',
//         ),
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildInfoCard({
//     required IconData icon,
//     required String title,
//     required String value,
//   }) {
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
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: widget.themeColor.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, size: 20, color: widget.themeColor),
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF94A3B8),
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Color(0xFF1E293B),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w700,
//         color: Color(0xFF1E293B),
//       ),
//     );
//   }

//   Widget _buildFooter(String nomPrestataire) {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 12,
//         bottom: MediaQuery.of(context).padding.bottom + 12,
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
//       child: ElevatedButton(
//         onPressed: () {
//           Navigator.pushNamed(
//             context,
//             '/nouvelle-commande',
//             arguments: {
//               'prestataire': widget.prestataire,
//               'config': _config,
//               'themeColor': widget.themeColor,
//             },
//           );
//         },
//         style: ElevatedButton.styleFrom(
//           backgroundColor: widget.themeColor,
//           foregroundColor: Colors.white,
//           minimumSize: const Size(double.infinity, 52),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           elevation: 0,
//         ),
//         child: Text(
//           'Commander chez $nomPrestataire',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ),
//     );
//   }
// }
















// // fiche_prestataire_screen.dart
// // Fiche détail d'un prestataire — GÉNÉRIQUE pour tous types de services.
// // Charge la config depuis l'API : typesPrestation, champsCommande, etapesEffectives.
// // => ZÉRO if(typeService) dans ce fichier.

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class Fiche_prestataires_screen extends StatefulWidget {
//   final Map<String, dynamic> prestataire;
//   final Color themeColor;

//   const Fiche_prestataires_screen({
//     super.key,
//     required this.prestataire,
//     required this.themeColor,
//   });

//   @override
//   State<Fiche_prestataires_screen> createState() => _Fiche_prestataires_screenState();
// }

// class _Fiche_prestataires_screenState extends State<Fiche_prestataires_screen>
//     with SingleTickerProviderStateMixin {
//   static const String _baseUrl = 'http://localhost:7090';

//   late TabController _tabController;
//   Map<String, dynamic> _config = {};
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadConfig();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadConfig() async {
//     final id = widget.prestataire['id'];
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/$id'),
//       );
//       if (res.statusCode == 200) {
//         setState(() {
//           _config = jsonDecode(res.body) as Map<String, dynamic>;
//           _loading = false;
//         });
//       } else {
//         setState(() { _config = _demoConfig(); _loading = false; });
//       }
//     } catch (_) {
//       setState(() { _config = _demoConfig(); _loading = false; });
//     }
//   }

//   Map<String, dynamic> _demoConfig() => {
//     'typesPrestation': [
//       {'id': 1, 'nom': 'Chemise', 'prixUnitaire': 500, 'unite': 'pièce'},
//       {'id': 2, 'nom': 'Pantalon', 'prixUnitaire': 800, 'unite': 'pièce'},
//       {'id': 3, 'nom': 'Robe / Boubou', 'prixUnitaire': 1500, 'unite': 'pièce'},
//       {'id': 4, 'nom': 'Costume complet', 'prixUnitaire': 3000, 'unite': 'ensemble'},
//       {'id': 5, 'nom': 'Couverture / Drap', 'prixUnitaire': 1200, 'unite': 'pièce'},
//     ],
//     'champsCommande': [
//       {
//         'id': 1,
//         'label': 'Mode de dépôt',
//         'type': 'LIST',
//         'options': ['🚗 Collecte à domicile', '🏪 Dépôt en atelier'],
//         'requis': true,
//       },
//       {
//         'id': 2,
//         'label': 'Adresse de collecte',
//         'type': 'TEXT',
//         'placeholder': 'Ex: Quartier Tilène, rue 14',
//         'requis': false,
//       },
//     ],
//     'avecAgent': false,
//     'horaires': 'Lun–Sam : 8h–20h · Dim : 9h–14h',
//     'adresse': 'Quartier Liberté, Dakar',
//   };

//   List<Map<String, dynamic>> get _typesPrestation =>
//       (_config['typesPrestation'] as List? ?? []).cast<Map<String, dynamic>>();

//   List<Map<String, dynamic>> get _champsCommande =>
//       (_config['champsCommande'] as List? ?? []).cast<Map<String, dynamic>>();

//   /// Extrait les options du champ de type LIST pour la section "Modes de dépôt"
//   List<String> get _modesDepot {
//     for (final c in _champsCommande) {
//       if ((c['type'] as String? ?? '') == 'LIST') {
//         return (c['options'] as List? ?? []).cast<String>();
//       }
//     }
//     return [];
//   }

//   @override
//   Widget build(BuildContext context) {
//     final p = widget.prestataire;
//     final nom = p['nom'] as String? ?? '';
//     final description = p['description'] as String? ?? '';
//     final note = (p['note'] as num? ?? 0.0).toDouble();
//     final nAvis = p['nombreAvis'] as int? ?? 0;
//     final distance = (p['distanceKm'] as num? ?? 0.0).toDouble();
//     final ouvert = p['ouvert'] as bool? ?? false;
//     final initiale = (p['avatarInitiale'] as String?) ?? (nom.isNotEmpty ? nom[0] : '?');

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       body: NestedScrollView(
//         headerSliverBuilder: (context, innerBoxIsScrolled) => [
//           SliverAppBar(
//             expandedHeight: 220,
//             pinned: true,
//             backgroundColor: widget.themeColor,
//             foregroundColor: Colors.white,
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.share_outlined),
//                 onPressed: () {},
//               ),
//             ],
//             flexibleSpace: FlexibleSpaceBar(
//               background: _buildHero(
//                 nom, description, note, nAvis, distance, ouvert, initiale),
//             ),
//             bottom: TabBar(
//               controller: _tabController,
//               indicatorColor: Colors.white,
//               indicatorWeight: 3,
//               labelColor: Colors.white,
//               unselectedLabelColor: Colors.white70,
//               labelStyle: const TextStyle(
//                 fontWeight: FontWeight.w700,
//                 fontSize: 14,
//               ),
//               tabs: const [
//                 Tab(text: 'Prestations'),
//                 Tab(text: 'Informations'),
//               ],
//             ),
//           ),
//         ],
//         body: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : TabBarView(
//                 controller: _tabController,
//                 children: [
//                   _buildTabPrestations(),
//                   _buildTabInformations(),
//                 ],
//               ),
//       ),
//       bottomNavigationBar: _buildFooter(nom),
//     );
//   }

//   Widget _buildHero(String nom, String description, double note, int nAvis,
//       double distance, bool ouvert, String initiale) {
//     return Container(
//       color: widget.themeColor,
//       padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Center(
//                   child: Text(
//                     initiale.toUpperCase(),
//                     style: const TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nom,
//                             style: const TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 3),
//                           decoration: BoxDecoration(
//                             color: ouvert
//                                 ? const Color(0xFF16A34A)
//                                 : const Color(0xFFDC2626),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             ouvert ? '● Ouvert' : '● Fermé',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       description,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withValues(alpha: 0.85),
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.star_rounded,
//                             size: 14, color: Color(0xFFFBBF24)),
//                         Text(
//                           ' ${note.toStringAsFixed(1)}',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.white,
//                           ),
//                         ),
//                         Text(
//                           ' ($nAvis avis)',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.7),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Icon(Icons.location_on_outlined,
//                             size: 13, color: Colors.white70),
//                         Text(
//                           ' ${distance.toStringAsFixed(1)} km',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.85),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTabPrestations() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         // Section typesPrestation
//         _buildSectionTitle(' Tarifs des prestations'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             children: _typesPrestation.asMap().entries.map((entry) {
//               final idx = entry.key;
//               final tp = entry.value;
//               final isLast = idx == _typesPrestation.length - 1;
//               final prix = tp['prixUnitaire'] as int? ?? 0;
//               final unite = tp['unite'] as String? ?? 'pièce';
//               final nomPresta = tp['nom'] as String? ?? '';
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 14),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nomPresta,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w500,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ),
//                         RichText(
//                           text: TextSpan(
//                             children: [
//                               TextSpan(
//                                 text: '$prix FCFA',
//                                 style: TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w800,
//                                   color: widget.themeColor,
//                                 ),
//                               ),
//                               TextSpan(
//                                 text: ' / $unite',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFF94A3B8),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (!isLast)
//                     const Divider(height: 1, indent: 16, endIndent: 16),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),

//         // Section modes (depuis champsCommande LIST)
//         if (_modesDepot.isNotEmpty) ...[
//           const SizedBox(height: 24),
//           _buildSectionTitle('📦 Modes disponibles'),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: _modesDepot.asMap().entries.map((entry) {
//                 final idx = entry.key;
//                 final mode = entry.value;
//                 final isLast = idx == _modesDepot.length - 1;
//                 return Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 14),
//                       child: Row(
//                         children: [
//                           Icon(Icons.check_circle_outline_rounded,
//                               size: 18, color: widget.themeColor),
//                           const SizedBox(width: 10),
//                           Text(
//                             mode,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (!isLast)
//                       const Divider(height: 1, indent: 16, endIndent: 16),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildTabInformations() {
//     final horaires = _config['horaires'] as String? ?? 'Non renseigné';
//     final adresse = _config['adresse'] as String? ??
//         widget.prestataire['adresse'] as String? ?? 'Non renseignée';

//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         _buildInfoCard(
//           icon: Icons.location_on_rounded,
//           title: 'Adresse',
//           value: adresse,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.schedule_rounded,
//           title: 'Horaires',
//           value: horaires,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.delivery_dining_rounded,
//           title: 'Délai moyen',
//           value: '${widget.prestataire['delaiHeures'] ?? 24} heures',
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.support_agent_rounded,
//           title: 'Agent disponible',
//           value: (_config['avecAgent'] as bool? ?? false) ? 'Oui' : 'Non',
//         ),
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildInfoCard({
//     required IconData icon,
//     required String title,
//     required String value,
//   }) {
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
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: widget.themeColor.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, size: 20, color: widget.themeColor),
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF94A3B8),
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Color(0xFF1E293B),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w700,
//         color: Color(0xFF1E293B),
//       ),
//     );
//   }

//   Widget _buildFooter(String nomPrestataire) {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 12,
//         bottom: MediaQuery.of(context).padding.bottom + 12,
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
//       child: ElevatedButton(
//         onPressed: () {
//           Navigator.pushNamed(
//             context,
//             '/nouvelle-commande',
//             arguments: {
//               'prestataire': widget.prestataire,
//               'config': _config,
//               'themeColor': widget.themeColor,
//             },
//           );
//         },
//         style: ElevatedButton.styleFrom(
//           backgroundColor: widget.themeColor,
//           foregroundColor: Colors.white,
//           minimumSize: const Size(double.infinity, 52),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           elevation: 0,
//         ),
//         child: Text(
//           'Commander chez $nomPrestataire',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ),
//     );
//   }
// }
















// // fiche_prestataire_screen.dart
// // Fiche détail d'un prestataire — GÉNÉRIQUE pour tous types de services.
// // Charge la config depuis l'API : typesPrestation, champsCommande, etapesEffectives.
// // => ZÉRO if(typeService) dans ce fichier.

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class Fiche_prestataires_screen extends StatefulWidget {
//   final Map<String, dynamic> prestataire;
//   final Color themeColor;

//   const Fiche_prestataires_screen({
//     super.key,
//     required this.prestataire,
//     required this.themeColor,
//   });

//   @override
//   State<Fiche_prestataires_screen> createState() => _Fiche_prestataires_screenState();
// }

// class _Fiche_prestataires_screenState extends State<Fiche_prestataires_screen>
//     with SingleTickerProviderStateMixin {
//   static const String _baseUrl = 'http://localhost:7090';

//   late TabController _tabController;
//   Map<String, dynamic> _config = {};
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _loadConfig();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadConfig() async {
//     final id = widget.prestataire['id'];
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/$id'),
//       );
//       if (res.statusCode == 200) {
//         setState(() {
//           _config = jsonDecode(res.body) as Map<String, dynamic>;
//           _loading = false;
//         });
//       } else {
//         setState(() { _config = _demoConfig(); _loading = false; });
//       }
//     } catch (_) {
//       setState(() { _config = _demoConfig(); _loading = false; });
//     }
//   }

//   Map<String, dynamic> _demoConfig() => {
//     'typesPrestation': [
//       {'id': 1, 'nom': 'Chemise', 'prixUnitaire': 500, 'unite': 'pièce'},
//       {'id': 2, 'nom': 'Pantalon', 'prixUnitaire': 800, 'unite': 'pièce'},
//       {'id': 3, 'nom': 'Robe / Boubou', 'prixUnitaire': 1500, 'unite': 'pièce'},
//       {'id': 4, 'nom': 'Costume complet', 'prixUnitaire': 3000, 'unite': 'ensemble'},
//       {'id': 5, 'nom': 'Couverture / Drap', 'prixUnitaire': 1200, 'unite': 'pièce'},
//     ],
//     'champsCommande': [
//       {
//         'id': 1,
//         'label': 'Mode de dépôt',
//         'type': 'LIST',
//         'options': ['🚗 Collecte à domicile', '🏪 Dépôt en atelier'],
//         'requis': true,
//       },
//       {
//         'id': 2,
//         'label': 'Adresse de collecte',
//         'type': 'TEXT',
//         'placeholder': 'Ex: Quartier Tilène, rue 14',
//         'requis': false,
//       },
//     ],
//     'avecAgent': false,
//     'horaires': 'Lun–Sam : 8h–20h · Dim : 9h–14h',
//     'adresse': 'Quartier Liberté, Dakar',
//   };

//   List<Map<String, dynamic>> get _typesPrestation =>
//       (_config['typesPrestation'] as List? ?? []).cast<Map<String, dynamic>>();

//   List<Map<String, dynamic>> get _champsCommande =>
//       (_config['champsCommande'] as List? ?? []).cast<Map<String, dynamic>>();

//   /// Extrait les options du champ de type LIST pour la section "Modes de dépôt"
//   List<String> get _modesDepot {
//     for (final c in _champsCommande) {
//       if ((c['type'] as String? ?? '') == 'LIST') {
//         return (c['options'] as List? ?? []).cast<String>();
//       }
//     }
//     return [];
//   }

//   @override
//   Widget build(BuildContext context) {
//     final p = widget.prestataire;
//     final nom = p['nom'] as String? ?? '';
//     final description = p['description'] as String? ?? '';
//     final note = (p['note'] as num? ?? 0.0).toDouble();
//     final nAvis = p['nombreAvis'] as int? ?? 0;
//     final distance = (p['distanceKm'] as num? ?? 0.0).toDouble();
//     final ouvert = p['ouvert'] as bool? ?? false;
//     final initiale = (p['avatarInitiale'] as String?) ?? (nom.isNotEmpty ? nom[0] : '?');

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       body: NestedScrollView(
//         headerSliverBuilder: (context, innerBoxIsScrolled) => [
//           SliverAppBar(
//             expandedHeight: 220,
//             pinned: true,
//             backgroundColor: widget.themeColor,
//             foregroundColor: Colors.white,
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.share_outlined),
//                 onPressed: () {},
//               ),
//             ],
//             flexibleSpace: FlexibleSpaceBar(
//               background: _buildHero(
//                 nom, description, note, nAvis, distance, ouvert, initiale),
//             ),
//             bottom: TabBar(
//               controller: _tabController,
//               indicatorColor: Colors.white,
//               indicatorWeight: 3,
//               labelColor: Colors.white,
//               unselectedLabelColor: Colors.white70,
//               labelStyle: const TextStyle(
//                 fontWeight: FontWeight.w700,
//                 fontSize: 14,
//               ),
//               tabs: const [
//                 Tab(text: 'Prestations'),
//                 Tab(text: 'Informations'),
//               ],
//             ),
//           ),
//         ],
//         body: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : TabBarView(
//                 controller: _tabController,
//                 children: [
//                   _buildTabPrestations(),
//                   _buildTabInformations(),
//                 ],
//               ),
//       ),
//       bottomNavigationBar: _buildFooter(nom),
//     );
//   }

//   Widget _buildHero(String nom, String description, double note, int nAvis,
//       double distance, bool ouvert, String initiale) {
//     return Container(
//       color: widget.themeColor,
//       padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Center(
//                   child: Text(
//                     initiale.toUpperCase(),
//                     style: const TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nom,
//                             style: const TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 3),
//                           decoration: BoxDecoration(
//                             color: ouvert
//                                 ? const Color(0xFF16A34A)
//                                 : const Color(0xFFDC2626),
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             ouvert ? '● Ouvert' : '● Fermé',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       description,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withValues(alpha: 0.85),
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.star_rounded,
//                             size: 14, color: Color(0xFFFBBF24)),
//                         Text(
//                           ' ${note.toStringAsFixed(1)}',
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.white,
//                           ),
//                         ),
//                         Text(
//                           ' ($nAvis avis)',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.7),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Icon(Icons.location_on_outlined,
//                             size: 13, color: Colors.white70),
//                         Text(
//                           ' ${distance.toStringAsFixed(1)} km',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.white.withValues(alpha: 0.85),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTabPrestations() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         // Section typesPrestation
//         _buildSectionTitle(' Tarifs des prestations'),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Column(
//             children: _typesPrestation.asMap().entries.map((entry) {
//               final idx = entry.key;
//               final tp = entry.value;
//               final isLast = idx == _typesPrestation.length - 1;
//               final prix = tp['prixUnitaire'] as int? ?? 0;
//               final unite = tp['unite'] as String? ?? 'pièce';
//               final nomPresta = tp['nom'] as String? ?? '';
//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 14),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             nomPresta,
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w500,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ),
//                         RichText(
//                           text: TextSpan(
//                             children: [
//                               TextSpan(
//                                 text: '$prix FCFA',
//                                 style: TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w800,
//                                   color: widget.themeColor,
//                                 ),
//                               ),
//                               TextSpan(
//                                 text: ' / $unite',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFF94A3B8),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (!isLast)
//                     const Divider(height: 1, indent: 16, endIndent: 16),
//                 ],
//               );
//             }).toList(),
//           ),
//         ),

//         // Section modes (depuis champsCommande LIST)
//         if (_modesDepot.isNotEmpty) ...[
//           const SizedBox(height: 24),
//           _buildSectionTitle('📦 Modes disponibles'),
//           const SizedBox(height: 12),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: _modesDepot.asMap().entries.map((entry) {
//                 final idx = entry.key;
//                 final mode = entry.value;
//                 final isLast = idx == _modesDepot.length - 1;
//                 return Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 14),
//                       child: Row(
//                         children: [
//                           Icon(Icons.check_circle_outline_rounded,
//                               size: 18, color: widget.themeColor),
//                           const SizedBox(width: 10),
//                           Text(
//                             mode,
//                             style: const TextStyle(
//                               fontSize: 14,
//                               color: Color(0xFF1E293B),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (!isLast)
//                       const Divider(height: 1, indent: 16, endIndent: 16),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildTabInformations() {
//     final horaires = _config['horaires'] as String? ?? 'Non renseigné';
//     final adresse = _config['adresse'] as String? ??
//         widget.prestataire['adresse'] as String? ?? 'Non renseignée';

//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         _buildInfoCard(
//           icon: Icons.location_on_rounded,
//           title: 'Adresse',
//           value: adresse,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.schedule_rounded,
//           title: 'Horaires',
//           value: horaires,
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.delivery_dining_rounded,
//           title: 'Délai moyen',
//           value: '${widget.prestataire['delaiHeures'] ?? 24} heures',
//         ),
//         const SizedBox(height: 12),
//         _buildInfoCard(
//           icon: Icons.support_agent_rounded,
//           title: 'Agent disponible',
//           value: (_config['avecAgent'] as bool? ?? false) ? 'Oui' : 'Non',
//         ),
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildInfoCard({
//     required IconData icon,
//     required String title,
//     required String value,
//   }) {
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
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: widget.themeColor.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, size: 20, color: widget.themeColor),
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF94A3B8),
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Color(0xFF1E293B),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w700,
//         color: Color(0xFF1E293B),
//       ),
//     );
//   }

//   Widget _buildFooter(String nomPrestataire) {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 16,
//         right: 16,
//         top: 12,
//         bottom: MediaQuery.of(context).padding.bottom + 12,
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
//       child: ElevatedButton(
//         onPressed: () {
//           Navigator.pushNamed(
//             context,
//             '/nouvelle-commande',
//             arguments: {
//               'prestataire': widget.prestataire,
//               'config': _config,
//               'themeColor': widget.themeColor,
//             },
//           );
//         },
//         style: ElevatedButton.styleFrom(
//           backgroundColor: widget.themeColor,
//           foregroundColor: Colors.white,
//           minimumSize: const Size(double.infinity, 52),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           elevation: 0,
//         ),
//         child: Text(
//           'Commander chez $nomPrestataire',
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ),
//     );
//   }
// }