// lib/features/prestataire/parametres_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() =>
      _ParametresScreenState();
}

class _ParametresScreenState
    extends State<ParametresScreen> {

  // ← Mode sombre
  bool _isDarkMode = false;

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
        title: Text("Paramètres",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
            CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 8),

            Text("Apparence",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecond,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            // ← Mode clair / sombre
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                  BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border,
                  width: 0.5),
              ),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _isDarkMode
                      ? const Color(0xFF1A1A2E)
                      : AppColors.primaryLight,
                    borderRadius:
                      BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                    color: _isDarkMode
                      ? Colors.white
                      : AppColors.primary,
                    size: 20),
                ),
                title: Text(
                  _isDarkMode
                    ? "Mode sombre"
                    : "Mode clair",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  "Changer l'apparence de l'app",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecond,
                  ),
                ),
                trailing: Switch(
                  value: _isDarkMode,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    setState(
                      () => _isDarkMode = val);
                    // TODO: implémenter ThemeMode
                    ScaffoldMessenger.of(context)
                      .showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                              ? "Mode sombre activé"
                              : "Mode clair activé",
                            style:
                              GoogleFonts.poppins(
                                fontSize: 12)),
                          backgroundColor:
                            AppColors.green,
                          behavior:
                            SnackBarBehavior.floating,
                          duration: const Duration(
                            seconds: 1),
                        ),
                      );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text("À propos",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecond,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                  BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border,
                  width: 0.5),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius:
                          BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.green,
                        size: 20),
                    ),
                    title: Text("Version",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text("1.0.0",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecond,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius:
                          BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 20),
                    ),
                    title: Text("ServiProx",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      "Services de proximité · Sénégal",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecond,
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
}