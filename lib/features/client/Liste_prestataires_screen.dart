// lib/features/client/liste_prestataires_screen.dart
// Écran générique pour TOUS les types de services : pressing, réparation, soins…
// => ZÉRO if(typeService) dans ce fichier.
// La couleur thème, le titre et l'URL API passent en paramètre.
// Les chips filtres sont dérivées des tags retournés par l'API (champ 'categoriesTags').
//
// ✅ CORRECTIFS v2 :
//   1. JWT auth header sur GET /prestataire (AuthStorage.getToken())
//   2. Navigation vers FichePrestataireScreen via MaterialPageRoute (constructeur)
//      au lieu de Navigator.pushNamed('/fiche-prestataire')

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/client/Fiche_prestataire_screen.dart';

// ── Imports ajoutés ──────────────────────────────────────────
import '../../core/services/auth_storage.dart';
import '../../core/constants/api_constants.dart';

class ListePrestatairesScreen extends StatefulWidget {
  final String typeServiceNom;   // 'PRESSING', 'REPARATION', 'SOINS'
  final String titre;            // 'Pressing', 'Réparateurs', 'Soins à domicile'
  final Color themeColor;        // bleu, violet, etc.

  const ListePrestatairesScreen({
    super.key,
    required this.typeServiceNom,
    required this.titre,
    required this.themeColor,
  });

  @override
  State<ListePrestatairesScreen> createState() => _ListePrestatairesScreenState();
}

class _ListePrestatairesScreenState extends State<ListePrestatairesScreen> {
  // ✅ URL centralisée dans ApiConstants — plus de duplication
  // Pour changer l'IP : modifier uniquement api_constants.dart

  List<Map<String, dynamic>> _prestataires = [];
  List<Map<String, dynamic>> _filtres = [];
  String _selectedFiltre = 'Tout';
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrestataires();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ✅ CORRECTIF 1 : JWT auth header ajouté ─────────────────
  Future<void> _loadPrestataires() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await AuthStorage.getToken();         // ← AJOUTÉ
      final res = await http.get(
        Uri.parse('${ApiConstants.prestataires}?typeService=${widget.typeServiceNom}'),
        headers: {                                         // ← AJOUTÉ
          'Authorization': 'Bearer $token',               // ← AJOUTÉ
        },                                                 // ← AJOUTÉ
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        final prestataires = data.cast<Map<String, dynamic>>();

        // Dériver les chips filtres depuis les tags des prestataires (zéro if typeService)
        final Set<String> tagsSet = {};
        for (final p in prestataires) {
          final tags = p['categoriesTags'] as List? ?? [];
          for (final t in tags) {
            tagsSet.add(t.toString());
          }
        }
        final filtres = <Map<String, dynamic>>[
          {'label': 'Tout', 'emoji': ''},
          ...tagsSet.map((t) => {'label': t, 'emoji': ''}),
        ];

        setState(() {
          _prestataires = prestataires;
          _filtres = filtres;
          _loading = false;
        });
      } else {
        setState(() { _error = 'Erreur ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      // Données de démo pour le développement
      setState(() {
        _prestataires = _demoData();
        _filtres = _demoFiltres();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _demoData() => [
    {
      'id': 1,
      'nom': 'Express Laverie Pro',
      'description': 'Pressing de qualité, livraison en 24h',
      'note': 4.8,
      'nombreAvis': 124,
      'distanceKm': 1.2,
      'delaiHeures': 24,
      'prixMin': 1500,
      'categoriesTags': ['Express', 'Domicile'],
      'ouvert': true,
      'avatarInitiale': 'E',
      'avatarColor': '#2563EB',
    },
    {
      'id': 2,
      'nom': 'Pressing Diamant',
      'description': 'Spécialiste habits de fête et costumes',
      'note': 4.6,
      'nombreAvis': 89,
      'distanceKm': 2.8,
      'delaiHeures': 48,
      'prixMin': 2000,
      'categoriesTags': ['Atelier'],
      'ouvert': true,
      'avatarInitiale': 'D',
      'avatarColor': '#7C3AED',
    },
    {
      'id': 3,
      'nom': 'Clean & Fresh',
      'description': 'Blanchisserie industrielle, tarifs compétitifs',
      'note': 4.3,
      'nombreAvis': 56,
      'distanceKm': 4.5,
      'delaiHeures': 72,
      'prixMin': 1000,
      'categoriesTags': ['Atelier'],
      'ouvert': false,
      'avatarInitiale': 'C',
      'avatarColor': '#059669',
    },
  ];

  List<Map<String, dynamic>> _demoFiltres() => [
    {'label': 'Tout', 'emoji': ''},
    {'label': 'Express', 'emoji': '⚡'},
    {'label': 'Domicile', 'emoji': '🚗'},
    {'label': 'Atelier', 'emoji': '🏪'},
  ];

  List<Map<String, dynamic>> get _prestatairesFiltres {
    return _prestataires.where((p) {
      final matchFiltre = _selectedFiltre == 'Tout' ||
          (p['categoriesTags'] as List? ?? []).contains(_selectedFiltre);
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          (p['nomCommercial'] ?? p['nom'] ?? '').toString().toLowerCase().contains(q) ||
          (p['description'] ?? p['descriptionService'] ?? '').toString().toLowerCase().contains(q);
      return matchFiltre && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        title: Text(widget.titre, style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {},
            tooltip: 'Filtres avancés',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildListe(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: widget.themeColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Rechercher un ${widget.titre.toLowerCase()}...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filtres.map((f) {
            final label = f['label'] as String;
            final emoji = f['emoji'] as String;
            final selected = _selectedFiltre == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  emoji.isEmpty ? label : '$emoji $label',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _selectedFiltre = label),
                selectedColor: widget.themeColor,
                backgroundColor: const Color(0xFFF1F5F9),
                showCheckmark: false,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildListe() {
    final liste = _prestatairesFiltres;
    if (liste.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez un autre filtre ou une autre recherche',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liste.length,
      itemBuilder: (context, i) => _buildCard(liste[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    // ── Champs corrigés selon les noms réels du backend ──────────
    final ouvert   = p['disponible'] as bool? ?? true;
    final note     = ((p['moyenneNotes'] ?? p['note'] ?? 0) as num).toDouble();
    final nAvis    = ((p['nombreAvis']   ?? p['nbAvis']  ?? 0) as num).toInt();
    final distance = ((p['distanceKm'] ?? 0) as num).toDouble();
    final delai    = ((p['delaiHeures'] ?? 0) as num).toInt();
    final prixMin  = ((p['prixMinimal'] ?? p['prixMin'] ?? 0) as num).toInt();

    // Tags : champ API ou dérivé depuis typesPrestation
    final List<String> tags = (() {
      final ct = p['categoriesTags'];
      if (ct is List && ct.isNotEmpty) return ct.cast<String>();
      final tp = p['typesPrestation'] as List? ?? [];
      return tp
          .map((t) => (t['nom'] ?? t['typePrestation'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
    })();

    // Initiale = 1ère lettre du nom commercial
    final nomAffiche = (p['nomCommercial'] ?? p['nom'] ?? '').toString();
    final initiale   = nomAffiche.isNotEmpty ? nomAffiche[0].toUpperCase() : '?';

    // Couleur avatar = themeColor si absent du JSON
    Color avatarColor;
    try {
      final hex = (p['avatarColor'] as String?)?.replaceFirst('#', '');
      avatarColor = (hex != null && hex.isNotEmpty)
          ? Color(int.parse('FF$hex', radix: 16))
          : widget.themeColor;
    } catch (_) {
      avatarColor = widget.themeColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ✅ CORRECTIF 2a : MaterialPageRoute au lieu de pushNamed ─
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FichePrestataireScreen(prestataire: p),
          ),
        ),
        child: Column(
          children: [
            // En-tête carte
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        initiale,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: avatarColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomAffiche,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ouvert
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ouvert ? 'Ouvert' : 'Fermé',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ouvert
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (p['description'] ?? p['descriptionService'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Stats inline
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              note.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              ' ($nAvis avis)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: Color(0xFF94A3B8)),
                            Text(
                              ' ${distance.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: Color(0xFF94A3B8)),
                            Text(
                              ' ${delai}h',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tags
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.themeColor,
                      ),
                    ),
                  )).toList(),
                ),
              ),

            // Footer prix + bouton
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'À partir de',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$prixMin FCFA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  // ✅ CORRECTIF 2b : même fix sur le bouton "Voir →" ─
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FichePrestataireScreen(prestataire: p),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.themeColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: widget.themeColor, width: 1.5),
                      ),
                    ),
                    child: const Text(
                      'Voir →',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Impossible de charger',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPrestataires,
            style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}