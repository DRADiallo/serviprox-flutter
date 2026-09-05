import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'pressing_screen.dart';
import 'pressing_commande_screen.dart';

class PressingDetailScreen extends StatelessWidget {
  final PressingMock pressing;
  const PressingDetailScreen({super.key, required this.pressing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [

          // AppBar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                child: Stack(
                  children: [
                    Positioned(
                      right: -20, top: -20,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: Text("🧺",
                                style: TextStyle(fontSize: 32)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(pressing.nom,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(pressing.adresse,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white
                                      .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 14),
                                    Text("${pressing.note} "
                                      "(${pressing.nbAvis} avis)",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Infos rapides
                  Row(
                    children: [
                      _infoChip(Icons.location_on_outlined,
                        "${pressing.distance} km",
                        AppColors.primary),
                      const SizedBox(width: 8),
                      _infoChip(Icons.access_time,
                        pressing.isOpen ? "Ouvert" : "Fermé",
                        pressing.isOpen
                          ? AppColors.green : Colors.grey),
                      const SizedBox(width: 8),
                      _infoChip(Icons.scale_outlined,
                        "${pressing.prixKilo.toInt()} F/kg",
                        AppColors.amber),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Modes de dépôt
                  Text("Mode de dépôt",
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _modeCard(
                    icon: "🏠",
                    title: "Collecte à domicile",
                    subtitle: "Agent vient chez vous · +500 FCFA",
                    isSelected: true,
                  ),
                  const SizedBox(height: 8),
                  _modeCard(
                    icon: "🏪",
                    title: "Dépôt atelier + livraison",
                    subtitle: "Vous déposez, on livre retour",
                    isSelected: false,
                  ),
                  const SizedBox(height: 8),
                  _modeCard(
                    icon: "🔄",
                    title: "Dépôt + récupération",
                    subtitle: "Vous gérez l'aller-retour",
                    isSelected: false,
                  ),

                  const SizedBox(height: 20),

                  // Prestations
                  Text("Nos prestations",
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _prestationItem(
                    "Lavage au kilo",
                    "500 FCFA / kg",
                    Icons.local_laundry_service_outlined,
                  ),
                  _prestationItem(
                    "Boubou / Bazin",
                    "1 500 FCFA / pièce",
                    Icons.checkroom_outlined,
                  ),
                  _prestationItem(
                    "Nettoyage à sec",
                    "400 FCFA / pièce",
                    Icons.dry_cleaning_outlined,
                  ),
                  if (pressing.hasExpress)
                    _prestationItem(
                      "Option Express",
                      "+33% sur tarif de base",
                      Icons.bolt_outlined,
                    ),

                  const SizedBox(height: 20),

                  // Sécurité
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                          color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Double preuve sécurisée",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                "Photos + signatures numériques "
                                "à la collecte et à la livraison.",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecond,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bouton Commander
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10, offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => PressingCommandeScreen(
                  pressing: pressing))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                  color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text("Commander maintenant",
                  style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11, color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(
      {required String icon, required String title,
       required String subtitle, required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected
                      ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textSecond),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle,
              color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _prestationItem(String nom, String prix, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nom,
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(prix,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}