import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memoireserviprox/features/prestataire/prestataire_home_screen.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';
import '../../core/services/auth_storage.dart';
import '../home/home_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // // Redirection après 3 secondes
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (mounted) {
    //     Navigator.pushReplacement(
    //       context,
    //       MaterialPageRoute(builder: (_) => const LoginScreen()),
    //     );
    //   }
    // });
    // Future.delayed(const Duration(seconds: 3), () async {
    //   if (mounted) {
    // // Vérifier si token existe en local
    // final isLoggedIn = await AuthStorage.isLoggedIn();

    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => isLoggedIn
    //       // Déjà connecté → HomeScreen directement
    //       ? const HomeScreen()
    //       // Pas connecté → LoginScreen
    //       : const LoginScreen(),
    //   ),
    // );
    //     }
    // });

    Future.delayed(const Duration(seconds: 3), () async {
  if (mounted) {
    final isLoggedIn = await AuthStorage.isLoggedIn();

    if (!isLoggedIn) {
      // Pas connecté → LoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ← AJOUT : redirection selon le rôle
    final role = await AuthStorage.getRole();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          switch (role.toUpperCase()) {
            case 'PRESTATAIRE':
              // ← Vers dashboard prestataire
              return const PrestataireHomeScreen();
            case 'ADMIN':
              // ← Vers dashboard admin
              //return const AdminHomeScreen();
            default:
              // CLIENT ou autre → HomeScreen
              return const HomeScreen();
          }
        },
      ),
    );
  }
});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    //Icons.local_laundry_service_rounded,
                    Icons.location_on_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Nom de l'app
              Text(
                "ServiProx",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Slogan
              Text(
                "Vos services de proximité,\ndisponibles en un clic",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 60),

              // Barre de chargement
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    // ignore: deprecated_member_use
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 3,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "Chargement...",
                style: GoogleFonts.poppins(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}