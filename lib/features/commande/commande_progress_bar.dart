// lib/features/commande/commande_progress_bar.dart
//
// ✅ Widget réutilisable : barre de progression des étapes
//    Utilisé par CommandeDetailScreen (prestataire) ET SuiviCommandeClientScreen (client)
//
// ✅ ARCHITECTURE THÈSE : Zéro if(typeService)
// ✅ Nouveau fichier — rollback = supprimer ce fichier + retirer les imports
//
// Usage :
//   CommandeProgressBar(
//     fullEtapes    : _fullEtapes,       // liste complète calculée par l'appelant
//     currentIndex  : _etapeIndex,       // index actuel (-1 si ANNULEE)
//     accentColor   : AppColors.amber,   // couleur étape active
//     doneColor     : AppColors.green,   // couleur étapes passées (facultatif)
//   )

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class CommandeProgressBar extends StatelessWidget {
  /// Liste complète des étapes calculée par le parent (_fullEtapes).
  final List<String> fullEtapes;

  /// Index de l'étape active dans [fullEtapes] (-1 si annulée).
  final int currentIndex;

  /// Couleur de l'étape active (ex: AppColors.amber pour EN_COURS).
  final Color accentColor;

  /// Couleur des étapes déjà passées (défaut : AppColors.green).
  final Color doneColor;

  const CommandeProgressBar({
    super.key,
    required this.fullEtapes,
    required this.currentIndex,
    required this.accentColor,
    Color? doneColor,
  }) : doneColor = doneColor ?? accentColor;

  // ── Label lisible de chaque étape ─────────────────────────────────────────
  static String labelEtape(String e) {
    switch (e) {
      case 'CREE':             return 'Créée';
      case 'CONFIRMEE':        return 'Confirmée';
      case 'ATTENTE_PAIEMENT': return 'Paiement';
      case 'CLOTUREE':         return 'Clôturée';
      default:
        final s = e.toLowerCase();
        return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = fullEtapes.length;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Barres colorées ──────────────────────────────────────────────────
        Row(
          children: List.generate(total, (i) {
            final done    = currentIndex >= 0 && i <= currentIndex;
            final current = i == currentIndex;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 5,
                decoration: BoxDecoration(
                  color: done
                      ? (current ? accentColor : doneColor)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),

        // ── Labels ───────────────────────────────────────────────────────────
        Row(
          children: fullEtapes.asMap().entries.map((entry) {
            final i     = entry.key;
            final done  = currentIndex >= 0 && i <= currentIndex;
            final cur   = i == currentIndex;
            return Expanded(
              child: Text(
                labelEtape(entry.value),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: done
                      ? (cur ? accentColor : doneColor)
                      : AppColors.textSecond,
                  fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: i == 0
                    ? TextAlign.left
                    : i == total - 1
                        ? TextAlign.right
                        : TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}