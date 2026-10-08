import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class PrestataireConfigScreen extends StatefulWidget {
  const PrestataireConfigScreen({super.key});

  @override
  State<PrestataireConfigScreen> createState() =>
      _PrestataireConfigScreenState();
}

class _PrestataireConfigScreenState
    extends State<PrestataireConfigScreen> {

  // ── Chargement ────────────────────────────────────
  bool _isLoading = true;
  bool _isSaving  = false;
  String _typeService = 'pressing';

  // ── Prestations de base ───────────────────────────
  // Chargées depuis GET /api/service-config/actifs
  // typeService = pressing → typesPrestation
  //List<Map<String, dynamic>> _prestationsBase = [];

  // ── Prix saisis par le prestataire ────────────────
  // Map<nomPrestation, TextEditingController>
  //final Map<String, TextEditingController> _prixControllers = {};

  // ── Prestations personnalisées ────────────────────
  // Ajoutées librement par le prestataire
  //final List<Map<String, TextEditingController>> _prestationsCustom = [];

  final List<Map<String, TextEditingController>>
    _prestations = [];
  // ── Options ───────────────────────────────────────
  bool _optionExpress   = false;
  bool _optionCollecte  = false;
  bool _optionLivraison = false;

  // ── Zone de couverture ────────────────────────────
  final _zoneController = TextEditingController();

  // ── Type service du prestataire ───────────────────
  

  // ← Exemples selon typeService
List<Map<String, String>> get _exemples {
  switch (_typeService) {
    case 'pressing':
      return [
        {'nom': 'Lavage kilo',      'prix': '500',  'unite': 'kg'},
        {'nom': 'Chemise',          'prix': '300',  'unite': 'pièce'},
        {'nom': 'Boubou/Bazin',     'prix': '2000', 'unite': 'pièce'},
        {'nom': 'Pantalon',         'prix': '500',  'unite': 'pièce'},
        {'nom': 'Nettoyage sec',    'prix': '400',  'unite': 'pièce'},
        {'nom': 'Repassage',        'prix': '200',  'unite': 'pièce'},
        {'nom': 'Gommage/Traitement','prix': '300', 'unite': 'pièce'},
        {'nom': 'Cuir/Daim',        'prix': '3000', 'unite': 'pièce'},
        {'nom': 'Laine/Cachemire',  'prix': '2500', 'unite': 'pièce'},
        {'nom': 'Article maison',   'prix': '1000', 'unite': 'pièce'},
      ];
    case 'coiffure':
      return [
        {'nom': 'Coiffure femme',   'prix': '3000', 'unite': 'forfait'},
        {'nom': 'Coiffure homme',   'prix': '1500', 'unite': 'forfait'},
        {'nom': 'Tresse',           'prix': '5000', 'unite': 'forfait'},
        {'nom': 'Défrisage',        'prix': '4000', 'unite': 'forfait'},
        {'nom': 'Coloration',       'prix': '6000', 'unite': 'forfait'},
      ];
    case 'reparation':
      return [
        {'nom': 'Diagnostic',       'prix': '2000', 'unite': 'forfait'},
        {'nom': 'Réparation écran', 'prix': '5000', 'unite': 'pièce'},
        {'nom': 'Batterie',         'prix': '3000', 'unite': 'pièce'},
        {'nom': 'Électroménager',   'prix': '8000', 'unite': 'forfait'},
        {'nom': 'Informatique',     'prix': '5000', 'unite': 'heure'},
      ];
    case 'nettoyage':
      return [
        {'nom': 'Ménage domicile',  'prix': '2000', 'unite': 'heure'},
        {'nom': 'Nettoyage bureau', 'prix': '5000', 'unite': 'forfait'},
        {'nom': 'Nettoyage vitres', 'prix': '3000', 'unite': 'forfait'},
        {'nom': 'Nettoyage moquette','prix': '4000','unite': 'forfait'},
      ];
    default:
      return [
        {'nom': 'Prestation 1', 'prix': '0', 'unite': 'pièce'},
        {'nom': 'Prestation 2', 'prix': '0', 'unite': 'pièce'},
      ];
  }
}

// Unite disponible
final List<String> _unites = [
    'pièce', 'kg', 'heure',
    'article', 'forfait', 'mètre',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

 @override
void dispose() {
  // ← UNE seule boucle
  for (final p in _prestations) {
    p['nom']?.dispose();
    p['prix']?.dispose();
    p['unite']?.dispose();
  }
  _zoneController.dispose();
  super.dispose();
}

  // ── Charger config existante + types de base ──────
  Future<void> _loadConfig() async {
  setState(() => _isLoading = true);
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    // ← Charger config existante du prestataire
    final existResp = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/prestataire'
        '/config/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (existResp.statusCode == 200) {
      final data = jsonDecode(existResp.body);

      // ← Charger typeService
      if (data['typeService'] != null) {
        setState(() =>
          _typeService = data['typeService']);
      }

      // ← Charger options
      if (data['optionsActives'] != null) {
        final options = jsonDecode(
          data['optionsActives']);
        setState(() {
          _optionExpress   =
            options['express']   ?? false;
          _optionCollecte  =
            options['collecte']  ?? false;
          _optionLivraison =
            options['livraison'] ?? false;
        });
      }

      // ← Charger zone
      if (data['zoneCouverture'] != null) {
        _zoneController.text =
          data['zoneCouverture'];
      }

      // ← Charger TOUTES les prestations
      // depuis prestationsAjoutees
      if (data['prestationsAjoutees'] != null) {
        final List<dynamic> items = jsonDecode(
          data['prestationsAjoutees']);

        for (final item in items) {
          if (item is Map) {
            // ← Nouveau format JSON ✅
            _addPrestation(
              nom:   item['nom']?.toString() ?? '',
              prix:  item['prix']?.toString() ?? '',
              unite: item['unite']?.toString()
                     ?? 'pièce',
            );
          } else {
            // ← Ancien format "nom:prix"
            // rétrocompatibilité
            final parts =
              item.toString().split(':');
            _addPrestation(
              nom:  parts.isNotEmpty
                ? parts[0].trim() : '',
              prix: parts.length > 1
                ? parts[1].trim() : '',
            );
          }
        }
      }

      // ← Charger aussi tarifsPersonnalises
      // (anciennes prestations de base)
      if (_prestations.isEmpty &&
          data['tarifsPersonnalises'] != null) {
        final tarifs = jsonDecode(
          data['tarifsPersonnalises'])
          as Map<String, dynamic>;
        for (final entry in tarifs.entries) {
          _addPrestation(
            nom:  entry.key,
            prix: entry.value.toString(),
          );
        }
      }
    }

    // ← Si aucune prestation → ligne vide
    if (_prestations.isEmpty) {
      _addPrestation();
    }

  } catch (e) {
    debugPrint("Erreur config: $e");
    if (_prestations.isEmpty) {
      _addPrestation();
    }
  } finally {
    setState(() => _isLoading = false);
  }
}

  // ── Ajouter prestation personnalisée ──────────────
  void _addPrestation({
  String nom = '',
  String prix = '',
  String unite = 'pièce',
}) {
  setState(() {
    _prestations.add({
      'nom':   TextEditingController(text: nom),
      'prix':  TextEditingController(text: prix),
      'unite': TextEditingController(text: unite),
    });
  });
}

  // ── Supprimer prestation personnalisée ────────────
  // UNE seule méthode pour supprimer
void _removePrestation(int index) {
  _prestations[index]['nom']?.dispose();
  _prestations[index]['prix']?.dispose();
  _prestations[index]['unite']?.dispose();
  setState(() => _prestations.removeAt(index));
}

  // ── Enregistrer la configuration ──────────────────
  Future<void> _sauvegarder() async {
  setState(() => _isSaving = true);
  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    // ← TOUTES les prestations
    // dans UN seul format JSON
    final List<Map<String, dynamic>> prestations =
      _prestations
        .where((p) =>
          p['nom']!.text.trim().isNotEmpty)
        .map((p) => {
          'nom':   p['nom']!.text.trim(),
          'prix':  double.tryParse(
            p['prix']!.text.trim()) ?? 0,
          'unite': p['unite']!.text.trim()
            .isEmpty ? 'pièce'
            : p['unite']!.text.trim(),
        })
        .toList();

    // ← Options
    final options = {
      'express':   _optionExpress,
      'collecte':  _optionCollecte,
      'livraison': _optionLivraison,
    };

    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/prestataire'
        '/config/$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
      body: {
        'typeService':    _typeService,
        'tarifsJson':     jsonEncode({}),
        // ← Tout dans prestationsJson !
        'prestationsJson': jsonEncode(prestations),
        'optionJson':     jsonEncode(options),
        'zoneCouverture':
          _zoneController.text.trim(),
      },
    );

    setState(() => _isSaving = false);

    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Text(
                "✅ Configuration enregistrée !",
                style: GoogleFonts.poppins(
                  fontSize: 13)),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Text(
                "❌ Erreur enregistrement",
                style: GoogleFonts.poppins(
                  fontSize: 13)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  } catch (e) {
    setState(() => _isSaving = false);
    debugPrint("Erreur save: $e");
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Configurer mon service",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Vos tarifs visibles par les clients",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
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

                // ── Prestations de base ───────────
                

                      // Bouton ajouter
                      // ← AVANT : 2 sections séparées
                // "Prestations de base"
                // "Mes prestations personnalisées"

                // ← APRÈS : 1 seule section
                _buildSection(
                  title: "Mes prestations",
                  subtitle:
                    "Saisissez vos services et vos prix",
                  child: Column(
                    children: [

                      // ← Header tableau
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text("Prestation",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecond,
                                )),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("Prix (FCFA)",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecond,
                                )),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text("Unité",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecond,
                                )),
                            ),
                            const SizedBox(width: 34),
                          ],
                        ),
                      ),

                      // ← Liste unifiée
                      ..._prestations
                        .asMap()
                        .entries
                        .map((e) =>
                          _buildPrestationRow(
                            e.key, e.value)),

                      const SizedBox(height: 8),

                      // ← Exemples inspirants
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius:
                            BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.amber
                              .withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: AppColors.amber,
                                  size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Exemples pour vous inspirer :",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: _exemples.map((e) =>
                                GestureDetector(
                                  onTap: () => _addPrestation(
                                    nom:   e['nom']!,
                                    prix:  e['prix']!,
                                    unite: e['unite']!,
                                  ),
                                  child: Container(
                                    padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                        BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.amber
                                          .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      "+ ${e['nom']}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.amber,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )).toList(),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "💡 Ajoutez ce que VOUS proposez !",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.amber,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ← Bouton ajouter
                      GestureDetector(
                        onTap: () => _addPrestation(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.green),
                            borderRadius:
                              BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                              MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.green,
                                size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Ajouter une prestation",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w500,
                                )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Options ───────────────────────
                _buildSection(
                      title: "Options de service",
                      subtitle: _typeService == 'pressing'
                        ? "Collecte et livraison par agents"
                        : "Options de déplacement",
                      child: Column(
                        children: [
                          // Express → toujours disponible
                          _buildOption(
                            "Service Express",
                            "Traitement/Intervention prioritaire",
                            Icons.bolt_outlined,
                            _optionExpress,
                            (val) => setState(
                              () => _optionExpress = val),
                          ),

                          // Collecte → seulement AVEC livraison
                          if (_typeService == 'pressing' ||
                              _typeService == 'blanchisserie')
                            _buildOption(
                              "Collecte à domicile",
                              "Agent vient chez le client",
                              Icons.delivery_dining_outlined,
                              _optionCollecte,
                              (val) => setState(
                                () => _optionCollecte = val),
                            ),

                          // Livraison → seulement AVEC livraison
                          if (_typeService == 'pressing' ||
                              _typeService == 'blanchisserie')
                            _buildOption(
                              "Livraison retour",
                              "Agent livre après traitement",
                              Icons.local_shipping_outlined,
                              _optionLivraison,
                              (val) => setState(
                                () => _optionLivraison = val),
                            ),

                          // Déplacement → SANS livraison
                          if (_typeService != 'pressing' &&
                              _typeService != 'blanchisserie')
                            _buildOption(
                              "Déplacement à domicile",
                              "Vous vous déplacez chez le client",
                              Icons.directions_walk_outlined,
                              _optionCollecte,
                              (val) => setState(
                                () => _optionCollecte = val),
                            ),
                        ],
                      ),
                    ),

                const SizedBox(height: 12),

                // ── Zone de couverture ─────────────
                _buildSection(
                  title: "Zone de couverture",
                  subtitle:
                    "Zones où vous intervenez",
                  child: TextField(
                    controller: _zoneController,
                    decoration: InputDecoration(
                      hintText:
                        "Ex: Médina, Plateau, Grand Dakar",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.green,
                        size: 20),
                      border: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5),
                      ),
                      contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Bouton enregistrer ─────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    onPressed:
                      _isSaving ? null : _sauvegarder,
                    child: _isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child:
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment:
                            MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.save_outlined,
                              size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Enregistrer ma configuration",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight:
                                  FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }

  // ── Section container ──────────────────────────────
  Widget _buildSection({
    required String title,
    required String subtitle,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecond,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Prestation de base ─────────────────────────────
  Widget _buildPrestationRow(
  int index,
  Map<String, TextEditingController> p,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [


        // ← AJOUT ICI : première chose dans le Row
        Container(
          width: 32, height: 32,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconPrestation(
              p['nom']!.text.isEmpty
                ? '' : p['nom']!.text),
            color: AppColors.green,
            size: 16),
        ),


        // ← Nom libre
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: p['nom'],
            style: GoogleFonts.poppins(
              fontSize: 12),
            decoration: InputDecoration(
              hintText: index < _exemples.length
                ? _exemples[index]['nom']
                : "Prestation ${index + 1}",
              hintStyle: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted),
              contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // ← Prix libre
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: p['prix'],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
            ),
            decoration: InputDecoration(
              hintText: "0",
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted),
              contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 10),
              border: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // ← Unité dropdown
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _unites.contains(
              p['unite']!.text)
              ? p['unite']!.text : 'pièce',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 10),
              border: OutlineInputBorder(
                borderRadius:
                  BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.border),
              ),
            ),
            items: _unites.map((u) =>
              DropdownMenuItem(
                value: u,
                child: Text(u,
                  style: GoogleFonts.poppins(
                    fontSize: 11)),
              )).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() =>
                  p['unite']!.text = val);
              }
            },
          ),
        ),

        const SizedBox(width: 6),

        // ← Supprimer
        GestureDetector(
          onTap: () => _removePrestation(index),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius:
                BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.red, size: 16),
          ),
        ),
      ],
    ),
  );
}

  // ── Option toggle ──────────────────────────────────
  Widget _buildOption(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: value
                ? AppColors.greenLight
                : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
              color: value
                ? AppColors.green
                : AppColors.textMuted,
              size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecond,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.green,
          ),
        ],
      ),
    );
  }

  // ── Icône selon prestation ─────────────────────────
  IconData _getIconPrestation(String nom) {
  final n = nom.toLowerCase();

  // ← Pressing
  if (n.contains('kilo') ||
      n.contains('lavage')) {
    return Icons.local_laundry_service_outlined;
  } else if (n.contains('boubou') ||
             n.contains('bazin') ||
             n.contains('kaftan')) {
    return Icons.checkroom_outlined;
  } else if (n.contains('sec')) {
    return Icons.dry_cleaning_outlined;
  } else if (n.contains('repassage')) {
    return Icons.iron_outlined;
  } else if (n.contains('gommage') ||
             n.contains('traitement')) {
    return Icons.auto_fix_high_outlined;
  } else if (n.contains('cuir') ||
             n.contains('daim')) {
    return Icons.workspace_premium_outlined;
  } else if (n.contains('laine') ||
             n.contains('cachemire')) {
    return Icons.texture_outlined;

  // ← Coiffure
  } else if (n.contains('coiffure') ||
             n.contains('tresse') ||
             n.contains('defrisage') ||
             n.contains('coloration')) {
    return Icons.content_cut_outlined;

  // ← Nettoyage
  } else if (n.contains('menage') ||
             n.contains('ménage') ||
             n.contains('nettoyage')) {
    return Icons.cleaning_services_outlined;
  } else if (n.contains('vitre')) {
    return Icons.window_outlined;
  } else if (n.contains('bureau')) {
    return Icons.business_outlined;

  // ← Réparation
  } else if (n.contains('diagnostic')) {
    return Icons.search_outlined;
  } else if (n.contains('ecran') ||
             n.contains('écran') ||
             n.contains('smartphone')) {
    return Icons.smartphone_outlined;
  } else if (n.contains('batterie')) {
    return Icons.battery_charging_full_outlined;
  } else if (n.contains('informatique') ||
             n.contains('ordinateur')) {
    return Icons.computer_outlined;
  } else if (n.contains('electromenager') ||
             n.contains('électroménager')) {
    return Icons.kitchen_outlined;

  // ← Soins
  } else if (n.contains('garde') ||
             n.contains('enfant')) {
    return Icons.child_care_outlined;
  } else if (n.contains('jardinage') ||
             n.contains('jardin')) {
    return Icons.yard_outlined;

  // ← Default
  } else {
    return Icons.star_outline;
  }
}
}