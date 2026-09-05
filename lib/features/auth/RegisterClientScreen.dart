import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';


class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() =>
      _RegisterClientScreenState();
}

class _RegisterClientScreenState
    extends State<RegisterClientScreen> {

  final _formKey             = GlobalKey<FormState>();
  // ← CHANGEMENT 1 : Prénom + Nom séparés
  final _prenomController    = TextEditingController();
  final _nomController       = TextEditingController();
  final _emailController     = TextEditingController();
  final _phoneController     = TextEditingController();
  final _adresseController   = TextEditingController();
  final _passwordController  = TextEditingController();
  final _confirmController   = TextEditingController();
  bool _obscurePassword      = true;
  bool _obscureConfirm       = true;
  bool _isLoading            = false;

  // ← AJOUT : Force du mot de passe
  String _passwordStrength   = "";
  Color _strengthColor       = Colors.transparent;
  double _strengthValue      = 0;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _adresseController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── FORCE MOT DE PASSE ───────────────────────────
  void _checkPasswordStrength(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordStrength = "";
        _strengthValue = 0;
        _strengthColor = Colors.transparent;
      } else if (value.length < 6) {
        _passwordStrength = "Faible";
        _strengthValue = 0.25;
        _strengthColor = Colors.red;
      } else if (value.length < 8 ||
          !RegExp(r'[A-Z]').hasMatch(value) ||
          !RegExp(r'[0-9]').hasMatch(value)) {
        _passwordStrength = "Moyen";
        _strengthValue = 0.6;
        _strengthColor = Colors.orange;
      } else if (value.length >= 8 &&
          RegExp(r'[A-Z]').hasMatch(value) &&
          RegExp(r'[0-9]').hasMatch(value) &&
          RegExp(r'[!@#\$%^&*]').hasMatch(value)) {
        _passwordStrength = "Très fort";
        _strengthValue = 1.0;
        _strengthColor = Colors.green;
      } else {
        _passwordStrength = "Fort";
        _strengthValue = 0.85;
        _strengthColor = AppColors.primary;
      }
    });
  }

  // ── VALIDATEURS ───────────────────────────────────
  String? _validatePrenom(String? value) {
    if (value == null || value.isEmpty) return "Prénom requis";
    if (value.length < 2) return "Minimum 2 caractères";
    if (RegExp(r'[0-9]').hasMatch(value)) {
      return "Pas de chiffres dans le prénom";
    }
    return null;
  }

  String? _validateNom(String? value) {
    if (value == null || value.isEmpty) return "Nom requis";
    if (value.length < 2) return "Minimum 2 caractères";
    if (RegExp(r'[0-9]').hasMatch(value)) {
      return "Pas de chiffres dans le nom";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email requis";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(value)) {
      return "Email invalide (ex: nom@email.com)";
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Téléphone requis";
    }
    final clean = value
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (!RegExp(r'^\+?221[0-9]{9}$').hasMatch(clean) &&
        !RegExp(r'^[0-9]{9}$').hasMatch(clean)) {
      return "Format invalide (ex: +221 77 000 00 00)";
    }
    return null;
  }

  String? _validateAdresse(String? value) {
    if (value == null || value.isEmpty) {
      return "Adresse requise";
    }
    if (value.length < 5) return "Adresse trop courte";
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Mot de passe requis";
    }
    if (value.length < 8) return "Minimum 8 caractères";
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Au moins 1 majuscule";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Au moins 1 chiffre";
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return "Confirmation requise";
    }
    if (value != _passwordController.text) {
      return "Les mots de passe ne correspondent pas";
    }
    return null;
  }
  void _register() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      // ← Appel API réel
      final response = await http.post(
        Uri.parse(ApiConstants.registerClient),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nom':              _nomController.text.trim(),
          'prenom':           _prenomController.text.trim(),
          'email':            _emailController.text.trim(),
          'telephone':        _phoneController.text.trim(),
          'adressePrincipale':_adresseController.text.trim(),
          'motDePasse':       _passwordController.text,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ← Sauvegarder dans SharedPreferences
        // comme après le login !
        await AuthStorage.saveUserData(
          token:  data['token'],
          userId: data['userId'],
          nom:    data['nom'],
          prenom: data['prenom'],
          email:  data['email'],
          role:   data['role'],
        );

        // Ajout : Sauvegarder l'adresse principale
        await AuthStorage.saveAdresse(_adresseController.text.trim());

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error['message'] ??
                "Erreur lors de l'inscription"),
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
          const SnackBar(
            content: Text(
              "Erreur réseau — Vérifiez votre connexion"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

  // void _register() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() => _isLoading = true);
  //     await Future.delayed(const Duration(seconds: 2));
  //     setState(() => _isLoading = false);
  //     if (mounted) {
  //       Navigator.pushAndRemoveUntil(
  //         context,
  //         MaterialPageRoute(
  //           builder: (_) => const HomeScreen()),
  //         (route) => false,
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // ══ HEADER BLEU ══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              color: AppColors.primary,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Inscription Client",
                        style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text("Accès à tous les services",
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ══ FORMULAIRE ══
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                              color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Accès immédiat après inscription.",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ← CHANGEMENT 2 : Prénom + Nom côte à côte
                      Row(
                        children: [
                          Expanded(
                            child: _buildFloatField(
                              label: "Prénom",
                              hint: "Ex : Awa",
                              icon: Icons.person_outline,
                              controller: _prenomController,
                              validator: _validatePrenom,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFloatField(
                              label: "Nom",
                              hint: "Ex : Seck",
                              icon: Icons.person_outline,
                              controller: _nomController,
                              validator: _validateNom,
                            ),
                          ),
                        ],
                      ),

                      _buildFloatField(
                        label: "Adresse email",
                        hint: "awa@email.com",
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      _buildFloatField(
                        label: "Téléphone",
                        hint: "77 000 00 00",
                        icon: Icons.phone_outlined,
                        controller: _phoneController,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                      ),

                      _buildFloatField(
                        label: "Adresse principale",
                        hint: "Ex : Médina, Dakar",
                        icon: Icons.location_on_outlined,
                        controller: _adresseController,
                        validator: _validateAdresse,
                      ),

                      // ← CHANGEMENT 3 : Mot de passe + force
                      _buildPasswordFloat(
                        label: "Mot de passe",
                        hint: "Min. 8 car., 1 majuscule, 1 chiffre",
                        controller: _passwordController,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                        validator: _validatePassword,
                        onChanged: _checkPasswordStrength,
                      ),

                      // ← AJOUT : Indicateur force mot de passe
                      if (_passwordStrength.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _strengthValue,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _strengthColor),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Force : $_passwordStrength",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _strengthColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      _buildPasswordFloat(
                        label: "Confirmer le mot de passe",
                        hint: "Répétez votre mot de passe",
                        controller: _confirmController,
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                        validator: _validateConfirm,
                      ),

                      const SizedBox(height: 8),

                      // Bouton créer compte
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                                )
                              : Text(
                                  "Créer mon compte Client",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CHAMP LABEL FLOTTANT ─────────────────────────
  Widget _buildFloatField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          // ← Label flottant
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecond,
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        validator: validator,
      ),
    );
  }

  // ── CHAMP MOT DE PASSE LABEL FLOTTANT ────────────
  Widget _buildPasswordFloat({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecond,
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          // ← Clé horizontale comme Login
          prefixIcon: Transform.scale(
            scaleX: -1,
            child: Transform.rotate(
              angle: 3.1416,
              child: const Icon(
                Icons.key_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecond,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
