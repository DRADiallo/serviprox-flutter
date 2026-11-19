// ═══════════════════════════════════════════════════════
// ConfigurerServiceScreen.dart
//
// RÔLE : Formulaire de configuration du service prestataire
//
// BACKEND : POST /api/prestataire/config/{id}
// Params REQUIS :
//   - typeService      (String)
//   - tarifsJson       (JSON String)
//   - optionJson       (JSON String)
//   - prestationsJson  (JSON String)
//   - zoneCouverture   (String)
//
// Params OPTIONNELS :
//   - etapesPersonnalisees  (JSON String)
//   - modesDepotAcceptes    (JSON String)
//   - avecAgent             (Boolean)
//
// SÉCURITÉ : JWT Bearer token sur TOUS les appels HTTP
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class ConfigurerServiceScreen extends StatefulWidget {
  const ConfigurerServiceScreen({super.key});

  @override
  State<ConfigurerServiceScreen> createState() =>
      _ConfigurerServiceScreenState();
}

class _ConfigurerServiceScreenState
    extends State<ConfigurerServiceScreen> {

  // ── Chargement ────────────────────────────────────
  bool _isLoading = true;
  bool _isSaving  = false;
  int  _userId    = 0;

  // ── Type de service ───────────────────────────────
  // Hérité du profil prestataire — affiché en lecture seule
  // doit correspondre à un ConfigurationService en base
  String _typeService = '';

  // ── Zone de couverture ────────────────────────────
  final _zoneController = TextEditingController();

  // ── Prestations ───────────────────────────────────
  // Liste de {nomCtrl, prixCtrl, uniteCtrl}
  // → Génère tarifsJson ET prestationsJson
  final List<Map<String, TextEditingController>> _prestations = [];

  // ── Options ───────────────────────────────────────
  bool _optionExpress   = false;
  bool _optionCollecte  = false;
  bool _optionLivraison = false;

  // ── Avec agent (livraison) ────────────────────────
  bool _avecAgent = false;

  // ── Clé formulaire ────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ─────────────────────────────────────────────────
  // LISTES DE RÉFÉRENCE
  // ─────────────────────────────────────────────────
  static const List<String> _typesService = [
    'pressing',
    'nettoyage',
    'laverie',
    'plomberie',
    'electricite',
    'maconnerie',
    'peinture',
    'jardinage',
  ];

  static const List<String> _unites = [
    'pièce',
    'kg',
    'heure',
    'mètre',
    'forfait',
    'visite',
  ];

  // Exemples de prestations selon type
  Map<String, List<Map<String, String>>> get _exemplesPrestations => {
    'pressing': [
      {'nom': 'Lavage kilo',  'prix': '500',  'unite': 'kg'},
      {'nom': 'Chemise',      'prix': '300',  'unite': 'pièce'},
      {'nom': 'Boubou/Bazin', 'prix': '2000', 'unite': 'pièce'},
      {'nom': 'Pantalon',     'prix': '500',  'unite': 'pièce'},
      {'nom': 'Nettoyage sec','prix': '400',  'unite': 'pièce'},
    ],
    'nettoyage': [
      {'nom': 'Nettoyage appartement', 'prix': '5000',  'unite': 'forfait'},
      {'nom': 'Nettoyage villa',       'prix': '10000', 'unite': 'forfait'},
      {'nom': 'Nettoyage bureau',      'prix': '3000',  'unite': 'heure'},
      {'nom': 'Vitre / Moquette',      'prix': '2000',  'unite': 'forfait'},
    ],
    'plomberie': [
      {'nom': 'Dépannage urgent',     'prix': '5000',  'unite': 'visite'},
      {'nom': 'Installation robinet', 'prix': '8000',  'unite': 'forfait'},
      {'nom': 'Débouchage',           'prix': '10000', 'unite': 'forfait'},
    ],
    'default': [
      {'nom': 'Prestation 1', 'prix': '1000', 'unite': 'forfait'},
      {'nom': 'Prestation 2', 'prix': '2000', 'unite': 'forfait'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _zoneController.dispose();
    for (final p in _prestations) {
      p['nom']!.dispose();
      p['prix']!.dispose();
      p['unite']!.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // CHARGEMENT — GET config existante
  // ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = await AuthStorage.getUserId();
    final typeStored = await AuthStorage.getTypeService();
    _userId = userId ?? 0;
    _typeService = typeStored;

    final token = await AuthStorage.getToken();
    if (token != null && _userId > 0) {
      await _loadConfigExistante(token);
    }

    // Si aucune prestation chargée → ajouter des exemples
    if (_prestations.isEmpty) {
      _chargerExemples(_typeService);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadConfigExistante(String token) async {
    try {
      final uri = Uri.parse(
          '${ApiConstants.prestataireConfig}/$_userId');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

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
        final optionStr = data['optionsActives'] as String?;
        if (optionStr != null && optionStr.isNotEmpty) {
          try {
            final opts = json.decode(optionStr) as Map<String, dynamic>;
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
              _ajouterPrestation(
                nom:   p['nom']   as String? ?? '',
                prix:  p['prix']?.toString() ?? '',
                unite: p['unite'] as String? ?? 'pièce',
              );
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Config non trouvée → première configuration
    }
  }

  // ─────────────────────────────────────────────────
  // EXEMPLES PAR TYPE DE SERVICE
  // ─────────────────────────────────────────────────
  void _chargerExemples(String type) {
    final exemples =
        _exemplesPrestations[type] ??
        _exemplesPrestations['default']!;
    for (final e in exemples) {
      _ajouterPrestation(
        nom:   e['nom']!,
        prix:  e['prix']!,
        unite: e['unite']!,
      );
    }
  }

  void _ajouterPrestation({
    String nom   = '',
    String prix  = '',
    String unite = 'pièce',
  }) {
    _prestations.add({
      'nom':   TextEditingController(text: nom),
      'prix':  TextEditingController(text: prix),
      'unite': TextEditingController(text: unite),
    });
  }

  void _supprimerPrestation(int index) {
    _prestations[index]['nom']!.dispose();
    _prestations[index]['prix']!.dispose();
    _prestations[index]['unite']!.dispose();
    setState(() => _prestations.removeAt(index));
  }

  // ─────────────────────────────────────────────────
  // CONSTRUIRE LES JSON POUR LE BACKEND
  // ─────────────────────────────────────────────────
  String get _tarifsJson {
    // {"Lavage kilo": "500", "Chemise": "300", ...}
    final map = <String, String>{};
    for (final p in _prestations) {
      final nom  = p['nom']!.text.trim();
      final prix = p['prix']!.text.trim();
      if (nom.isNotEmpty && prix.isNotEmpty) {
        map[nom] = prix;
      }
    }
    return json.encode(map);
  }

  String get _optionJson {
    // {"express": false, "collecte": true, "livraison": false}
    return json.encode({
      'express':   _optionExpress,
      'collecte':  _optionCollecte,
      'livraison': _optionLivraison,
    });
  }

  String get _prestationsJson {
    // [{"nom": "Lavage kilo", "prix": 500, "unite": "kg"}, ...]
    final list = <Map<String, dynamic>>[];
    for (final p in _prestations) {
      final nom   = p['nom']!.text.trim();
      final prix  = p['prix']!.text.trim();
      final unite = p['unite']!.text.trim();
      if (nom.isNotEmpty) {
        list.add({
          'nom':   nom,
          'prix':  double.tryParse(prix) ?? 0,
          'unite': unite,
        });
      }
    }
    return json.encode(list);
  }

  String? get _modesDepotAcceptes {
    if (!_avecAgent) return null;
    final modes = <String>[];
    if (_optionCollecte)  modes.add('Collecte domicile');
    if (_optionLivraison) modes.add('Dépôt atelier (livraison)');
    if (modes.isEmpty)    return null;
    return json.encode(modes);
  }

  String? get _etapesPersonnalisees {
    if (!_avecAgent) return null;
    return json.encode([
      'collecte', 'reception', 'traitement', 'livraison',
    ]);
  }

  // ─────────────────────────────────────────────────
  // ENREGISTRER — POST /api/prestataire/config/{id}
  // ─────────────────────────────────────────────────
  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;

    final zone = _zoneController.text.trim();
    if (zone.isEmpty) {
      _showSnack('⚠️ La zone de couverture est obligatoire');
      return;
    }
    if (_prestations.isEmpty) {
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
      // ── 5 PARAMS REQUIS + optionnels ───────────────
      final params = {
        'typeService':     _typeService,
        'tarifsJson':      _tarifsJson,
        'optionJson':      _optionJson,
        'prestationsJson': _prestationsJson,
        'zoneCouverture':  zone,
        // Optionnels
        'avecAgent': _avecAgent.toString(),
      };

      final modesDepot = _modesDepotAcceptes;
      if (modesDepot != null) params['modesDepotAcceptes'] = modesDepot;

      final etapes = _etapesPersonnalisees;
      if (etapes != null) params['etapesPersonnalisees'] = etapes;

      // URI avec query params
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
        // Sauvegarder typeService localement
        await AuthStorage.saveTypeService(_typeService);
        _showSnack('✅ Service configuré avec succès !');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        // Afficher le message d'erreur du backend
        String msgErreur = 'Erreur ${response.statusCode}';
        try {
          final body = json.decode(response.body);
          msgErreur = body['message'] ?? body['error'] ?? msgErreur;
        } catch (_) {
          msgErreur = response.body.isNotEmpty
              ? response.body.substring(
                  0, response.body.length.clamp(0, 150))
              : msgErreur;
        }
        _showSnack('❌ $msgErreur');
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
        content: Text(msg,
            style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: msg.startsWith('✅')
            ? AppColors.green
            : AppColors.red,
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.green))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ① Type de service
                  _sectionTypeService(),
                  const SizedBox(height: 20),

                  // ② Zone de couverture
                  _sectionZone(),
                  const SizedBox(height: 20),

                  // ③ Prestations & Tarifs
                  _sectionPrestations(),
                  const SizedBox(height: 20),

                  // ④ Options
                  _sectionOptions(),
                  const SizedBox(height: 20),

                  // ⑤ Agents / Collecte
                  _sectionAgents(),
                  const SizedBox(height: 32),

                  // Bouton Enregistrer
                  _boutonSauvegarder(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.green, Color(0xFF3A7A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme:
              const IconThemeData(color: Colors.white),
          title: Text(
            'Configurer mon service',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ① SECTION — TYPE DE SERVICE
  // ─────────────────────────────────────────────────
  Widget _sectionTypeService() {
    return _card(
      title: '① Type de service',
      icon: Icons.category_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre type de service (défini à l\'inscription)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 10),
                Text(
                  _labelTypeService(_typeService),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
          if (_typeService.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '⚠️ Type non défini. Mettez à jour votre profil.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _labelTypeService(String type) {
    switch (type.toLowerCase()) {
      case 'pressing':    return '🧺 Pressing';
      case 'nettoyage':   return '🧹 Nettoyage';
      case 'laverie':     return '👕 Laverie';
      case 'plomberie':   return '🔧 Plomberie';
      case 'electricite': return '⚡ Électricité';
      case 'maconnerie':  return '🏗️ Maçonnerie';
      case 'peinture':    return '🎨 Peinture';
      case 'jardinage':   return '🌿 Jardinage';
      default:
        return type.isEmpty ? '⚙️ Non défini' : type;
    }
  }

  // ─────────────────────────────────────────────────
  // ② SECTION — ZONE DE COUVERTURE
  // ─────────────────────────────────────────────────
  Widget _sectionZone() {
    return _card(
      title: '② Zone de couverture',
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFFFF6B6B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quartiers / zones couverts par votre service',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _zoneController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ex: Médina, Plateau, Almadies, Fann',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.location_on,
                  color: Color(0xFFFF6B6B)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.green, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Zone obligatoire'
                : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ③ SECTION — PRESTATIONS & TARIFS
  // ─────────────────────────────────────────────────
  Widget _sectionPrestations() {
    return _card(
      title: '③ Prestations & Tarifs',
      icon: Icons.price_check_rounded,
      iconColor: AppColors.primary,
      trailing: TextButton.icon(
        onPressed: () => setState(() => _ajouterPrestation()),
        icon: const Icon(Icons.add_circle_rounded,
            color: AppColors.green, size: 18),
        label: Text(
          'Ajouter',
          style: GoogleFonts.poppins(
            color: AppColors.green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        children: [
          if (_prestations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune prestation. Appuyez sur "Ajouter".',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ...List.generate(_prestations.length, (i) =>
              _buildPrestationItem(i)),
          if (_prestations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.border),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.textMuted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Les tarifs seront visibles par les clients',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrestationItem(int index) {
    final p = _prestations[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Numéro
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nom de la prestation
              Expanded(
                child: TextFormField(
                  controller: p['nom'],
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: _inputDeco('Nom de la prestation'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Requis'
                          : null,
                ),
              ),
              const SizedBox(width: 6),
              // Supprimer
              GestureDetector(
                onTap: () => setState(
                    () => _supprimerPrestation(index)),
                child: const Icon(Icons.remove_circle,
                    color: AppColors.red, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Prix
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: p['prix'],
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: _inputDecoSuffix(
                      'Prix', 'FCFA'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Requis'
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              // Unité
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _unites.contains(p['unite']!.text)
                      ? p['unite']!.text
                      : _unites.first,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textPrimary),
                  decoration: _inputDeco('Unité'),
                  items: _unites
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => p['unite']!.text = v);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ④ SECTION — OPTIONS
  // ─────────────────────────────────────────────────
  Widget _sectionOptions() {
    return _card(
      title: '④ Options proposées',
      icon: Icons.tune_rounded,
      iconColor: AppColors.amber,
      child: Column(
        children: [
          _toggleOption(
            icon: Icons.flash_on_rounded,
            label: 'Service Express',
            subtitle: 'Traitement prioritaire (supplément de prix)',
            value: _optionExpress,
            color: AppColors.amber,
            onChanged: (v) => setState(() => _optionExpress = v),
          ),
          const Divider(height: 1, color: AppColors.border),
          _toggleOption(
            icon: Icons.directions_bike_rounded,
            label: 'Collecte à domicile',
            subtitle: 'Un agent récupère chez le client',
            value: _optionCollecte,
            color: AppColors.primary,
            onChanged: (v) => setState(() => _optionCollecte = v),
          ),
          const Divider(height: 1, color: AppColors.border),
          _toggleOption(
            icon: Icons.local_shipping_rounded,
            label: 'Livraison à domicile',
            subtitle: 'Retour chez le client après traitement',
            value: _optionLivraison,
            color: AppColors.green,
            onChanged: (v) => setState(() => _optionLivraison = v),
          ),
        ],
      ),
    );
  }

  Widget _toggleOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
      value: value,
      activeColor: color,
      onChanged: onChanged,
    );
  }

  // ─────────────────────────────────────────────────
  // ⑤ SECTION — AGENTS
  // ─────────────────────────────────────────────────
  Widget _sectionAgents() {
    return _card(
      title: '⑤ Gestion avec agents',
      icon: Icons.people_rounded,
      iconColor: AppColors.purple,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_rounded,
                  color: AppColors.purple, size: 18),
            ),
            title: Text(
              'Utiliser des agents livreurs',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Activez si vous avez des agents pour la collecte/livraison',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            value: _avecAgent,
            activeColor: AppColors.purple,
            onChanged: (v) => setState(() => _avecAgent = v),
          ),
          if (_avecAgent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.purple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.purple, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avec agents activé : les modes collecte & livraison seront configurés automatiquement selon vos options.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // BOUTON ENREGISTRER
  // ─────────────────────────────────────────────────
  Widget _boutonSauvegarder() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _sauvegarder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                '✅  Enregistrer la configuration',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // WIDGETS UTILITAIRES
  // ─────────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    required Widget child,
  }) {
    final color = iconColor ?? AppColors.green;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de section
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
          fontSize: 12, color: AppColors.textMuted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.green, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );
  }

  InputDecoration _inputDecoSuffix(String hint, String suffix) {
    return _inputDeco(hint).copyWith(
      suffixText: suffix,
      suffixStyle: GoogleFonts.poppins(
          fontSize: 11, color: AppColors.textMuted),
    );
  }
}