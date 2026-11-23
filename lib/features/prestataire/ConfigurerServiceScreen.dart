// ═══════════════════════════════════════════════════════
// configurer_service_screen_v2.dart
//
// RÔLE : Configuration du service en 3 onglets (maquette)
//
//   Onglet 1 — Prestations : liste des services + tarifs
//   Onglet 2 — Formulaire  : champs dynamiques (champsCommande)
//   Onglet 3 — Étapes      : workflow personnalisé du service
//
// BACKEND : POST /api/prestataire/config/{id}
// LOAD    : GET  /api/prestataire/config/{id}
//
// NOUVEAU FICHIER (v2) — rollback : supprimer ce fichier
// et revenir à ConfigurerServiceScreen dans prestataire_home_screen.dart
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

// ─────────────────────────────────────────────────────────────
// MODÈLES LOCAUX
// ─────────────────────────────────────────────────────────────

class _Prestation {
  TextEditingController nomCtrl;
  TextEditingController prixCtrl;
  String unite;
  _Prestation({String nom = '', String prix = '', this.unite = 'pièce'})
      : nomCtrl  = TextEditingController(text: nom),
        prixCtrl = TextEditingController(text: prix);
  void dispose() {
    nomCtrl.dispose();
    prixCtrl.dispose();
  }
}

class _ChampCommande {
  TextEditingController nomCtrl;
  String type;    // TEXT | NUMBER | LIST
  bool requis;
  List<String> options; // pour type LIST

  _ChampCommande({
    String nom       = '',
    this.type        = 'TEXT',
    this.requis      = true,
    List<String>? options,
  })  : nomCtrl  = TextEditingController(text: nom),
        options  = options ?? [];

  void dispose() => nomCtrl.dispose();

  Map<String, dynamic> toJson() => {
    'nom':     nomCtrl.text.trim(),
    'type':    type,
    'requis':  requis,
    if (type == 'LIST') 'options': options,
  };
}

// Étapes fixes du workflow (non éditables)
const List<String> _etapesFixees = ['CREE', 'CONFIRMEE', 'CLOTUREE'];

// ─────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────

class ConfigurerServiceScreenV2 extends StatefulWidget {
  const ConfigurerServiceScreenV2({super.key});

  @override
  State<ConfigurerServiceScreenV2> createState() =>
      _ConfigurerServiceScreenV2State();
}

class _ConfigurerServiceScreenV2State
    extends State<ConfigurerServiceScreenV2>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;

  // ── État général ──────────────────────────────────
  bool _isLoading = true;
  bool _isSaving  = false;
  int  _userId    = 0;
  String _typeService = '';

  // ── Zone de couverture ────────────────────────────
  final _zoneController = TextEditingController();

  // ── Onglet 1 : Prestations ────────────────────────
  final List<_Prestation> _prestations = [];

  // ── Options (Express / Collecte / Livraison) ──────
  bool _optionExpress   = false;
  bool _optionCollecte  = false;
  bool _optionLivraison = false;
  bool _avecAgent       = false;

  // ── Onglet 2 : Formulaire (champsCommande) ────────
  final List<_ChampCommande> _champs = [];

  // ── Onglet 3 : Étapes workflow ────────────────────
  // Étapes personnalisables (entre CONFIRMEE et CLOTUREE)
  final List<TextEditingController> _etapesCustom = [];

  // ─────────────────────────────────────────────────
  static const List<String> _unites = [
    'pièce', 'kg', 'heure', 'mètre', 'forfait', 'visite',
  ];

  // Étapes prédéfinies par cas métier
  static const Map<String, List<String>> _etapesPredef = {
    'PRESSING'   : ['EN_COLLECTE', 'EN_TRAITEMENT', 'EN_LIVRAISON'],
    'REPARATION' : ['DIAGNOSTIC', 'DEVIS_ENVOYE', 'EN_REPARATION'],
    'SOINS'      : ['PLANIFIEE', 'EN_INTERVENTION'],
  };

  // ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _zoneController.dispose();
    for (final p in _prestations) p.dispose();
    for (final c in _champs)      c.dispose();
    for (final e in _etapesCustom) e.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // CHARGEMENT
  // ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId       = await AuthStorage.getUserId();
    final typeStored   = await AuthStorage.getTypeService();
    _userId      = userId ?? 0;
    _typeService = typeStored;

    final token = await AuthStorage.getToken();
    if (token != null && _userId > 0) {
      await _loadConfigExistante(token);
    }

    // Pas de prestations → exemples par défaut
    if (_prestations.isEmpty) _chargerExemples(_typeService);

    // Pas d'étapes → prédef selon type
    if (_etapesCustom.isEmpty) _chargerEtapesPredef(_typeService);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadConfigExistante(String token) async {
    try {
      final uri = Uri.parse('${ApiConstants.prestataireConfig}/$_userId');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;
      final data = json.decode(res.body) as Map<String, dynamic>;

      // Type service
      final type = data['typeService'] as String? ?? '';
      if (type.isNotEmpty) {
        _typeService = type;
        await AuthStorage.saveTypeService(type);
      }

      // Zone
      _zoneController.text = data['zoneCouverture'] as String? ?? '';

      // avecAgent
      _avecAgent = data['avecAgent'] as bool? ?? false;

      // Options
      final optStr = data['optionsActives'] as String?;
      if (optStr != null && optStr.isNotEmpty) {
        try {
          final opts = json.decode(optStr) as Map<String, dynamic>;
          _optionExpress   = opts['express']   as bool? ?? false;
          _optionCollecte  = opts['collecte']  as bool? ?? false;
          _optionLivraison = opts['livraison'] as bool? ?? false;
        } catch (_) {}
      }

      // Prestations
      final prestStr = data['prestationsAjoutees'] as String?;
      if (prestStr != null && prestStr.isNotEmpty) {
        try {
          final list = json.decode(prestStr) as List<dynamic>;
          for (final p in list) {
            _prestations.add(_Prestation(
              nom:   p['nom']?.toString()   ?? '',
              prix:  p['prix']?.toString()  ?? '',
              unite: p['unite']?.toString() ?? 'pièce',
            ));
          }
        } catch (_) {}
      }

      // champsCommande (Onglet 2)
      final champsStr = data['champsCommande'] as String?;
      if (champsStr != null && champsStr.isNotEmpty) {
        try {
          final list = json.decode(champsStr) as List<dynamic>;
          for (final c in list) {
            _champs.add(_ChampCommande(
              nom:     c['nom']?.toString()  ?? '',
              type:    c['type']?.toString() ?? 'TEXT',
              requis:  c['requis'] as bool?  ?? true,
              options: (c['options'] as List?)?.map((e) => e.toString()).toList(),
            ));
          }
        } catch (_) {}
      }

      // Étapes personnalisées (Onglet 3)
      final etapesStr = data['etapesPersonnalisees'] as String?;
      if (etapesStr != null && etapesStr.isNotEmpty) {
        try {
          final list = json.decode(etapesStr) as List<dynamic>;
          // Filtrer les étapes fixes déjà présentes
          for (final e in list) {
            final etape = e.toString().toUpperCase();
            if (!_etapesFixees.contains(etape)) {
              _etapesCustom.add(TextEditingController(text: etape));
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // Première configuration
    }
  }

  void _chargerExemples(String type) {
    final Map<String, List<Map<String, String>>> exemples = {
      'pressing': [
        {'nom': 'Lavage kilo',    'prix': '500',  'unite': 'kg'},
        {'nom': 'Chemise',        'prix': '300',  'unite': 'pièce'},
        {'nom': 'Boubou/Bazin',   'prix': '2000', 'unite': 'pièce'},
        {'nom': 'Nettoyage sec',  'prix': '400',  'unite': 'pièce'},
      ],
      'reparation': [
        {'nom': 'Diagnostic',     'prix': '2000', 'unite': 'forfait'},
        {'nom': 'Remplacement écran', 'prix': '30000', 'unite': 'pièce'},
        {'nom': 'Réparation batterie','prix': '10000', 'unite': 'pièce'},
      ],
      'soins': [
        {'nom': 'Coiffure femme', 'prix': '5000',  'unite': 'forfait'},
        {'nom': 'Manucure',       'prix': '3000',  'unite': 'forfait'},
        {'nom': 'Massage 1h',     'prix': '10000', 'unite': 'heure'},
      ],
    };
    final key = type.toLowerCase();
    final list = exemples[key] ?? [
      {'nom': 'Prestation 1', 'prix': '1000', 'unite': 'forfait'},
      {'nom': 'Prestation 2', 'prix': '2000', 'unite': 'forfait'},
    ];
    for (final e in list) {
      _prestations.add(_Prestation(
        nom: e['nom']!, prix: e['prix']!, unite: e['unite']!,
      ));
    }
  }

  void _chargerEtapesPredef(String type) {
    final key = type.toUpperCase();
    final etapes = _etapesPredef[key] ?? ['EN_TRAITEMENT'];
    for (final e in etapes) {
      _etapesCustom.add(TextEditingController(text: e));
    }
  }

  // ─────────────────────────────────────────────────
  // CONSTRUIRE LES JSON BACKEND
  // ─────────────────────────────────────────────────
  String get _tarifsJson {
    final map = <String, String>{};
    for (final p in _prestations) {
      final nom  = p.nomCtrl.text.trim();
      final prix = p.prixCtrl.text.trim();
      if (nom.isNotEmpty && prix.isNotEmpty) map[nom] = prix;
    }
    return json.encode(map);
  }

  String get _optionJson => json.encode({
    'express':   _optionExpress,
    'collecte':  _optionCollecte,
    'livraison': _optionLivraison,
  });

  String get _prestationsJson {
    final list = _prestations
        .where((p) => p.nomCtrl.text.trim().isNotEmpty)
        .map((p) => {
              'nom':   p.nomCtrl.text.trim(),
              'prix':  double.tryParse(p.prixCtrl.text.trim()) ?? 0,
              'unite': p.unite,
            })
        .toList();
    return json.encode(list);
  }

  String get _champsCommandeJson {
    final list = _champs
        .where((c) => c.nomCtrl.text.trim().isNotEmpty)
        .map((c) => c.toJson())
        .toList();
    return json.encode(list);
  }

  String get _etapesPersonnaliseesJson {
    // Inclure les étapes dans l'ordre : custom en premier, puis CLOTUREE
    final toutes = _etapesCustom
        .map((e) => e.text.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
    return json.encode(toutes);
  }

  String? get _modesDepotAcceptes {
    if (!_avecAgent) return null;
    final modes = <String>[];
    if (_optionCollecte)  modes.add('Collecte domicile');
    if (_optionLivraison) modes.add('Dépôt atelier (livraison)');
    if (modes.isEmpty)    return null;
    return json.encode(modes);
  }

  // ─────────────────────────────────────────────────
  // ENREGISTRER
  // ─────────────────────────────────────────────────
  Future<void> _sauvegarder() async {
    final zone = _zoneController.text.trim();
    if (zone.isEmpty) {
      _showSnack('⚠️ La zone de couverture est obligatoire');
      return;
    }
    if (_prestations.where((p) => p.nomCtrl.text.isNotEmpty).isEmpty) {
      _showSnack('⚠️ Ajoutez au moins une prestation');
      return;
    }

    setState(() => _isSaving = true);

    final token = await AuthStorage.getToken();
    if (token == null) {
      _showSnack('❌ Session expirée. Reconnectez-vous.');
      setState(() => _isSaving = false);
      return;
    }

    try {
      final params = <String, String>{
        'typeService':     _typeService,
        'tarifsJson':      _tarifsJson,
        'optionJson':      _optionJson,
        'prestationsJson': _prestationsJson,
        'zoneCouverture':  zone,
        'avecAgent':       _avecAgent.toString(),
        'champsCommande':  _champsCommandeJson,
      };

      // Étapes personnalisées si renseignées
      final etapes = _etapesPersonnaliseesJson;
      if (etapes != '[]') params['etapesPersonnalisees'] = etapes;

      final modes = _modesDepotAcceptes;
      if (modes != null) params['modesDepotAcceptes'] = modes;

      final uri = Uri.parse(
        '${ApiConstants.prestataireConfig}/$_userId',
      ).replace(queryParameters: params);

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await AuthStorage.saveTypeService(_typeService);
        _showSnack('✅ Service configuré avec succès !');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        String msg = 'Erreur ${response.statusCode}';
        try {
          final body = json.decode(response.body);
          msg = body['message'] ?? body['error'] ?? msg;
        } catch (_) {
          if (response.body.isNotEmpty) {
            msg = response.body.substring(0, response.body.length.clamp(0, 150));
          }
        }
        _showSnack('❌ $msg');
      }
    } catch (e) {
      _showSnack('❌ Connexion impossible. Vérifiez le réseau.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            msg.startsWith('✅') ? AppColors.primary : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildZoneHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildTab1Prestations(),
                      _buildTab2Formulaire(),
                      _buildTab3Etapes(),
                    ],
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Configurer mon service',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _typeService.isEmpty ? '—' : _typeService.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // HEADER ZONE (toujours visible au-dessus des tabs)
  // ─────────────────────────────────────────────────
  Widget _buildZoneHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _zoneController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Zone de couverture (ex : Dakar, Plateau…)',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
        tabs: const [
          Tab(text: 'Prestations'),
          Tab(text: 'Formulaire'),
          Tab(text: 'Étapes'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ONGLET 1 — PRESTATIONS
  // ═══════════════════════════════════════════════
  Widget _buildTab1Prestations() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Options de livraison
        _buildOptionsCard(),
        const SizedBox(height: 16),

        // Header prestations
        Row(
          children: [
            Text(
              'Mes prestations & tarifs',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _prestations.add(_Prestation());
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Liste des prestations
        ..._prestations.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return _buildPrestationCard(i, p);
        }),
      ],
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Options du service',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.flash_on,
            label: 'Service express',
            value: _optionExpress,
            onChanged: (v) => setState(() => _optionExpress = v),
          ),
          _buildOptionTile(
            icon: Icons.directions_bike,
            label: 'Collecte à domicile',
            value: _optionCollecte,
            onChanged: (v) => setState(() {
              _optionCollecte = v;
              if (v) _avecAgent = true;
            }),
          ),
          _buildOptionTile(
            icon: Icons.local_shipping,
            label: 'Livraison incluse',
            value: _optionLivraison,
            onChanged: (v) => setState(() {
              _optionLivraison = v;
              if (v) _avecAgent = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label,
          style: GoogleFonts.poppins(fontSize: 13)),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  Widget _buildPrestationCard(int index, _Prestation p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextField(
              controller: p.nomCtrl,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Nom de la prestation',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: p.prixCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Prix (FCFA)',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildUniteDropdown(p),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              p.dispose();
              setState(() => _prestations.removeAt(index));
            },
            child: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildUniteDropdown(_Prestation p) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _unites.contains(p.unite) ? p.unite : _unites.first,
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
        isDense: true,
        items: _unites
            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
            .toList(),
        onChanged: (val) {
          if (val != null) setState(() => p.unite = val);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ONGLET 2 — FORMULAIRE (champsCommande)
  // ═══════════════════════════════════════════════
  Widget _buildTab2Formulaire() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info concept
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFECB5)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Formulaire de commande dynamique',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ces champs s\'afficheront au client lorsqu\'il passera commande. Stockés en JSON → zéro if(typeService).',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.brown.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Header
        Row(
          children: [
            Text(
              'Champs du formulaire',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _champs.add(_ChampCommande())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_champs.isEmpty)
          _buildEmptyState(
            icon: Icons.list_alt,
            message: 'Aucun champ défini.\nAjoutez des champs pour personnaliser\nle formulaire de commande.',
          ),

        ..._champs.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return _buildChampCard(i, c);
        }),
      ],
    );
  }

  Widget _buildChampCard(int index, _ChampCommande c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom + supprimer
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c.nomCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nom du champ (ex : Poids, Type tissu…)',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  c.dispose();
                  setState(() => _champs.removeAt(index));
                },
                child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
          const Divider(height: 16),
          // Type + Requis
          Row(
            children: [
              // Type badge
              const Text('Type : ',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              _buildTypeSelector(c),
              const Spacer(),
              // Requis toggle
              Row(
                children: [
                  Text(
                    c.requis ? 'Requis' : 'Optionnel',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: c.requis ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: c.requis,
                    activeColor: Colors.redAccent,
                    onChanged: (v) => setState(() => c.requis = v),
                  ),
                ],
              ),
            ],
          ),
          // Options (uniquement pour type LIST)
          if (c.type == 'LIST') ...[
            const SizedBox(height: 8),
            _buildListOptions(c),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector(_ChampCommande c) {
    const types = ['TEXT', 'NUMBER', 'LIST'];
    const colors = {
      'TEXT':   Color(0xFF3B82F6),
      'NUMBER': Color(0xFF10B981),
      'LIST':   Color(0xFF8B5CF6),
    };
    return Row(
      children: types.map((t) {
        final selected = c.type == t;
        return GestureDetector(
          onTap: () => setState(() => c.type = t),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? (colors[t] ?? Colors.grey).withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? (colors[t] ?? Colors.grey)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              t,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected
                    ? (colors[t] ?? Colors.grey)
                    : Colors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListOptions(_ChampCommande c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options de la liste :',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        ...c.options.asMap().entries.map((entry) {
          final i = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: c.options[i],
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Option…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => c.options[i] = val,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => c.options.removeAt(i)),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => c.options.add('')),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ajouter une option', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8B5CF6),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // ONGLET 3 — ÉTAPES WORKFLOW
  // ═══════════════════════════════════════════════
  Widget _buildTab3Etapes() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔄', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workflow personnalisé',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Définissez les étapes que traverse votre service. Les étapes fixes (CREE, CONFIRMEE, CLOTUREE) sont automatiques.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Étapes fixes (non éditables)
        Text(
          'Étapes fixes (automatiques)',
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        ..._etapesFixees.map((e) => _buildEtapeFixe(e)),

        // Séparateur + étapes custom
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Étapes personnalisées',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(
                  () => _etapesCustom.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Présets rapides
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('Pressing', ['EN_COLLECTE', 'EN_TRAITEMENT', 'EN_LIVRAISON']),
              const SizedBox(width: 8),
              _buildPresetChip('Réparation', ['DIAGNOSTIC', 'DEVIS_ENVOYE', 'EN_REPARATION']),
              const SizedBox(width: 8),
              _buildPresetChip('Soins', ['PLANIFIEE', 'EN_INTERVENTION']),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_etapesCustom.isEmpty)
          _buildEmptyState(
            icon: Icons.timeline,
            message: 'Aucune étape personnalisée.\nUtilisez un preset ou ajoutez vos propres étapes.',
          ),

        // Liste réorderable des étapes custom
        ..._etapesCustom.asMap().entries.map((entry) {
          final i = entry.key;
          final ctrl = entry.value;
          return _buildEtapeCustomCard(i, ctrl);
        }),
      ],
    );
  }

  Widget _buildEtapeFixe(String etape) {
    final icons = {
      'CREE':      Icons.add_circle_outline,
      'CONFIRMEE': Icons.check_circle_outline,
      'CLOTUREE':  Icons.lock_outline,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icons[etape] ?? Icons.circle, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(
            etape,
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '🔒 fixe',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtapeCustomCard(int index, TextEditingController ctrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Drag handle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          ),
          // Numéro
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          // Champ texte
          Expanded(
            child: TextField(
              controller: ctrl,
              style: GoogleFonts.poppins(fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ex: EN_TRAITEMENT, DIAGNOSTIC…',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          // Boutons up/down
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: index > 0
                    ? () => setState(() {
                          final tmp = _etapesCustom[index];
                          _etapesCustom[index] = _etapesCustom[index - 1];
                          _etapesCustom[index - 1] = tmp;
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.arrow_upward,
                      size: 16,
                      color: index > 0 ? AppColors.primary : Colors.grey.shade300),
                ),
              ),
              InkWell(
                onTap: index < _etapesCustom.length - 1
                    ? () => setState(() {
                          final tmp = _etapesCustom[index];
                          _etapesCustom[index] = _etapesCustom[index + 1];
                          _etapesCustom[index + 1] = tmp;
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.arrow_downward,
                      size: 16,
                      color: index < _etapesCustom.length - 1
                          ? AppColors.primary
                          : Colors.grey.shade300),
                ),
              ),
            ],
          ),
          // Supprimer
          InkWell(
            onTap: () {
              ctrl.dispose();
              setState(() => _etapesCustom.removeAt(index));
            },
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, List<String> etapes) {
    return GestureDetector(
      onTap: () {
        setState(() {
          for (final e in _etapesCustom) e.dispose();
          _etapesCustom.clear();
          for (final e in etapes) {
            _etapesCustom.add(TextEditingController(text: e));
          }
        });
        _showSnack('✅ Étapes "$label" appliquées');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // BOUTON SAUVEGARDER (bas de page)
  // ─────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _sauvegarder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Valider la configuration',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // HELPER : état vide
  // ─────────────────────────────────────────────────
  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey, height: 1.6),
          ),
        ],
      ),
    );
  }
}



// // ═══════════════════════════════════════════════════════
// // ConfigurerServiceScreen.dart
// //
// // RÔLE : Formulaire de configuration du service prestataire
// //
// // BACKEND : POST /api/prestataire/config/{id}
// // Params REQUIS :
// //   - typeService      (String)
// //   - tarifsJson       (JSON String)
// //   - optionJson       (JSON String)
// //   - prestationsJson  (JSON String)
// //   - zoneCouverture   (String)
// //
// // Params OPTIONNELS :
// //   - etapesPersonnalisees  (JSON String)
// //   - modesDepotAcceptes    (JSON String)
// //   - avecAgent             (Boolean)
// //
// // SÉCURITÉ : JWT Bearer token sur TOUS les appels HTTP
// // ═══════════════════════════════════════════════════════

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';

// class ConfigurerServiceScreen extends StatefulWidget {
//   const ConfigurerServiceScreen({super.key});

//   @override
//   State<ConfigurerServiceScreen> createState() =>
//       _ConfigurerServiceScreenState();
// }

// class _ConfigurerServiceScreenState
//     extends State<ConfigurerServiceScreen> {

//   // ── Chargement ────────────────────────────────────
//   bool _isLoading = true;
//   bool _isSaving  = false;
//   int  _userId    = 0;

//   // ── Type de service ───────────────────────────────
//   // Hérité du profil prestataire — affiché en lecture seule
//   // doit correspondre à un ConfigurationService en base
//   String _typeService = '';

//   // ── Zone de couverture ────────────────────────────
//   final _zoneController = TextEditingController();

//   // ── Prestations ───────────────────────────────────
//   // Liste de {nomCtrl, prixCtrl, uniteCtrl}
//   // → Génère tarifsJson ET prestationsJson
//   final List<Map<String, TextEditingController>> _prestations = [];

//   // ── Options ───────────────────────────────────────
//   bool _optionExpress   = false;
//   bool _optionCollecte  = false;
//   bool _optionLivraison = false;

//   // ── Avec agent (livraison) ────────────────────────
//   bool _avecAgent = false;

//   // ── Clé formulaire ────────────────────────────────
//   final _formKey = GlobalKey<FormState>();

//   // ─────────────────────────────────────────────────
//   // LISTES DE RÉFÉRENCE
//   // ─────────────────────────────────────────────────
//   static const List<String> _typesService = [
//     'pressing',
//     'nettoyage',
//     'laverie',
//     'plomberie',
//     'electricite',
//     'maconnerie',
//     'peinture',
//     'jardinage',
//   ];

//   static const List<String> _unites = [
//     'pièce',
//     'kg',
//     'heure',
//     'mètre',
//     'forfait',
//     'visite',
//   ];

//   // Exemples de prestations selon type
//   Map<String, List<Map<String, String>>> get _exemplesPrestations => {
//     'pressing': [
//       {'nom': 'Lavage kilo',  'prix': '500',  'unite': 'kg'},
//       {'nom': 'Chemise',      'prix': '300',  'unite': 'pièce'},
//       {'nom': 'Boubou/Bazin', 'prix': '2000', 'unite': 'pièce'},
//       {'nom': 'Pantalon',     'prix': '500',  'unite': 'pièce'},
//       {'nom': 'Nettoyage sec','prix': '400',  'unite': 'pièce'},
//     ],
//     'nettoyage': [
//       {'nom': 'Nettoyage appartement', 'prix': '5000',  'unite': 'forfait'},
//       {'nom': 'Nettoyage villa',       'prix': '10000', 'unite': 'forfait'},
//       {'nom': 'Nettoyage bureau',      'prix': '3000',  'unite': 'heure'},
//       {'nom': 'Vitre / Moquette',      'prix': '2000',  'unite': 'forfait'},
//     ],
//     'plomberie': [
//       {'nom': 'Dépannage urgent',     'prix': '5000',  'unite': 'visite'},
//       {'nom': 'Installation robinet', 'prix': '8000',  'unite': 'forfait'},
//       {'nom': 'Débouchage',           'prix': '10000', 'unite': 'forfait'},
//     ],
//     'default': [
//       {'nom': 'Prestation 1', 'prix': '1000', 'unite': 'forfait'},
//       {'nom': 'Prestation 2', 'prix': '2000', 'unite': 'forfait'},
//     ],
//   };

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   @override
//   void dispose() {
//     _zoneController.dispose();
//     for (final p in _prestations) {
//       p['nom']!.dispose();
//       p['prix']!.dispose();
//       p['unite']!.dispose();
//     }
//     super.dispose();
//   }

//   // ─────────────────────────────────────────────────
//   // CHARGEMENT — GET config existante
//   // ─────────────────────────────────────────────────
//   Future<void> _loadData() async {
//     setState(() => _isLoading = true);

//     final userId = await AuthStorage.getUserId();
//     final typeStored = await AuthStorage.getTypeService();
//     _userId = userId ?? 0;
//     _typeService = typeStored;

//     final token = await AuthStorage.getToken();
//     if (token != null && _userId > 0) {
//       await _loadConfigExistante(token);
//     }

//     // Si aucune prestation chargée → ajouter des exemples
//     if (_prestations.isEmpty) {
//       _chargerExemples(_typeService);
//     }

//     if (mounted) setState(() => _isLoading = false);
//   }

//   Future<void> _loadConfigExistante(String token) async {
//     try {
//       final uri = Uri.parse(
//           '${ApiConstants.prestataireConfig}/$_userId');
//       final response = await http.get(uri, headers: {
//         'Authorization': 'Bearer $token',
//         'Content-Type': 'application/json',
//       }).timeout(const Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         // Type service
//         final type = data['typeService'] as String? ?? '';
//         if (type.isNotEmpty) {
//           _typeService = type;
//           await AuthStorage.saveTypeService(type);
//         }

//         // Zone
//         _zoneController.text = data['zoneCouverture'] as String? ?? '';

//         // avecAgent
//         _avecAgent = data['avecAgent'] as bool? ?? false;

//         // Options
//         final optionStr = data['optionsActives'] as String?;
//         if (optionStr != null && optionStr.isNotEmpty) {
//           try {
//             final opts = json.decode(optionStr) as Map<String, dynamic>;
//             _optionExpress   = opts['express']   as bool? ?? false;
//             _optionCollecte  = opts['collecte']  as bool? ?? false;
//             _optionLivraison = opts['livraison'] as bool? ?? false;
//           } catch (_) {}
//         }

//         // Prestations
//         final prestStr = data['prestationsAjoutees'] as String?;
//         if (prestStr != null && prestStr.isNotEmpty) {
//           try {
//             final list = json.decode(prestStr) as List<dynamic>;
//             for (final p in list) {
//               _ajouterPrestation(
//                 nom:   p['nom']   as String? ?? '',
//                 prix:  p['prix']?.toString() ?? '',
//                 unite: p['unite'] as String? ?? 'pièce',
//               );
//             }
//           } catch (_) {}
//         }
//       }
//     } catch (_) {
//       // Config non trouvée → première configuration
//     }
//   }

//   // ─────────────────────────────────────────────────
//   // EXEMPLES PAR TYPE DE SERVICE
//   // ─────────────────────────────────────────────────
//   void _chargerExemples(String type) {
//     final exemples =
//         _exemplesPrestations[type] ??
//         _exemplesPrestations['default']!;
//     for (final e in exemples) {
//       _ajouterPrestation(
//         nom:   e['nom']!,
//         prix:  e['prix']!,
//         unite: e['unite']!,
//       );
//     }
//   }

//   void _ajouterPrestation({
//     String nom   = '',
//     String prix  = '',
//     String unite = 'pièce',
//   }) {
//     _prestations.add({
//       'nom':   TextEditingController(text: nom),
//       'prix':  TextEditingController(text: prix),
//       'unite': TextEditingController(text: unite),
//     });
//   }

//   void _supprimerPrestation(int index) {
//     _prestations[index]['nom']!.dispose();
//     _prestations[index]['prix']!.dispose();
//     _prestations[index]['unite']!.dispose();
//     setState(() => _prestations.removeAt(index));
//   }

//   // ─────────────────────────────────────────────────
//   // CONSTRUIRE LES JSON POUR LE BACKEND
//   // ─────────────────────────────────────────────────
//   String get _tarifsJson {
//     // {"Lavage kilo": "500", "Chemise": "300", ...}
//     final map = <String, String>{};
//     for (final p in _prestations) {
//       final nom  = p['nom']!.text.trim();
//       final prix = p['prix']!.text.trim();
//       if (nom.isNotEmpty && prix.isNotEmpty) {
//         map[nom] = prix;
//       }
//     }
//     return json.encode(map);
//   }

//   String get _optionJson {
//     // {"express": false, "collecte": true, "livraison": false}
//     return json.encode({
//       'express':   _optionExpress,
//       'collecte':  _optionCollecte,
//       'livraison': _optionLivraison,
//     });
//   }

//   String get _prestationsJson {
//     // [{"nom": "Lavage kilo", "prix": 500, "unite": "kg"}, ...]
//     final list = <Map<String, dynamic>>[];
//     for (final p in _prestations) {
//       final nom   = p['nom']!.text.trim();
//       final prix  = p['prix']!.text.trim();
//       final unite = p['unite']!.text.trim();
//       if (nom.isNotEmpty) {
//         list.add({
//           'nom':   nom,
//           'prix':  double.tryParse(prix) ?? 0,
//           'unite': unite,
//         });
//       }
//     }
//     return json.encode(list);
//   }

//   String? get _modesDepotAcceptes {
//     if (!_avecAgent) return null;
//     final modes = <String>[];
//     if (_optionCollecte)  modes.add('Collecte domicile');
//     if (_optionLivraison) modes.add('Dépôt atelier (livraison)');
//     if (modes.isEmpty)    return null;
//     return json.encode(modes);
//   }

//   String? get _etapesPersonnalisees {
//     if (!_avecAgent) return null;
//     return json.encode([
//       'collecte', 'reception', 'traitement', 'livraison',
//     ]);
//   }

//   // ─────────────────────────────────────────────────
//   // ENREGISTRER — POST /api/prestataire/config/{id}
//   // ─────────────────────────────────────────────────
//   Future<void> _sauvegarder() async {
//     if (!_formKey.currentState!.validate()) return;

//     final zone = _zoneController.text.trim();
//     if (zone.isEmpty) {
//       _showSnack('⚠️ La zone de couverture est obligatoire');
//       return;
//     }
//     if (_prestations.isEmpty) {
//       _showSnack('⚠️ Ajoutez au moins une prestation');
//       return;
//     }

//     setState(() => _isSaving = true);

//     final token = await AuthStorage.getToken();
//     if (token == null) {
//       _showSnack('❌ Session expirée. Reconnectez-vous.');
//       setState(() => _isSaving = false);
//       return;
//     }

//     try {
//       // ── 5 PARAMS REQUIS + optionnels ───────────────
//       final params = {
//         'typeService':     _typeService,
//         'tarifsJson':      _tarifsJson,
//         'optionJson':      _optionJson,
//         'prestationsJson': _prestationsJson,
//         'zoneCouverture':  zone,
//         // Optionnels
//         'avecAgent': _avecAgent.toString(),
//       };

//       final modesDepot = _modesDepotAcceptes;
//       if (modesDepot != null) params['modesDepotAcceptes'] = modesDepot;

//       final etapes = _etapesPersonnalisees;
//       if (etapes != null) params['etapesPersonnalisees'] = etapes;

//       // URI avec query params
//       final uri = Uri.parse(
//         '${ApiConstants.prestataireConfig}/$_userId',
//       ).replace(queryParameters: params);

//       final response = await http.post(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       ).timeout(const Duration(seconds: 15));

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         // Sauvegarder typeService localement
//         await AuthStorage.saveTypeService(_typeService);
//         _showSnack('✅ Service configuré avec succès !');
//         await Future.delayed(const Duration(milliseconds: 800));
//         if (mounted) Navigator.pop(context);
//       } else {
//         // Afficher le message d'erreur du backend
//         String msgErreur = 'Erreur ${response.statusCode}';
//         try {
//           final body = json.decode(response.body);
//           msgErreur = body['message'] ?? body['error'] ?? msgErreur;
//         } catch (_) {
//           msgErreur = response.body.isNotEmpty
//               ? response.body.substring(
//                   0, response.body.length.clamp(0, 150))
//               : msgErreur;
//         }
//         _showSnack('❌ $msgErreur');
//       }
//     } catch (e) {
//       _showSnack('❌ Connexion impossible. Vérifiez le réseau.');
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   void _showSnack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg,
//             style: GoogleFonts.poppins(fontSize: 13)),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor: msg.startsWith('✅')
//             ? AppColors.green
//             : AppColors.red,
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // BUILD PRINCIPAL
//   // ─────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: _buildAppBar(),
//       body: _isLoading
//           ? const Center(
//               child: CircularProgressIndicator(
//                   color: AppColors.green))
//           : Form(
//               key: _formKey,
//               child: ListView(
//                 padding: const EdgeInsets.all(16),
//                 children: [
//                   // ① Type de service
//                   _sectionTypeService(),
//                   const SizedBox(height: 20),

//                   // ② Zone de couverture
//                   _sectionZone(),
//                   const SizedBox(height: 20),

//                   // ③ Prestations & Tarifs
//                   _sectionPrestations(),
//                   const SizedBox(height: 20),

//                   // ④ Options
//                   _sectionOptions(),
//                   const SizedBox(height: 20),

//                   // ⑤ Agents / Collecte
//                   _sectionAgents(),
//                   const SizedBox(height: 32),

//                   // Bouton Enregistrer
//                   _boutonSauvegarder(),
//                   const SizedBox(height: 24),
//                 ],
//               ),
//             ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // APP BAR
//   // ─────────────────────────────────────────────────
//   PreferredSizeWidget _buildAppBar() {
//     return PreferredSize(
//       preferredSize: const Size.fromHeight(kToolbarHeight),
//       child: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [AppColors.green, Color(0xFF3A7A1A)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           iconTheme:
//               const IconThemeData(color: Colors.white),
//           title: Text(
//             'Configurer mon service',
//             style: GoogleFonts.poppins(
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//               fontSize: 17,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // ① SECTION — TYPE DE SERVICE
//   // ─────────────────────────────────────────────────
//   Widget _sectionTypeService() {
//     return _card(
//       title: '① Type de service',
//       icon: Icons.category_rounded,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Votre type de service (défini à l\'inscription)',
//             style: GoogleFonts.poppins(
//               fontSize: 12,
//               color: AppColors.textMuted,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.symmetric(
//                 horizontal: 14, vertical: 12),
//             decoration: BoxDecoration(
//               color: AppColors.greenLight,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(
//                   color: AppColors.green.withOpacity(0.3)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.verified_rounded,
//                     color: AppColors.green, size: 20),
//                 const SizedBox(width: 10),
//                 Text(
//                   _labelTypeService(_typeService),
//                   style: GoogleFonts.poppins(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 15,
//                     color: AppColors.green,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (_typeService.isEmpty) ...[
//             const SizedBox(height: 10),
//             Text(
//               '⚠️ Type non défini. Mettez à jour votre profil.',
//               style: GoogleFonts.poppins(
//                 fontSize: 11,
//                 color: AppColors.amber,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   String _labelTypeService(String type) {
//     switch (type.toLowerCase()) {
//       case 'pressing':    return '🧺 Pressing';
//       case 'nettoyage':   return '🧹 Nettoyage';
//       case 'laverie':     return '👕 Laverie';
//       case 'plomberie':   return '🔧 Plomberie';
//       case 'electricite': return '⚡ Électricité';
//       case 'maconnerie':  return '🏗️ Maçonnerie';
//       case 'peinture':    return '🎨 Peinture';
//       case 'jardinage':   return '🌿 Jardinage';
//       default:
//         return type.isEmpty ? '⚙️ Non défini' : type;
//     }
//   }

//   // ─────────────────────────────────────────────────
//   // ② SECTION — ZONE DE COUVERTURE
//   // ─────────────────────────────────────────────────
//   Widget _sectionZone() {
//     return _card(
//       title: '② Zone de couverture',
//       icon: Icons.location_on_rounded,
//       iconColor: const Color(0xFFFF6B6B),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Quartiers / zones couverts par votre service',
//             style: GoogleFonts.poppins(
//               fontSize: 12,
//               color: AppColors.textMuted,
//             ),
//           ),
//           const SizedBox(height: 10),
//           TextFormField(
//             controller: _zoneController,
//             style: GoogleFonts.poppins(fontSize: 14),
//             decoration: InputDecoration(
//               hintText: 'Ex: Médina, Plateau, Almadies, Fann',
//               hintStyle: GoogleFonts.poppins(
//                   fontSize: 13, color: AppColors.textMuted),
//               prefixIcon: const Icon(Icons.location_on,
//                   color: Color(0xFFFF6B6B)),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide: const BorderSide(
//                     color: AppColors.border),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//                 borderSide: const BorderSide(
//                     color: AppColors.green, width: 1.5),
//               ),
//               filled: true,
//               fillColor: Colors.white,
//             ),
//             validator: (v) => (v == null || v.trim().isEmpty)
//                 ? 'Zone obligatoire'
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // ③ SECTION — PRESTATIONS & TARIFS
//   // ─────────────────────────────────────────────────
//   Widget _sectionPrestations() {
//     return _card(
//       title: '③ Prestations & Tarifs',
//       icon: Icons.price_check_rounded,
//       iconColor: AppColors.primary,
//       trailing: TextButton.icon(
//         onPressed: () => setState(() => _ajouterPrestation()),
//         icon: const Icon(Icons.add_circle_rounded,
//             color: AppColors.green, size: 18),
//         label: Text(
//           'Ajouter',
//           style: GoogleFonts.poppins(
//             color: AppColors.green,
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       child: Column(
//         children: [
//           if (_prestations.isEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               child: Text(
//                 'Aucune prestation. Appuyez sur "Ajouter".',
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   color: AppColors.textMuted,
//                 ),
//               ),
//             ),
//           ...List.generate(_prestations.length, (i) =>
//               _buildPrestationItem(i)),
//           if (_prestations.isNotEmpty) ...[
//             const SizedBox(height: 10),
//             const Divider(color: AppColors.border),
//             const SizedBox(height: 4),
//             Row(
//               children: [
//                 const Icon(Icons.info_outline,
//                     color: AppColors.textMuted, size: 14),
//                 const SizedBox(width: 6),
//                 Expanded(
//                   child: Text(
//                     'Les tarifs seront visibles par les clients',
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       color: AppColors.textMuted,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildPrestationItem(int index) {
//     final p = _prestations[index];
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: AppColors.background,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: AppColors.border),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               // Numéro
//               Container(
//                 width: 24,
//                 height: 24,
//                 decoration: BoxDecoration(
//                   color: AppColors.greenLight,
//                   shape: BoxShape.circle,
//                 ),
//                 child: Center(
//                   child: Text(
//                     '${index + 1}',
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       fontWeight: FontWeight.bold,
//                       color: AppColors.green,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               // Nom de la prestation
//               Expanded(
//                 child: TextFormField(
//                   controller: p['nom'],
//                   style: GoogleFonts.poppins(fontSize: 13),
//                   decoration: _inputDeco('Nom de la prestation'),
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty)
//                           ? 'Requis'
//                           : null,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               // Supprimer
//               GestureDetector(
//                 onTap: () => setState(
//                     () => _supprimerPrestation(index)),
//                 child: const Icon(Icons.remove_circle,
//                     color: AppColors.red, size: 20),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               // Prix
//               Expanded(
//                 flex: 2,
//                 child: TextFormField(
//                   controller: p['prix'],
//                   keyboardType: TextInputType.number,
//                   style: GoogleFonts.poppins(fontSize: 13),
//                   decoration: _inputDecoSuffix(
//                       'Prix', 'FCFA'),
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty)
//                           ? 'Requis'
//                           : null,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               // Unité
//               Expanded(
//                 flex: 2,
//                 child: DropdownButtonFormField<String>(
//                   value: _unites.contains(p['unite']!.text)
//                       ? p['unite']!.text
//                       : _unites.first,
//                   style: GoogleFonts.poppins(
//                       fontSize: 13,
//                       color: AppColors.textPrimary),
//                   decoration: _inputDeco('Unité'),
//                   items: _unites
//                       .map((u) => DropdownMenuItem(
//                             value: u,
//                             child: Text(u),
//                           ))
//                       .toList(),
//                   onChanged: (v) {
//                     if (v != null) {
//                       setState(() => p['unite']!.text = v);
//                     }
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // ④ SECTION — OPTIONS
//   // ─────────────────────────────────────────────────
//   Widget _sectionOptions() {
//     return _card(
//       title: '④ Options proposées',
//       icon: Icons.tune_rounded,
//       iconColor: AppColors.amber,
//       child: Column(
//         children: [
//           _toggleOption(
//             icon: Icons.flash_on_rounded,
//             label: 'Service Express',
//             subtitle: 'Traitement prioritaire (supplément de prix)',
//             value: _optionExpress,
//             color: AppColors.amber,
//             onChanged: (v) => setState(() => _optionExpress = v),
//           ),
//           const Divider(height: 1, color: AppColors.border),
//           _toggleOption(
//             icon: Icons.directions_bike_rounded,
//             label: 'Collecte à domicile',
//             subtitle: 'Un agent récupère chez le client',
//             value: _optionCollecte,
//             color: AppColors.primary,
//             onChanged: (v) => setState(() => _optionCollecte = v),
//           ),
//           const Divider(height: 1, color: AppColors.border),
//           _toggleOption(
//             icon: Icons.local_shipping_rounded,
//             label: 'Livraison à domicile',
//             subtitle: 'Retour chez le client après traitement',
//             value: _optionLivraison,
//             color: AppColors.green,
//             onChanged: (v) => setState(() => _optionLivraison = v),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _toggleOption({
//     required IconData icon,
//     required String label,
//     required String subtitle,
//     required bool value,
//     required Color color,
//     required ValueChanged<bool> onChanged,
//   }) {
//     return SwitchListTile(
//       contentPadding: EdgeInsets.zero,
//       secondary: Container(
//         padding: const EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.1),
//           shape: BoxShape.circle,
//         ),
//         child: Icon(icon, color: color, size: 18),
//       ),
//       title: Text(
//         label,
//         style: GoogleFonts.poppins(
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//           color: AppColors.textPrimary,
//         ),
//       ),
//       subtitle: Text(
//         subtitle,
//         style: GoogleFonts.poppins(
//           fontSize: 11,
//           color: AppColors.textMuted,
//         ),
//       ),
//       value: value,
//       activeColor: color,
//       onChanged: onChanged,
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // ⑤ SECTION — AGENTS
//   // ─────────────────────────────────────────────────
//   Widget _sectionAgents() {
//     return _card(
//       title: '⑤ Gestion avec agents',
//       icon: Icons.people_rounded,
//       iconColor: AppColors.purple,
//       child: Column(
//         children: [
//           SwitchListTile(
//             contentPadding: EdgeInsets.zero,
//             secondary: Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: AppColors.purple.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.people_rounded,
//                   color: AppColors.purple, size: 18),
//             ),
//             title: Text(
//               'Utiliser des agents livreurs',
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             subtitle: Text(
//               'Activez si vous avez des agents pour la collecte/livraison',
//               style: GoogleFonts.poppins(
//                 fontSize: 11,
//                 color: AppColors.textMuted,
//               ),
//             ),
//             value: _avecAgent,
//             activeColor: AppColors.purple,
//             onChanged: (v) => setState(() => _avecAgent = v),
//           ),
//           if (_avecAgent) ...[
//             const SizedBox(height: 10),
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: AppColors.purple.withOpacity(0.07),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                     color: AppColors.purple.withOpacity(0.2)),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.info_outline,
//                       color: AppColors.purple, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Avec agents activé : les modes collecte & livraison seront configurés automatiquement selon vos options.',
//                       style: GoogleFonts.poppins(
//                         fontSize: 11,
//                         color: AppColors.purple,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // BOUTON ENREGISTRER
//   // ─────────────────────────────────────────────────
//   Widget _boutonSauvegarder() {
//     return SizedBox(
//       width: double.infinity,
//       height: 52,
//       child: ElevatedButton(
//         onPressed: _isSaving ? null : _sauvegarder,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.green,
//           foregroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//           elevation: 0,
//         ),
//         child: _isSaving
//             ? const SizedBox(
//                 height: 22,
//                 width: 22,
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                   strokeWidth: 2.5,
//                 ),
//               )
//             : Text(
//                 '✅  Enregistrer la configuration',
//                 style: GoogleFonts.poppins(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────────
//   // WIDGETS UTILITAIRES
//   // ─────────────────────────────────────────────────
//   Widget _card({
//     required String title,
//     required IconData icon,
//     Color? iconColor,
//     Widget? trailing,
//     required Widget child,
//   }) {
//     final color = iconColor ?? AppColors.green;
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header de section
//           Padding(
//             padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(7),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(icon, color: color, size: 18),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     title,
//                     style: GoogleFonts.poppins(
//                       fontWeight: FontWeight.w600,
//                       fontSize: 14,
//                       color: AppColors.textPrimary,
//                     ),
//                   ),
//                 ),
//                 if (trailing != null) trailing,
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: AppColors.border),
//           Padding(
//             padding: const EdgeInsets.all(14),
//             child: child,
//           ),
//         ],
//       ),
//     );
//   }

//   InputDecoration _inputDeco(String hint) {
//     return InputDecoration(
//       hintText: hint,
//       hintStyle: GoogleFonts.poppins(
//           fontSize: 12, color: AppColors.textMuted),
//       contentPadding:
//           const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: const BorderSide(color: AppColors.border),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide:
//             const BorderSide(color: AppColors.green, width: 1.5),
//       ),
//       filled: true,
//       fillColor: Colors.white,
//       isDense: true,
//     );
//   }

//   InputDecoration _inputDecoSuffix(String hint, String suffix) {
//     return _inputDeco(hint).copyWith(
//       suffixText: suffix,
//       suffixStyle: GoogleFonts.poppins(
//           fontSize: 11, color: AppColors.textMuted),
//     );
//   }
// }