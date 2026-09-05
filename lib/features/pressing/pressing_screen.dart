import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'pressing_detail_screen.dart';

// ── MODÈLE MOCK ──────────────────────────────────────
class PressingMock {
  final String id, nom, adresse, zone;
  final double note, prixKilo;
  final int nbAvis, distance;
  final bool isOpen, hasExpress, hasCollecte;
  final List<String> services;

  const PressingMock({
    required this.id, required this.nom,
    required this.adresse, required this.zone,
    required this.note, required this.prixKilo,
    required this.nbAvis, required this.distance,
    required this.isOpen, required this.hasExpress,
    required this.hasCollecte, required this.services,
  });
}

final List<PressingMock> mockPressings = [
  const PressingMock(
    id: '1', nom: 'Pressing Médina Express',
    adresse: 'Rue 12, Médina', zone: 'Médina',
    note: 4.8, prixKilo: 500, nbAvis: 124,
    distance: 1, isOpen: true,
    hasExpress: true, hasCollecte: true,
    services: ['Lavage kilo', 'Boubou/Bazin', 'Express'],
  ),
  const PressingMock(
    id: '2', nom: 'Pressing Almadies Luxe',
    adresse: 'Av. Cheikh Anta, Almadies', zone: 'Almadies',
    note: 4.9, prixKilo: 800, nbAvis: 89,
    distance: 3, isOpen: true,
    hasExpress: true, hasCollecte: true,
    services: ['Lavage kilo', 'Robe mariée', 'Dentelle'],
  ),
  const PressingMock(
    id: '3', nom: 'Tech Pressing Plateau',
    adresse: 'Bd de la République', zone: 'Plateau',
    note: 4.6, prixKilo: 450, nbAvis: 56,
    distance: 2, isOpen: true,
    hasExpress: false, hasCollecte: true,
    services: ['Lavage kilo', 'Nettoyage sec'],
  ),
  const PressingMock(
    id: '4', nom: 'Pressing Yoff Qualité',
    adresse: 'Route de Yoff', zone: 'Yoff',
    note: 4.5, prixKilo: 500, nbAvis: 43,
    distance: 5, isOpen: false,
    hasExpress: false, hasCollecte: true,
    services: ['Lavage kilo', 'Boubou/Bazin'],
  ),
  const PressingMock(
    id: '5', nom: 'Pressing Ouakam Pro',
    adresse: 'Cité Millionnaire, Ouakam', zone: 'Ouakam',
    note: 4.7, prixKilo: 550, nbAvis: 72,
    distance: 4, isOpen: true,
    hasExpress: true, hasCollecte: false,
    services: ['Lavage kilo', 'Costume', 'Express'],
  ),
];

// ── ECRAN LISTE ──────────────────────────────────────
class PressingScreen extends StatefulWidget {
  const PressingScreen({super.key});

  @override
  State<PressingScreen> createState() => _PressingScreenState();
}

class _PressingScreenState extends State<PressingScreen> {
  String _filter = 'Tous';
  final List<String> _filters = [
    'Tous', 'Express', 'Collecte', 'Boubou', 'Ouvert'
  ];

  List<PressingMock> get _filtered {
    switch (_filter) {
      case 'Express':
        return mockPressings.where((p) => p.hasExpress).toList();
      case 'Collecte':
        return mockPressings.where((p) => p.hasCollecte).toList();
      case 'Boubou':
        return mockPressings
          .where((p) => p.services.any((s) => s.contains('Boubou')))
          .toList();
      case 'Ouvert':
        return mockPressings.where((p) => p.isOpen).toList();
      default:
        return mockPressings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [

          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🧺 Pressing",
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text("${mockPressings.length} prestataires "
                      "près de vous",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [

                // Recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border, width: 0.5),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Rechercher un pressing...",
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search,
                          color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // Filtres
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                    itemCount: _filters.length,
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final bool sel = _filter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                              ? AppColors.primary
                              : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                ? AppColors.primary
                                : AppColors.border),
                          ),
                          child: Text(f,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: sel
                                ? Colors.white
                                : AppColors.textSecond,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Nombre de résultats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text("${_filtered.length} résultats",
                        style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildPressingCard(context, _filtered[i]),
                childCount: _filtered.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildPressingCard(BuildContext context, PressingMock p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => PressingDetailScreen(pressing: p))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [

            // Bannière
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10, top: -10,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text("🧺",
                              style: TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p.nom,
                                style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(p.adresse,
                                style: GoogleFonts.poppins(
                                  color: Colors.white
                                    .withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.isOpen
                              ? Colors.green
                              : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p.isOpen ? "Ouvert" : "Fermé",
                            style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Infos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Note
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                          Text("${p.note}",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(" (${p.nbAvis})",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecond,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Distance
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                            color: AppColors.primary, size: 14),
                          Text("${p.distance} km",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecond,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Prix
                      Text("${p.prixKilo.toInt()} F/kg",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Badges services
                  Row(
                    children: [
                      if (p.hasExpress)
                        _badge("Express", AppColors.amber,
                          AppColors.amberLight),
                      if (p.hasCollecte)
                        _badge("Collecte", AppColors.green,
                          AppColors.greenLight),
                      ...p.services.take(2).map((s) =>
                        _badge(s, AppColors.primary,
                          AppColors.primaryLight)),
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

  Widget _badge(String label, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: GoogleFonts.poppins(
          fontSize: 9, color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}