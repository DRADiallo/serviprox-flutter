import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memoireserviprox/core/models/config_prestataire_model.dart';


// ══════════════════════════════════════════════════
// CHAMP DYNAMIQUE UNIQUE
// TEXT  → TextField normal
// NUMBER → TextField numérique
// LIST  → DropdownButtonFormField
// Aucun if(typeService) — tout vient du JSON API
// ══════════════════════════════════════════════════
class ChampDynamiqueWidget extends StatelessWidget {
  final ChampCommandeModel champ;
  final String valeur;
  final ValueChanged<String> onChanged;

  const ChampDynamiqueWidget({
    super.key,
    required this.champ,
    required this.valeur,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label + requis ──────────────────────
          Row(
            children: [
              Text(
                champ.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (champ.requis) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // ── Champ selon le type ─────────────────
          if (champ.type == 'LIST')
            _buildListe(context)
          else
            _buildTexte(),
        ],
      ),
    );
  }

  // ── TextField TEXT ou NUMBER ───────────────────
  Widget _buildTexte() {
    return TextFormField(
      initialValue: valeur,
      keyboardType: champ.type == 'NUMBER'
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: champ.type == 'NUMBER'
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        hintText: champ.type == 'NUMBER'
            ? 'Entrez un nombre'
            : 'Entrez ${champ.label.toLowerCase()}',
        hintStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF1A73E8),
            width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  // ── Dropdown pour type LIST ────────────────────
  Widget _buildListe(BuildContext context) {
    final String valeurSelectionnee =
        champ.valeurs.contains(valeur)
            ? valeur
            : (champ.valeurs.isNotEmpty
                ? champ.valeurs.first
                : '');

    return DropdownButtonFormField<String>(
      value: valeurSelectionnee.isNotEmpty
          ? valeurSelectionnee
          : null,
      onChanged: (v) => onChanged(v ?? ''),
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF1A73E8),
            width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: champ.valeurs
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(v,
                  style: GoogleFonts.poppins(
                    fontSize: 13)),
              ))
          .toList(),
    );
  }
}

// ══════════════════════════════════════════════════
// FORMULAIRE DYNAMIQUE COMPLET
// Génère tous les champs depuis champsCommande
// + champ modeDepot si modesDepot > 1
// ══════════════════════════════════════════════════
class FormulaireDynamiqueWidget extends StatelessWidget {
  final List<ChampCommandeModel> champs;
  final List<String> modesDepot;
  final Map<String, String> valeurs;
  final ValueChanged<Map<String, String>> onChanged;

  const FormulaireDynamiqueWidget({
    super.key,
    required this.champs,
    required this.modesDepot,
    required this.valeurs,
    required this.onChanged,
  });

  void _update(String code, String val) {
    final updated = Map<String, String>.from(valeurs);
    updated[code] = val;
    onChanged(updated);
  }

  // ── Label affiché pour le mode dépôt ──────────
  String _labelMode(String mode) {
    switch (mode) {
      case 'COLLECTE_DOMICILE':
        return ' Collecte à domicile';
      case 'DEPOT_ATELIER':
        return ' Dépôt en atelier';
      case 'LIVRAISON_DOMICILE':
        return ' Livraison à domicile';
      default:
        return mode.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Mode dépôt (si plusieurs options) ────
        if (modesDepot.length > 1) ...[
          Text(
            'Mode de dépôt',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: valeurs['modeDepot'] ??
                modesDepot.first,
            onChanged: (v) =>
                _update('modeDepot', v ?? ''),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF1A1A2E),
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF1A73E8),
                  width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: modesDepot
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        _labelMode(m),
                        style: GoogleFonts.poppins(
                          fontSize: 13),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
        ],

        // ── Champs dynamiques depuis l'API ────────
        ...champs.map((champ) =>
          ChampDynamiqueWidget(
            champ: champ,
            valeur: valeurs[champ.code] ?? '',
            onChanged: (v) =>
                _update(champ.code, v),
          ),
        ),
      ],
    );
  }
}