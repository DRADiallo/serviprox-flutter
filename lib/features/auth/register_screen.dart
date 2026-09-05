import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memoireserviprox/features/auth/RegisterClientScreen.dart';
import 'package:memoireserviprox/features/auth/RegisterPrestataireScreen.dart';
import '../../core/constants/app_colors.dart';


class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header bleu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Qui êtes-vous ? 👤",
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text("Choisissez votre profil pour créer votre compte",
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildChoiceCard(
                      context: context,
                      icon: Icons.person_outline,
                      label: "Je suis un Client",
                      description: "Je cherche des services de proximité",
                      color: AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterClientScreen())),
                    ),
                    const SizedBox(height: 12),
                    _buildChoiceCard(
                      context: context,
                      icon: Icons.store_outlined,
                      label: "Je suis un Prestataire",
                      description: "Je propose des services professionnels",
                      color: AppColors.green,
                      bgColor: AppColors.greenLight,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPrestataireScreen())),
                    ),
                    const SizedBox(height: 12),
                    _buildChoiceCard(
                      context: context,
                      icon: Icons.directions_car_outlined,
                      label: "Je suis un Agent",
                      description: "Compte créé par votre prestataire",
                      color: AppColors.red,
                      bgColor: AppColors.redLight,
                      isDisabled: true,
                      onTap: () {},
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          text: "Déjà inscrit ? ",
                          style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecond,
                          ),
                          children: [
                            TextSpan(
                              text: "Se connecter",
                              style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(description,
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecond,
                      ),
                    ),
                    if (isDisabled)
                      Text("Non disponible ici",
                        style: GoogleFonts.poppins(
                          fontSize: 9, color: AppColors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isDisabled)
                Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}