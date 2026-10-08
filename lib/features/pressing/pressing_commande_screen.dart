import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import 'pressing_screen.dart';

class PressingCommandeScreen extends StatefulWidget {
  final PressingModel pressing;

  const PressingCommandeScreen({
    super.key,
    required this.pressing,
  });

  @override
  State<PressingCommandeScreen> createState() =>
      _PressingCommandeScreenState();
}

class _PressingCommandeScreenState
    extends State<PressingCommandeScreen> {

  // ── Mode de dépôt sélectionné ─────────────────────
  String _modeDepot = 'COLLECTE_DOMICILE';

  final _descriptionColisController =
  TextEditingController();

  @override
  void dispose() {
    _descriptionColisController.dispose();
    super.dispose();
  }

  // ── Prestations sélectionnées ─────────────────────
  // Map<nomPrestation, quantité>
  final Map<String, int> _selections = {};

  // ── Chargement ────────────────────────────────────
  bool _isLoading = false;

  // ── Prestations disponibles ────────────────────────
  // Viennent de configData du prestataire
  List<Map<String, dynamic>> get _prestations {
    final List<Map<String, dynamic>> result = [];

    // Services configurés par le prestataire
    for (final service in widget.pressing.services) {
      result.add({
        'nom': service,
        'prix': _getPrix(service),
        'unite': _getUnite(service),
        'icon': _getIcon(service),
      });
    }

    // Ajouter option Express si disponible
    if (widget.pressing.hasExpress) {
      result.add({
        'nom': 'Option Express',
        'prix': 0,
        'unite': 'forfait',
        'icon': Icons.bolt_outlined,
        'isOption': true,
      });
    }

    return result;
  }

  // ── Prix depuis tarifsPersonnalises ───────────────
  

  // ── Unité selon le service ─────────────────────────
  double _getPrix(String service) {
  final tarifs = widget.pressing.tarifs;
  
  // ← Chercher directement par nom exact
  if (tarifs.containsKey(service)) {
    return (tarifs[service] ?? 0).toDouble();
  }
  
  // ← Cherche par correspondance partielle
  final s = service.toLowerCase();
  for (final entry in tarifs.entries) {
    if (entry.key.toLowerCase().contains(s) ||
        s.contains(entry.key.toLowerCase())) {
      return (entry.value ?? 0).toDouble();
    }
  }
  
  return 0.0;
}
  String _getUnite(String service) {
    final s = service.toLowerCase();
    if (s.contains('kilo') || s.contains('lavage')) {
      return 'kg';
    }
    return 'pièce';
  }

  // ── Icône selon le service ─────────────────────────
  IconData _getIcon(String service) {
    final s = service.toLowerCase();
    if (s.contains('kilo') || s.contains('lavage')) {
      return Icons.local_laundry_service_outlined;
    } else if (s.contains('boubou') ||
               s.contains('bazin')) {
      return Icons.checkroom_outlined;
    } else if (s.contains('sec')) {
      return Icons.dry_cleaning_outlined;
    } else if (s.contains('gommage') ||
               s.contains('traitement')) {
      return Icons.auto_fix_high_outlined;
    } else if (s.contains('repassage')) {
      return Icons.iron_outlined;
    } else if (s.contains('blanchissage')) {
      return Icons.bubble_chart_outlined;
    } else {
      return Icons.star_outline;
    }
  }

  // ── Total calculé dynamiquement ───────────────────
  double get _total {
    double total = 0;
    for (final entry in _selections.entries) {
      if (entry.value > 0) {
        final presta = _prestations.firstWhere(
          (p) => p['nom'] == entry.key,
          orElse: () => {'prix': 0},
        );
        total += (presta['prix'] as double) * entry.value;
      }
    }
    return total;
  }

  // ── Nombre d'articles sélectionnés ────────────────
  int get _totalArticles {
    return _selections.values
      .fold(0, (sum, qty) => sum + qty);
  }

  // ── Soumettre la commande ──────────────────────────
  Future<void> _commander() async {
    if (_selections.isEmpty ||
        _selections.values.every((q) => q == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Sélectionnez au moins une prestation",
            style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      // Construire les lignes de commande
      final lignes = _selections.entries
        .where((e) => e.value > 0)
        .map((e) {
          final presta = _prestations.firstWhere(
            (p) => p['nom'] == e.key,
            orElse: () => {
              'prix': 0.0,
              'unite': 'pièce',
            },
          );
          return {
            'typePrestation': e.key,
            'quantite': e.value,
            'unite': presta['unite'] ?? 'pièce',
            'prixUnitaire': presta['prix'] ?? 0.0,
            'instructions': '',
          };
        }).toList();

      final response = await http.post(
        Uri.parse(
          '${ApiConstants.commandes}/client/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'prestataireId': widget.pressing.id,
          'modeDepot': _modeDepot,
          'descriptionColis':
            _descriptionColisController.text.trim(),
          'lignes': lignes,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        // ← Commande réussie !
        _showSuccessDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Erreur lors de la commande",
                style: GoogleFonts.poppins(
                  fontSize: 12)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Erreur réseau",
              style: GoogleFonts.poppins(
                fontSize: 12)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Dialog succès ──────────────────────────────────
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text("Commande envoyée !",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Votre commande a été transmise à "
              "${widget.pressing.nomCommercial}. "
              "Vous serez contacté sous peu.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecond,
              ),
            ),
            const SizedBox(height: 16),
            // Récapitulatif
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _recapRow(
                    "Total",
                    "${_total.toInt()} FCFA"),
                  _recapRow(
                    "Articles",
                    "$_totalArticles articles"),
                  _recapRow(
                    "Mode",
                    _modeDepot == 'COLLECTE_DOMICILE'
                      ? "Collecte domicile"
                      : "Dépôt atelier"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Retour à l'accueil
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst);
              },
              child: Text("Retour à l'accueil",
                style: GoogleFonts.poppins(
                  fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne récapitulatif ────────────────────────────
  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecond)),
          Text(value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Commander",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(widget.pressing.nomCommercial,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white
                  .withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Mode de dépôt ──────────────────────
            Text("Mode de dépôt",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Collecte domicile
            if (widget.pressing.hasCollecte)
              _buildModeCard(
                icon: "🏠",
                title: "Collecte à domicile",
                subtitle:
                  "Agent vient chez vous · +500 FCFA",
                value: 'COLLECTE_DOMICILE',
              ),

            const SizedBox(height: 8),

            // Dépôt atelier
            _buildModeCard(
              icon: "🏪",
              title: "Dépôt en atelier",
              subtitle:
                "Vous déposez, on livre retour",
              value: 'DEPOT_ATELIER',
            ),

            const SizedBox(height: 24),

            // ← AJOUT : Description des articles
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border, width: 0.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius:
                            BorderRadius.circular(10)),
                        child: const Icon(
                          Icons.list_alt_outlined,
                          color: AppColors.primary,
                          size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Décrivez vos articles",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              "Optionnel · aide l'agent "
                              "à identifier vos articles",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionColisController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 12),
                    decoration: InputDecoration(
                      hintText:
                        "Ex: 2 pantalons noirs,\n"
                        "3 chemises blanches,\n"
                        "1 boubou bazin bleu...",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted),
                      contentPadding:
                        const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                          BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Prestations ────────────────────────
            Text("Choisissez vos prestations",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Prix configurés par le prestataire",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecond,
              ),
            ),
            const SizedBox(height: 12),

            // ← Prestations dynamiques !
            ..._prestations.map((presta) =>
              _buildPrestationCard(presta)),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // ── Barre de total + bouton commander ─────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                .withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Récapitulatif rapide
            if (_totalArticles > 0) ...[
              Row(
                mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$_totalArticles article(s)",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecond,
                    ),
                  ),
                  Text(
                    "${_total.toInt()} FCFA",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Bouton commander
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading
                  ? null : _commander,
                child: _isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _totalArticles > 0
                            ? "Confirmer — "
                              "${_total.toInt()} FCFA"
                            : "Confirmer la commande",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carte mode de dépôt ────────────────────────────
  Widget _buildModeCard({
    required String icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final bool isSelected = _modeDepot == value;
    return GestureDetector(
      onTap: () => setState(
        () => _modeDepot = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
            ? AppColors.primaryLight
            : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
              ? AppColors.primary
              : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(icon,
              style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                  CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    ),
                  ),
                  Text(subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecond)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Carte prestation avec quantité ────────────────
  Widget _buildPrestationCard(
      Map<String, dynamic> presta) {
    final String nom = presta['nom'];
    final double prix = presta['prix'] as double;
    final String unite = presta['unite'] as String;
    final IconData icon = presta['icon'] as IconData;
    final int qty = _selections[nom] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qty > 0
            ? AppColors.primary
            : AppColors.border,
          width: qty > 0 ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: qty > 0
                ? AppColors.primaryLight
                : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
              color: qty > 0
                ? AppColors.primary
                : AppColors.textMuted,
              size: 20),
          ),
          const SizedBox(width: 12),

          // Nom + prix
          Expanded(
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [
                Text(nom,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  prix > 0
                    ? "${prix.toInt()} FCFA / $unite"
                    : "Sur devis",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Sélecteur quantité + / -
          Row(
            children: [
              // Bouton -
              GestureDetector(
                onTap: qty > 0
                  ? () => setState(() =>
                      _selections[nom] = qty - 1)
                  : null,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: qty > 0
                      ? AppColors.primary
                      : AppColors.border,
                    borderRadius:
                      BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove,
                    color: Colors.white, size: 16),
                ),
              ),

              // Quantité
              SizedBox(
                width: 32,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: qty > 0
                      ? AppColors.primary
                      : AppColors.textMuted,
                  ),
                ),
              ),

              // Bouton +
              GestureDetector(
                onTap: () => setState(() =>
                  _selections[nom] = qty + 1),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                      BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add,
                    color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

