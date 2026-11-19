// lib/features/client/client_home_screen.dart
//
// Écran d'accueil client ServiProx
// - Charge les types de service depuis GET /api/type-service (JWT)
// - Fallback sur une liste statique si l'API échoue
// - Grille 2 colonnes → NaviguE vers ListePrestatairesScreen
// - Zéro if(typeService) : tout est générique
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/client/Liste_prestataires_screen.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_storage.dart';


class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String _prenomClient = '';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ── Catégories de secours (zéro appel réseau requis) ─────
  static const List<Map<String, dynamic>> _fallback = [
    {
      'nom': 'PRESSING',
      'libelle': 'Pressing',
      'description': 'Nettoyage & repassage',
      'icone': '🧺',
      'couleur': '#185FA5',
    },
    {
      'nom': 'REPARATION',
      'libelle': 'Réparation',
      'description': 'Électro & appareils',
      'icone': '🔧',
      'couleur': '#854F0B',
    },
    {
      'nom': 'COIFFURE',
      'libelle': 'Coiffure',
      'description': 'Soins capillaires',
      'icone': '💇',
      'couleur': '#27500A',
    },
    {
      'nom': 'SOINS',
      'libelle': 'Soins & Beauté',
      'description': 'Bien-être à domicile',
      'icone': '💆',
      'couleur': '#7C3AED',
    },
    {
      'nom': 'BLANCHISSERIE',
      'libelle': 'Blanchisserie',
      'description': 'Linge industriel',
      'icone': '👕',
      'couleur': '#0F766E',
    },
    {
      'nom': 'PLOMBERIE',
      'libelle': 'Plomberie',
      'description': 'Fuites & installations',
      'icone': '🚿',
      'couleur': '#1D4ED8',
    },
    {
      'nom': 'JARDINAGE',
      'libelle': 'Jardinage',
      'description': 'Entretien espaces verts',
      'icone': '🌿',
      'couleur': '#166534',
    },
    {
      'nom': 'ELECTRICITE',
      'libelle': 'Électricité',
      'description': 'Installation & dépannage',
      'icone': '⚡',
      'couleur': '#B45309',
    },
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadUserInfo(), _loadCategories()]);
  }

  // ── Charger le prénom du client ───────────────────────────
  Future<void> _loadUserInfo() async {
    try {
      final userId = await AuthStorage.getUserId();
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final prenom = data['prenom'] as String?
            ?? data['nom'] as String?
            ?? data['username'] as String?
            ?? '';
        if (mounted) setState(() => _prenomClient = prenom);
      }
    } catch (_) {
      // Pas critique : le greeting affiche simplement "Bonjour 👋"
    }
  }

  // ── Charger les types de service depuis l'API ─────────────
  Future<void> _loadCategories() async {
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/type-service'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        final cats = data
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        if (cats.isNotEmpty && mounted) {
          setState(() {
            _categories = cats;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    // Fallback statique
    if (mounted) setState(() { _categories = _fallback; _loading = false; });
  }

  // ── Filtrer selon la recherche ────────────────────────────
  List<Map<String, dynamic>> get _categoriesFiltrees {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery.toLowerCase();
    return _categories.where((c) {
      final lib = (c['libelle'] as String? ?? '').toLowerCase();
      final desc = (c['description'] as String? ?? '').toLowerCase();
      return lib.contains(q) || desc.contains(q);
    }).toList();
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _ouvrirCategorie(Map<String, dynamic> cat) {
    final nom = cat['nom'] as String? ?? cat['typeServiceNom'] as String? ?? '';
    final libelle = cat['libelle'] as String? ?? nom;
    final hex = cat['couleur'] as String? ?? '#185FA5';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListePrestatairesScreen(
          typeServiceNom: nom,
          titre: libelle,
          themeColor: _hexToColor(hex),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header gradient ─────────────────────────────
          _buildSliverHeader(),

          // ── Barre de recherche ──────────────────────────
          SliverToBoxAdapter(child: _buildSearchBar()),

          // ── Titre section ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Nos services',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    Text(
                      '${_categoriesFiltrees.length} disponible${_categoriesFiltrees.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecond),
                    ),
                ],
              ),
            ),
          ),

          // ── Grille catégories ───────────────────────────
          if (_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Chargement des services…',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecond)),
                  ]),
                ),
              ),
            )
          else if (_categoriesFiltrees.isEmpty)
            SliverToBoxAdapter(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _buildCategoryCard(_categoriesFiltrees[i]),
                  childCount: _categoriesFiltrees.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── SliverAppBar / header gradient ───────────────────────
  Widget _buildSliverHeader() {
    final greeting = _prenomClient.isNotEmpty
        ? 'Bonjour, $_prenomClient 👋'
        : 'Bonjour 👋';

    return SliverAppBar(
      expandedHeight: 160,
      collapsedHeight: 60,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Que cherchez-vous aujourd\'hui ?',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Titre affiché quand le header est réduit
        title: Text(
          'ServiProx',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
      ),
      // Actions : bouton notifications
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Barre de recherche ────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher un service…',
            hintStyle: GoogleFonts.poppins(
                fontSize: 14, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.primary, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Carte catégorie ───────────────────────────────────────
  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final icone = cat['icone'] as String? ?? '🏪';
    final libelle = cat['libelle'] as String? ?? '—';
    final desc = cat['description'] as String? ?? '';
    final hex = cat['couleur'] as String? ?? '#185FA5';
    final color = _hexToColor(hex);

    return GestureDetector(
      onTap: () => _ouvrirCategorie(cat),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: color.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Pastille couleur décorative en haut à droite
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji dans une boite colorée
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        icone,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Libellé
                  Text(
                    libelle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecond,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Bouton "Voir"
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Voir',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_rounded,
                                size: 12, color: color),
                          ],
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
    );
  }

  // ── État vide ─────────────────────────────────────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 60, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            'Aucun service trouvé',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecond),
          ),
          const SizedBox(height: 6),
          Text(
            'Essayez un autre mot-clé',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}