// lib/features/auth/login_agent_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/agent/AgentHomeScreen.dart';
import 'package:memoireserviprox/features/auth/OtpScreen.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import '../agent/AgentHomeScreen.dart';
import 'login_screen.dart';

class LoginAgentScreen extends StatefulWidget {
  const LoginAgentScreen({super.key});

  @override
  State<LoginAgentScreen> createState() =>
      _LoginAgentScreenState();
}

class _LoginAgentScreenState
    extends State<LoginAgentScreen> {

  // ── Controllers ───────────────────────────────────
  final _phoneController = TextEditingController();
  final _pinController   = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Variables ─────────────────────────────────────
  bool _isLoading       = false;
  bool _obscurePin      = true;
  String _selectedIndicatif = '+221';
  String _selectedFlag      = '🇸🇳';

  // ── Indicatifs ────────────────────────────────────
  final List<Map<String, String>> _indicatifs = [
    {'flag': '🇸🇳', 'code': '+221', 'pays': 'Sénégal'},
    {'flag': '🇫🇷', 'code': '+33',  'pays': 'France'},
    {'flag': '🇲🇦', 'code': '+212', 'pays': 'Maroc'},
    {'flag': '🇨🇮', 'code': '+225', 'pays': "Côte d'Ivoire"},
    {'flag': '🇲🇱', 'code': '+223', 'pays': 'Mali'},
    {'flag': '🇬🇳', 'code': '+224', 'pays': 'Guinée'},
    {'flag': '🇧🇫', 'code': '+226', 'pays': 'Burkina Faso'},
    {'flag': '🇬🇧', 'code': '+44',  'pays': 'Royaume-Uni'},
    {'flag': '🇺🇸', 'code': '+1',   'pays': 'États-Unis'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ── Login Agent ───────────────────────────────────
  Future<void> _loginAgent() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final telephone = _phoneController.text
        .trim().replaceAll(' ', '');

    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}'
        '/auth/login/agent'
        '?telephone=$telephone'),
    );

    setState(() => _isLoading = false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ← CHANGEMENT : avant on allait direct
      // vers AgentHomeScreen avec le token
      // Maintenant → OtpScreen car login
      // retourne {message, telephone}
      if (data.containsKey('message')) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                // Téléphone pour l'API
                telephone: telephone,
                // Téléphone affiché
                telephoneAffiche:
                  '$_selectedFlag '
                  '$_selectedIndicatif '
                  '${_phoneController.text.trim()}',
              ),
            ),
          );
        }
        return;
      }

    } else {
      final error = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error['message'] ??
              "Téléphone introuvable",
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
            "Erreur de connexion",
            style: GoogleFonts.poppins(
              fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
  

  // ── Dialog indicatif ──────────────────────────────
  void _showIndicatifDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Choisir l'indicatif",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...(_indicatifs.map((item) =>
            ListTile(
              leading: Text(item['flag']!,
                style: const TextStyle(
                  fontSize: 24)),
              title: Text(item['pays']!,
                style: GoogleFonts.poppins(
                  fontSize: 13)),
              trailing: Text(item['code']!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
              selected: _selectedIndicatif ==
                item['code'],
              selectedTileColor:
                AppColors.greenLight,
              onTap: () {
                setState(() {
                  _selectedIndicatif = item['code']!;
                  _selectedFlag      = item['flag']!;
                });
                Navigator.pop(context);
              },
            ),
          )).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 30),

                // ── Logo ────────────────────────────
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius:
                      BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_outlined,
                    color: AppColors.green,
                    size: 40),
                ),

                const SizedBox(height: 20),

                // ── Titre ────────────────────────────
                Text("Espace Agent",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Connectez-vous avec votre\n"
                  "téléphone et code PIN",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecond,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Téléphone + indicatif ─────────────
                Row(
                  children: [
                    // Indicatif
                    GestureDetector(
                      onTap: _showIndicatifDialog,
                      child: Container(
                        height: 56,
                        padding:
                          const EdgeInsets.symmetric(
                            horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: AppColors.border),
                          borderRadius:
                            BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(_selectedFlag,
                              style: const TextStyle(
                                fontSize: 20)),
                            const SizedBox(width: 4),
                            Text(_selectedIndicatif,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                  FontWeight.w500,
                                color:
                                  AppColors.textPrimary,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textSecond,
                              size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Numéro
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType:
                          TextInputType.phone,
                        style: GoogleFonts.poppins(
                          fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          labelText: "Téléphone",
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecond,
                          ),
                          floatingLabelStyle:
                            GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.green,
                              fontWeight:
                                FontWeight.w500,
                            ),
                          hintText: "77 123 45 67",
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            color: AppColors.green),
                          border: OutlineInputBorder(
                            borderRadius:
                              BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border),
                          ),
                          focusedBorder:
                            OutlineInputBorder(
                              borderRadius:
                                BorderRadius.circular(12),
                              borderSide:
                                const BorderSide(
                                  color: AppColors.green,
                                  width: 1.5),
                            ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Requis";
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Code PIN ──────────────────────────
                // TextFormField(
                //   controller: _pinController,
                //   obscureText: _obscurePin,
                //   keyboardType: TextInputType.number,
                //   maxLength: 6,
                //   style: GoogleFonts.poppins(
                //     fontSize: 18,
                //     fontWeight: FontWeight.w700,
                //     letterSpacing: 8,
                //     color: AppColors.green,
                //   ),
                //   decoration: InputDecoration(
                //     filled: true,
                //     fillColor: Colors.white,
                //     counterText: '',
                //     labelText: "Code PIN (6 chiffres)",
                //     labelStyle: GoogleFonts.poppins(
                //       fontSize: 13,
                //       color: AppColors.textSecond,
                //     ),
                //     floatingLabelStyle:
                //       GoogleFonts.poppins(
                //         fontSize: 12,
                //         color: AppColors.green,
                //         fontWeight: FontWeight.w500,
                //       ),
                //     hintText: "• • • • • •",
                //     hintStyle: GoogleFonts.poppins(
                //       fontSize: 18,
                //       color: AppColors.textMuted,
                //       letterSpacing: 8,
                //     ),
                //     prefixIcon: const Icon(
                //       Icons.pin_outlined,
                //       color: AppColors.green),
                //     suffixIcon: IconButton(
                //       icon: Icon(
                //         _obscurePin
                //           ? Icons.visibility_outlined
                //           : Icons.visibility_off_outlined,
                //         color: AppColors.textSecond,
                //         size: 20),
                //       onPressed: () => setState(
                //         () => _obscurePin =
                //           !_obscurePin),
                //     ),
                //     border: OutlineInputBorder(
                //       borderRadius:
                //         BorderRadius.circular(12),
                //       borderSide: const BorderSide(
                //         color: AppColors.border),
                //     ),
                //     focusedBorder: OutlineInputBorder(
                //       borderRadius:
                //         BorderRadius.circular(12),
                //       borderSide: const BorderSide(
                //         color: AppColors.green,
                //         width: 1.5),
                //     ),
                //   ),
                //   validator: (v) {
                //     if (v == null || v.isEmpty) {
                //       return "Entrez votre code PIN";
                //     }
                //     if (v.length < 6) {
                //       return "Le PIN doit contenir "
                //              "6 chiffres";
                //     }
                //     return null;
                //   },
                // ),

                const SizedBox(height: 8),

                // ← Info PIN
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius:
                      BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.green,
                        size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Votre code PIN vous a été "
                          "communiqué par votre "
                          "prestataire lors de votre "
                          "création de compte.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Bouton connexion ──────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                          BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading
                      ? null : _loginAgent,
                    child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child:
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5))
                      : Text(
                          "Se connecter",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight:
                              FontWeight.w600,
                          ),
                        ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Retour login normal ───────────────
                const Divider(),
                const SizedBox(height: 16),

                Text(
                  "Vous êtes client ou prestataire ?",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecond,
                  ),
                ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const LoginScreen())),
                  child: Row(
                    mainAxisAlignment:
                      MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.arrow_back,
                        color: AppColors.primary,
                        size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Connexion normale",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}