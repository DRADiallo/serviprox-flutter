import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memoireserviprox/features/auth/LoginAgentScreen.dart';
import 'package:memoireserviprox/features/auth/OtpScreen.dart';
import 'package:memoireserviprox/features/prestataire/prestataire_home_screen.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  // ← AJOUT variables indicatif

  final _phoneController = TextEditingController();
  String _selectedIndicatif = '+221';
  String _selectedFlag = '🇸🇳';


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── MÉTHODE _login() MISE À JOUR ──────────────────
void _login() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      // ── Appel API réel Spring Boot ───────────────
      // POST /api/auth/login
      // On envoie email + motDePasse en JSON
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'motDePasse': _passwordController.text,
          // ← indicatif + numéro sans espaces
          'telephone': 
            _phoneController.text.trim()
              .replaceAll(' ', ''),
                }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        // ── Connexion réussie ────────────────────
        // jsonDecode = convertit la réponse JSON en Map
        final data = jsonDecode(response.body);

        // ← AJOUT : Admin → pas sur mobile !
        // if (data['role'] == 'ADMIN') {
        //   if (mounted) {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(
        //         content: Text(
        //           "Accès admin via interface "
        //           "web uniquement"),
        //         backgroundColor: Colors.red,
        //         behavior: SnackBarBehavior.floating,
        //       ),
        //     );
        //   }
        //   return; // ← Stopper ici !
        // }

        // Sauvegarder les données dans SharedPreferences
        // → Disponibles même après fermeture de l'app
        // await AuthStorage.saveUserData(
        //   token:  data['token'],
        //   userId: data['userId'],
        //   nom:    data['nom'],
        //   prenom: data['prenom'],
        //   email:  data['email'],
        //   role:   data['role'],
        // );

        //  ← AJOUT : sauvegarder l'adresse depuis le login
        await AuthStorage.saveAdresse( data['adresse'] ?? '');

        // Rediriger vers HomeScreen
        // pushAndRemoveUntil = supprime tout l'historique
        // L'utilisateur ne peut pas revenir au Login
        // 
        //
        if (data.containsKey('message')) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpScreen(
                  // Téléphone pour l'API
                  telephone: _phoneController.text
                    .trim().replaceAll(' ', ''),
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
        // ── Erreur serveur ───────────────────────
        // Afficher message d'erreur
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error['message'] ??
                "Email ou mot de passe incorrect",
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

    } catch (e) {
      // ── Erreur réseau ────────────────────────────
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Erreur de connexion — "
              "Vérifiez votre réseau"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
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
        // Handle
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
        // ← Liste des pays
        ...(_indicatifs.map((item) =>
          ListTile(
            leading: Text(item['flag']!,
              style: const TextStyle(
                fontSize: 24)),
            title: Text(item['pays']!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: Text(item['code']!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            // ← Coché si sélectionné
            selected: _selectedIndicatif ==
              item['code'],
            selectedTileColor:
              AppColors.primaryLight,
            onTap: () {
              setState(() {
                _selectedIndicatif =
                  item['code']!;
                _selectedFlag =
                  item['flag']!;
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

// ← Liste des indicatifs
final List<Map<String, String>> _indicatifs = [
  {'flag': '🇸🇳', 'code': '+221', 'pays': 'Sénégal'},
  {'flag': '🇫🇷', 'code': '+33',  'pays': 'France'},
  {'flag': '🇲🇦', 'code': '+212', 'pays': 'Maroc'},
  {'flag': '🇨🇮', 'code': '+225', 'pays': "Côte d'Ivoire"},
  {'flag': '🇲🇱', 'code': '+223', 'pays': 'Mali'},
  {'flag': '🇬🇳', 'code': '+224', 'pays': 'Guinée'},
  {'flag': '🇧🇫', 'code': '+226', 'pays': 'Burkina Faso'},
  {'flag': '🇹🇬', 'code': '+228', 'pays': 'Togo'},
  {'flag': '🇧🇯', 'code': '+229', 'pays': 'Bénin'},
  {'flag': '🇳🇪', 'code': '+227', 'pays': 'Niger'},
  {'flag': '🇬🇧', 'code': '+44',  'pays': 'Royaume-Uni'},
  {'flag': '🇺🇸', 'code': '+1',   'pays': 'États-Unis'},
];

  // void _login() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() => _isLoading = true);
  //     await Future.delayed(const Duration(seconds: 2));
  //     setState(() => _isLoading = false);
  //     if (mounted) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (_) => const HomeScreen()),
  //       );
  //     }
  //   }
  // }

  // ← AJOUT : Mot de passe oublié
  void _forgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => _ForgotPasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 40),

                // Logo + titre
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          //Icons.local_laundry_service_rounded,
                          Icons.location_on_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "ServiProx",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Titre
                Text(
                  "Bienvenue ! 👋",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Connectez-vous à votre compte",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecond,
                  ),
                ),

                const SizedBox(height: 28),

                // ← CHANGEMENT 1 : Label flottant Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    // ← labelText au lieu de Text() au-dessus
                    labelText: "Adresse email",
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecond,
                    ),
                    floatingLabelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    hintText: "votre@email.com",
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer votre email";
                    }
                    if (!value.contains("@")) {
                      return "Email invalide";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ← CHANGEMENT 2 : Label flottant + icône clé horizontale
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    // ← labelText au lieu de Text() au-dessus
                    labelText: "Mot de passe",
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecond,
                    ),
                    floatingLabelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    hintText: "••••••••",
                    // ← CHANGEMENT 3 : Clé horizontale
                    // prefixIcon: Transform.rotate(
                    //   // 180° = clé horizontale
                    //   angle: 3.1416,
                    //   child: const Icon(
                    //     Icons.key_outlined,
                    //     color: AppColors.primary,
                    //   ),
                    // ),
                    prefixIcon: Transform.scale(
                    // ← Miroir horizontal
                    scaleX: -1,
                    child: Transform.rotate(
                      angle: 3.1416,
                      child: const Icon(
                        Icons.key_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecond,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer votre mot de passe";
                    }
                    if (value.length < 6) {
                      return "Minimum 6 caractères";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

            // ← AJOUT : Champ téléphone avec indicatif
            Row(
              children: [
                // ── Indicatif pays ─────────────────────
                GestureDetector(
                  onTap: () => _showIndicatifDialog(),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10),
                    decoration: BoxDecoration(
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
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
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

                // ── Numéro téléphone ───────────────────
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Numéro téléphone",
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecond,
                      ),
                      floatingLabelStyle:
                        GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      hintText: "77 123 45 67",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Entrez votre téléphone";
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

                const SizedBox(height: 8),

                // Mot de passe oublié
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    // ← Appel du bottom sheet
                    onPressed: _forgotPassword,
                    child: Text(
                      "Mot de passe oublié ?",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Bouton Se connecter
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "Se connecter",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Séparateur
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "ou continuer avec",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.border)),
                  ],
                ),

                const SizedBox(height: 16),

                // Bouton Google
                // SizedBox(
                //   width: double.infinity,
                //   height: 50,
                //   child: OutlinedButton.icon(
                //     onPressed: () {},
                //     style: OutlinedButton.styleFrom(
                //       side: const BorderSide(color: AppColors.border),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(10),
                //       ),
                //     ),
                //     icon: const Text(
                //       "G",
                //       style: TextStyle(
                //         fontSize: 18,
                //         fontWeight: FontWeight.bold,
                //         color: Colors.red,
                //       ),
                //     ),
                //     // label: Text(
                //     //   "Continuer avec Google",
                //     //   style: GoogleFonts.poppins(
                //     //     fontSize: 13,
                //     //     color: AppColors.textPrimary,
                //     //   ),
                //     // ),
                //   ),
                // ),

                const SizedBox(height: 24),

                // Lien inscription
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Pas encore de compte ? ",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecond,
                        ),
                        children: [
                          TextSpan(
                            text: "S'inscrire",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // ← AJOUT : Lien vers LoginAgentScreen
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const LoginAgentScreen())),
                  child: Row(
                    mainAxisAlignment:
                      MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delivery_dining_outlined,
                        color: AppColors.green,
                        size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Vous êtes un agent ? "
                        "Connectez-vous ici",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20)


                //const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════
// WIDGET : Mot de passe oublié (BottomSheet)
// ════════════════════════════════════════
class _ForgotPasswordSheet extends StatefulWidget {
  @override
  State<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState
    extends State<_ForgotPasswordSheet> {

  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ← Evite que le clavier cache le sheet
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Indicateur
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

          Text(
            "Mot de passe oublié ?",
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Entrez votre adresse email pour recevoir "
            "un lien de réinitialisation.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecond,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          if (!_sent) ...[
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Adresse email",
                labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecond,
                ),
                floatingLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.primary,
                ),
                hintText: "votre@email.com",
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_emailCtrl.text.contains("@")) {
                    setState(() => _sent = true);
                  }
                },
                child: Text(
                  "Envoyer le lien",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ] else ...[
            // ← Message de confirmation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Lien envoyé ! Vérifiez votre boîte email.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Annuler",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecond,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  
}