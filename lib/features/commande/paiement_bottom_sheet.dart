// lib/features/commande/paiement_bottom_sheet.dart
//
// 💳 Simulation paiement — Wave / Orange Money / Yas
// Utilisé côté CLIENT depuis suivi_commande_client_screen.dart
//
// Retourne Map<String,String>? via Navigator.pop() :
//   { 'operateur': 'WAVE', 'transactionId': 'TXN_...', 'telephone': '77...' }
// Retourne null si l'utilisateur annule.
//
// Architecture thèse : zéro if(typeService)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  MODÈLE OPÉRATEURS
// ═══════════════════════════════════════════════════════════════════════════
class _Operateur {
  final String id;
  final String label;
  final Color color;
  final IconData icon;        // fallback si l'asset n'est pas chargé
  final String assetPath;     // logo PNG dans assets/images/
  const _Operateur(this.id, this.label, this.color, this.icon, this.assetPath);
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class PaiementBottomSheet extends StatefulWidget {
  final double montant;
  final int commandeId;

  const PaiementBottomSheet({
    super.key,
    required this.montant,
    required this.commandeId,
  });

  /// Ouvre le bottom sheet et retourne le résultat du paiement simulé.
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required double montant,
    required int commandeId,
  }) =>
      showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            PaiementBottomSheet(montant: montant, commandeId: commandeId),
      );

  @override
  State<PaiementBottomSheet> createState() => _PaiementBottomSheetState();
}

class _PaiementBottomSheetState extends State<PaiementBottomSheet> {
  static final _operateurs = [
    _Operateur('WAVE',         'Wave',         const Color(0xFF0A85E0), Icons.waves_rounded,   'assets/images/logo_wave.png'),
    _Operateur('ORANGE_MONEY', 'Orange Money', const Color(0xFFFF6600), Icons.circle_outlined, 'assets/images/logo_orange_money.png'),
    _Operateur('YAS',          'Mixx by Yas',  const Color(0xFF8B00C8), Icons.diamond_outlined,'assets/images/logo_yas.png'),
  ];

  String? _selectedId;
  final _telCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String _txId = '';

  _Operateur? get _selectedOp =>
      _selectedId == null ? null : _operateurs.firstWhere((o) => o.id == _selectedId);

  String _genTxId() {
    final rng = Random();
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final rand = (rng.nextInt(89999) + 10000);
    return 'TXN_$ts$rand';
  }

  String _fmt(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return '${buf.toString()} FCFA';
  }

  Future<void> _simuler() async {
    if (_selectedId == null) {
      _snack('Choisissez un opérateur de paiement');
      return;
    }
    final tel = _telCtrl.text.trim();
    if (tel.length < 9) {
      _snack('Numéro de téléphone invalide');
      return;
    }
    setState(() => _loading = true);
    // Simulation réseau : 2 secondes
    await Future.delayed(const Duration(seconds: 2));
    _txId = _genTxId();
    setState(() { _loading = false; _success = true; });
    // Fermer après 1.5 s avec le résultat
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pop(context, {
        'operateur': _selectedId!,
        'transactionId': _txId,
        'telephone': tel,
      });
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _telCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_success) ...[
            // ── Succès ───────────────────────────────────────────────────
            Center(
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 44),
                ),
                const SizedBox(height: 16),
                Text('Paiement effectué !',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(_txId,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecond)),
                const SizedBox(height: 4),
                Text('Votre commande est clôturée.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecond)),
                const SizedBox(height: 8),
              ]),
            ),
          ] else ...[
            // ── Montant ───────────────────────────────────────────────────
            Text('Montant à payer',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond)),
            const SizedBox(height: 2),
            Text(_fmt(widget.montant),
                style: GoogleFonts.poppins(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            const SizedBox(height: 20),

            // ── Choix opérateur ───────────────────────────────────────────
            Text('Mode de paiement',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond)),
            const SizedBox(height: 10),
            Row(
              children: _operateurs.map((op) {
                final sel = _selectedId == op.id;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedId = op.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? op.color.withOpacity(0.08) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? op.color : AppColors.border,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Logo PNG avec fallback icône Flutter
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            op.assetPath,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              op.icon, size: 26,
                              color: sel ? op.color : AppColors.textSecond,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(op.label,
                            style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: sel ? op.color : AppColors.textSecond,
                            ),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // ── Numéro ────────────────────────────────────────────────────
            Text('Numéro de téléphone',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecond)),
            const SizedBox(height: 6),
            TextField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: GoogleFonts.poppins(fontSize: 15,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '77 XXX XX XX',
                hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _selectedOp?.color ?? AppColors.primary,
                      width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // ── Bouton ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _simuler,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedOp?.color ?? AppColors.primary,
                  disabledBackgroundColor:
                      (_selectedOp?.color ?? AppColors.primary).withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Payer ${_fmt(widget.montant)}',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Paiement sécurisé — simulation',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textMuted)),
            ),
          ],
        ],
      ),
    );
  }
}