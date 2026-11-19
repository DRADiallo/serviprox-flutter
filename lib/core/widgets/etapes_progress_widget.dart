import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════
// BARRE D'ÉTAPES DYNAMIQUE
// Les étapes viennent de l'API — aucun if(typeService)
// L'icône est déduite du nom de l'étape
// ══════════════════════════════════════════════════
class EtapesProgressWidget extends StatelessWidget {
  final List<String> etapes;
  final String etapeCourante;
  final Color couleurActive;

  const EtapesProgressWidget({
    super.key,
    required this.etapes,
    required this.etapeCourante,
    this.couleurActive = const Color(0xFF1A73E8),
  });

  // ── Indice de l'étape courante ─────────────────
  int get _indexCourant {
    final idx = etapes.indexOf(etapeCourante);
    return idx < 0 ? 0 : idx;
  }

  // ── Icône déduite du NOM de l'étape ───────────
  // Aucune référence à un type de service
  IconData _iconeEtape(String etape) {
    final e = etape.toLowerCase();
    if (e.contains('collect'))
      return Icons.directions_car_outlined;
    if (e.contains('livr'))
      return Icons.local_shipping_outlined;
    if (e.contains('traitement') ||
        e.contains('traiter') ||
        e.contains('nettoyage') ||
        e.contains('lavage'))
      return Icons.local_laundry_service_outlined;
    if (e.contains('repass'))
      return Icons.iron_outlined;
    if (e.contains('attente') ||
        e.contains('pending'))
      return Icons.hourglass_empty_outlined;
    if (e.contains('terminé') ||
        e.contains('termine') ||
        e.contains('done') ||
        e.contains('complet'))
      return Icons.check_circle_outline;
    if (e.contains('verif') ||
        e.contains('contrôle') ||
        e.contains('controle'))
      return Icons.fact_check_outlined;
    if (e.contains('paiement') ||
        e.contains('payer'))
      return Icons.payment_outlined;
    if (e.contains('photo') ||
        e.contains('preuve'))
      return Icons.camera_alt_outlined;
    if (e.contains('diagnos') ||
        e.contains('examen'))
      return Icons.search_outlined;
    if (e.contains('repar'))
      return Icons.build_outlined;
    if (e.contains('soin') ||
        e.contains('consult'))
      return Icons.medical_services_outlined;
    // Icône générique
    return Icons.radio_button_checked_outlined;
  }

  // ── Label formaté ──────────────────────────────
  String _label(String etape) {
    return etape
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w)
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (etapes.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16, horizontal: 8),
      child: Column(
        children: [
          // ── Ligne d'étapes ──────────────────────
          Row(
            children: List.generate(
              etapes.length,
              (i) {
                final bool fait = i <= _indexCourant;
                final bool courant =
                    i == _indexCourant;

                return Expanded(
                  child: Row(
                    children: [
                      // Cercle étape
                      _cercle(
                        icone: _iconeEtape(etapes[i]),
                        fait: fait,
                        courant: courant,
                      ),
                      // Trait entre étapes
                      if (i < etapes.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < _indexCourant
                                ? couleurActive
                                : Colors.grey
                                    .shade300,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Labels des étapes ───────────────────
          Row(
            children: List.generate(
              etapes.length,
              (i) {
                final bool courant =
                    i == _indexCourant;
                return Expanded(
                  child: Text(
                    _label(etapes[i]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: courant
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: courant
                          ? couleurActive
                          : Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Cercle d'une étape ─────────────────────────
  Widget _cercle({
    required IconData icone,
    required bool fait,
    required bool courant,
  }) {
    return Container(
      width: courant ? 36 : 30,
      height: courant ? 36 : 30,
      decoration: BoxDecoration(
        color: fait
            ? couleurActive
            : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: courant
            ? Border.all(
                color: couleurActive,
                width: 2.5)
            : null,
        boxShadow: courant
            ? [
                BoxShadow(
                  color: couleurActive
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Icon(
        icone,
        size: courant ? 18 : 15,
        color: fait
            ? Colors.white
            : Colors.grey.shade400,
      ),
    );
  }
}