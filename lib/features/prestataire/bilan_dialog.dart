// lib/features/prestataire/bilan_dialog.dart
//
// ✅ Dialog bilan / facture — extrait de CommandeDetailScreen
// ✅ ARCHITECTURE THÈSE : Zéro if(typeService)
// ✅ Nouveau fichier — rollback = supprimer ce fichier + retirer l'import
//
// Contenu dynamique config-driven :
//   • Liste des services de la commande (nom × quantité = prix)
//   • Frais de collecte   si commande.fraisCollecte > 0
//   • Frais de livraison  si commande.fraisLivraison > 0
//     → seules les lignes qui s'appliquent sont affichées
//   • Champ montant pré-rempli (modifiable par le prestataire)
//
// Usage :
//   final montant = await BilanDialog.show(
//     context,
//     commande: _cmd,
//     montantInitial: _montantTotal,
//   );
//   if (montant != null) setState(() => _montantTotal = montant);
//
// Retourne double? :
//   null    → prestataire a annulé
//   double  → montant confirmé

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class BilanDialog {
  BilanDialog._(); // Classe utilitaire, pas d'instances

  /// Affiche le dialog bilan et retourne le montant confirmé, ou null si annulé.
  static Future<double?> show(
    BuildContext context, {
    required Map<String, dynamic> commande,
    double montantInitial = 0.0,
  }) async {
    // ── Pré-calcul depuis les prestations de la commande ──────────────────────
    double calculated = 0.0;
    final prestations = commande['prestations'] as List? ??
        (commande['typesPrestation'] as List? ?? []);

    for (final p in prestations) {
      final prix =
          ((p['prixUnitaire'] ?? p['prix'] ?? p['montant'] ?? 0) as num)
              .toDouble();
      final qte = ((p['quantite'] ?? p['qte'] ?? 1) as num).toDouble();
      calculated += prix * qte;
    }

    final fraisCollecte =
        ((commande['fraisCollecte'] ?? commande['frais_collecte']) as num?)
                ?.toDouble() ??
            0.0;
    final fraisLivraison =
        ((commande['fraisLivraison'] ?? commande['frais_livraison']) as num?)
                ?.toDouble() ??
            0.0;
    if (fraisCollecte > 0) calculated += fraisCollecte;
    if (fraisLivraison > 0) calculated += fraisLivraison;

    // Priorité : montant déjà saisi > calcul auto > 0
    final initial = montantInitial > 0
        ? montantInitial
        : calculated > 0
            ? calculated
            : 0.0;

    final ctrl =
        TextEditingController(text: initial > 0 ? initial.toStringAsFixed(0) : '');

    // ── Dialog ────────────────────────────────────────────────────────────────
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BilanDialogContent(
        prestations: prestations,
        fraisCollecte: fraisCollecte,
        fraisLivraison: fraisLivraison,
        ctrl: ctrl,
      ),
    );

    ctrl.dispose();
    return result;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Widget interne (ne pas exporter)
// ════════════════════════════════════════════════════════════════════════════
class _BilanDialogContent extends StatelessWidget {
  final List<dynamic> prestations;
  final double fraisCollecte;
  final double fraisLivraison;
  final TextEditingController ctrl;

  const _BilanDialogContent({
    required this.prestations,
    required this.fraisCollecte,
    required this.fraisLivraison,
    required this.ctrl,
  });

  static String _fmtPrix(double v) =>
      '${v.toStringAsFixed(0)} FCFA';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Bilan de la commande',
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Services ──────────────────────────────────────────────────
            if (prestations.isNotEmpty) ...[
              Text(
                'Services demandés',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecond),
              ),
              const SizedBox(height: 6),
              ...prestations.map((p) {
                final nom = (p['nom'] ?? p['typePrestation'] ?? 'Service')
                    .toString();
                final qte =
                    ((p['quantite'] ?? p['qte'] ?? 1) as num).toInt();
                final prix = ((p['prixUnitaire'] ??
                            p['prix'] ??
                            p['montant'] ??
                            0) as num)
                        .toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$nom × $qte',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        _fmtPrix(prix * qte),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),

              // ── Frais collecte (si activé) ───────────────────────────
              if (fraisCollecte > 0)
                _fraisRow('Frais de collecte', fraisCollecte),

              // ── Frais livraison (si activé) ──────────────────────────
              if (fraisLivraison > 0)
                _fraisRow('Frais de livraison', fraisLivraison),

              const Divider(height: 16),
            ],

            // ── Champ montant total ────────────────────────────────────
            Text(
              'Montant total facturé',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green),
              decoration: InputDecoration(
                suffixText: 'FCFA',
                suffixStyle: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppColors.green, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Ce montant sera visible par le client.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textSecond),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Annuler',
              style: GoogleFonts.poppins(color: AppColors.textSecond)),
        ),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(ctrl.text.trim()) ?? 0.0;
            Navigator.pop(context, v);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text(
            'Confirmer & envoyer',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _fraisRow(String label, double montant) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textPrimary)),
            Text(_fmtPrix(montant),
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber)),
          ],
        ),
      );
}