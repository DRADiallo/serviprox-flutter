import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'pressing_screen.dart';

class PressingCommandeScreen extends StatelessWidget {
  final PressingMock pressing;
  const PressingCommandeScreen({super.key, required this.pressing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Commander — ${pressing.nom}",
          style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("🧺", style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text("Passer commande",
              style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text("En cours d'implémentation...",
              style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecond),
            ),
          ],
        ),
      ),
    );
  }
}