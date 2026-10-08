// lib/features/auth/otp_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/agent/AgentHomeScreen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import '../home/home_screen.dart';
import '../prestataire/prestataire_home_screen.dart';
import 'dart:async';

class OtpScreen extends StatefulWidget {
  // Téléphone complet avec indicatif
  // Ex: "+221771234569"
  final String telephone;
  final String telephoneAffiche;

  const OtpScreen({
    super.key,
    required this.telephone,
    required this.telephoneAffiche,
  });

  @override
  State<OtpScreen> createState() =>
      _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {

  // ── 6 controllers pour les 6 cases ───────────────
  final List<TextEditingController> _controllers =
    List.generate(6, (_) =>
      TextEditingController());

  // ── 6 FocusNodes pour navigation auto ────────────
  final List<FocusNode> _focusNodes =
    List.generate(6, (_) => FocusNode());

  bool _isLoading  = false;
  bool _canResend  = false;
  int  _secondsLeft = 120; // 2 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Démarrer le timer dès l'ouverture
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Timer 2 minutes ───────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 120;
      _canResend   = false;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 0) {
          t.cancel();
          setState(() => _canResend = true);
        } else {
          setState(() => _secondsLeft--);
        }
      });
  }

  // ── Format timer ──────────────────────────────────
  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:'
           '${s.toString().padLeft(2, '0')}';
  }

  // ── Code saisi complet ────────────────────────────
  String get _code =>
    _controllers.map((c) => c.text).join();

  // ── Vérifier OTP ──────────────────────────────────
  Future<void> _verifier() async {
    if (_code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Entrez le code à 6 chiffres",
            style: GoogleFonts.poppins(
              fontSize: 12)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
        '${ApiConstants.verifyOtp}'
        '?telephone=${widget.telephone}'
        '&code=$_code'),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Sauvegarder token et infos
        await AuthStorage.saveUserData(
          token:  data['token'],
          userId: data['userId'],
          nom:    data['nom'],
          prenom: data['prenom'],
          email:  data['email'],
          role:   data['role'],
        );
        await AuthStorage.saveAdresse(
          data['adresse'] ?? '');

        // Dans _verifier() après récupération token
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) {
                switch (data['role']) {
                  case 'PRESTATAIRE':
                    return const PrestataireHomeScreen();
                  // AJOUT
                  case 'LIVREUR':
                    return const AgentHomeScreen();
                  default:
                    // CLIENT
                    return const HomeScreen();
                }
              }),
            (route) => false,
          );
        }
        // if (mounted) {
        //   // Rediriger selon le rôle
        //   Navigator.pushAndRemoveUntil(
        //     context,
        //     MaterialPageRoute(
        //       builder: (_) {
        //         switch (data['role']) {
        //           case 'PRESTATAIRE':
        //             return const
        //               PrestataireHomeScreen();
        //           default:
        //             return const HomeScreen();
        //         }
        //       }),
        //     (route) => false,
        //   );
        // }
      } else {
        if (mounted) {
          // Effacer les cases
          for (final c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();

          ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  "Code incorrect ou expiré",
                  style: GoogleFonts.poppins(
                    fontSize: 12)),
                backgroundColor: Colors.red,
                behavior:
                  SnackBarBehavior.floating,
              ),
            );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur réseau",
              style: GoogleFonts.poppins(
                fontSize: 12)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Renvoyer OTP ──────────────────────────────────
  Future<void> _renvoyer() async {
    try {
      await http.post(
        Uri.parse(
          '${ApiConstants.baseUrl}'
          '/auth/resend-otp'
          '?telephone=${widget.telephone}'),
      );

      // Réinitialiser le timer
      _startTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Nouveau code envoyé !",
              style: GoogleFonts.poppins(
                fontSize: 12)),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur resend: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
            CrossAxisAlignment.center,
          children: [

            const SizedBox(height: 20),

            // ── Icône ─────────────────────────────
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                  BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.phone_android_outlined,
                color: AppColors.primary,
                size: 40),
            ),

            const SizedBox(height: 24),

            // ── Titre ─────────────────────────────
            Text("Vérification",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Code envoyé au",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecond,
              ),
            ),

            Text(
              widget.telephoneAffiche,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 32),

            // ── 6 cases OTP ───────────────────────
            Row(
              mainAxisAlignment:
                MainAxisAlignment.center,
              children: List.generate(6, (i) =>
                Container(
                  width: 48, height: 56,
                  margin: const EdgeInsets
                    .symmetric(horizontal: 4),
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType:
                      TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
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
                              color: AppColors.primary,
                              width: 2),
                        ),
                      enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                            BorderRadius.circular(12),
                          borderSide:
                            const BorderSide(
                              color: AppColors.border),
                        ),
                    ),
                    // ← Navigation auto entre cases
                    onChanged: (val) {
                      if (val.isNotEmpty &&
                          i < 5) {
                        _focusNodes[i + 1]
                          .requestFocus();
                      }
                      // Auto valider si 6 chiffres
                      if (_code.length == 6) {
                        _verifier();
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Timer ─────────────────────────────
            if (!_canResend)
              Row(
                mainAxisAlignment:
                  MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppColors.textSecond,
                    size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Expire dans $_timerText",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecond,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // ── Bouton valider ────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                    AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                      BorderRadius.circular(12)),
                ),
                onPressed: _isLoading
                  ? null : _verifier,
                child: _isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child:
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5))
                  : Text(
                      "Valider le code",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight:
                          FontWeight.w600,
                      ),
                    ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Renvoyer ──────────────────────────
            Row(
              mainAxisAlignment:
                MainAxisAlignment.center,
              children: [
                Text(
                  "Vous n'avez pas reçu ? ",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecond,
                  ),
                ),
                GestureDetector(
                  onTap: _canResend
                    ? _renvoyer : null,
                  child: Text(
                    "Renvoyer le code",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _canResend
                        ? AppColors.primary
                        : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}