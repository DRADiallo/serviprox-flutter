import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/agent/agent_missions_screen.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import 'photo_preuve_screen.dart';
import '../auth/login_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() =>
      _AgentHomeScreenState();
}

class _AgentHomeScreenState
    extends State<AgentHomeScreen> {

  // ── Variables d'état ──────────────────────────────
  String _nomComplet = '';
  String _telephone  = '';
  bool _disponible   = true;
  bool _isLoading    = true;
  int _currentIndex  = 0;

  // ── Initiales ─────────────────────────────────────
  String get _initiales {
    final parts = _nomComplet.trim().split(' ');
    return parts
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Charger données agent ─────────────────────────
  Future<void> _loadData() async {
    final prenom = await AuthStorage.getPrenom();
    final nom    = await AuthStorage.getNom();
    final tel    = await AuthStorage.getEmail();

    if (mounted) {
      setState(() {
        _nomComplet = '$prenom $nom'.trim();
        _telephone  = tel;
        _isLoading  = false;
      });
    }
  }

  // ── Déconnexion ───────────────────────────────────
  Future<void> _logout() async {
    await AuthStorage.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildAccueil(),
         // _buildMesCommandes(),
         const AgentMissionsScreen(),
          _buildProfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) =>
            setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home, color: AppColors.green),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(
              Icons.list_alt, color: AppColors.green),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person, color: AppColors.green),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  

  // ══ PAGE ACCUEIL ══════════════════════════════════
  Widget _buildAccueil() {
    return Column(
      children: [

        // ── Header vert ───────────────────────────
        Container(
          color: AppColors.green,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16, 8, 16, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge disponibilité
                      GestureDetector(
                        onTap: () => setState(
                          () => _disponible =
                            !_disponible),
                        child: Container(
                          padding:
                            const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6),
                          decoration: BoxDecoration(
                            color: _disponible
                              ? Colors.white
                                  .withValues(alpha: 0.2)
                              : Colors.orange
                                  .withValues(alpha: 0.3),
                            borderRadius:
                              BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _disponible
                                    ? Colors.greenAccent
                                    : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _disponible
                                  ? "Disponible"
                                  : "En mission",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight:
                                    FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Cloche notification
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white
                            .withValues(alpha: 0.15),
                          borderRadius:
                            BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 20),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Infos agent
                  Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white
                            .withValues(alpha: 0.2),
                          borderRadius:
                            BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(_initiales,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment:
                          CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bonjour, $_nomComplet !",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Agent · ServiProx",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Body ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // Statut du jour
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _disponible
                      ? AppColors.greenLight
                      : AppColors.amberLight,
                    borderRadius:
                      BorderRadius.circular(12),
                    border: Border.all(
                      color: _disponible
                        ? AppColors.green
                            .withValues(alpha: 0.3)
                        : AppColors.amber
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _disponible
                          ? Icons.check_circle_outline
                          : Icons.delivery_dining,
                        color: _disponible
                          ? AppColors.green
                          : AppColors.amber,
                        size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          children: [
                            Text(
                              _disponible
                                ? "Vous êtes disponible"
                                : "Vous êtes en mission",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                  FontWeight.w600,
                                color: _disponible
                                  ? AppColors.green
                                  : AppColors.amber,
                              ),
                            ),
                            Text(
                              _disponible
                                ? "En attente de missions"
                                : "Mission en cours",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _disponible
                                  ? AppColors.green
                                  : AppColors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Toggle disponibilité
                      Switch(
                        value: _disponible,
                        activeColor: AppColors.green,
                        onChanged: (val) =>
                          setState(
                            () => _disponible = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text("Mes actions",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Grille actions ─────────────────
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics:
                    const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _buildActionCard(
                      Icons.list_alt_outlined,
                      "Mes missions",
                      "Commandes assignées",
                      AppColors.green,
                      AppColors.greenLight,
                      onTap: () => setState(
                        () => _currentIndex = 1),
                    ),
                    _buildActionCard(
                      Icons.location_on_outlined,
                      "Ma position",
                      "Mettre à jour GPS",
                      AppColors.primary,
                      AppColors.primaryLight,
                      onTap: () {},
                    ),
                    _buildActionCard(
                      Icons.camera_alt_outlined,
                      "Photo preuve",
                      "Collecte / Livraison",
                      AppColors.purple,
                      AppColors.purpleLight,
                      onTap: () => _showChoixTypePreuve(),
                    ),
                    _buildActionCard(
                      Icons.history_outlined,
                      "Historique",
                      "Missions passées",
                      AppColors.amber,
                      AppColors.amberLight,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Dernières missions ─────────────
                Text("Dernières missions",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                      BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          color: AppColors.textMuted,
                          size: 36),
                        const SizedBox(height: 8),
                        Text(
                          "Aucune mission assignée",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecond,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showChoixTypePreuve() {
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
          child: Text("Type de preuve",
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.green),
          title: Text("Collecte client",
            style: GoogleFonts.poppins(
              fontSize: 13)),
          subtitle: Text(
            "Photo avant collecte",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecond)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                  PhotoPreuveScreen(
                    commandeId: 4, // ← dynamique
                    typePreuve: 'COLLECTE_CLIENT',
                    titre: 'Preuve collecte',
                  )));
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.local_shipping_outlined,
            color: AppColors.primary),
          title: Text("Livraison client",
            style: GoogleFonts.poppins(
              fontSize: 13)),
          subtitle: Text(
            "Photo après traitement",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecond)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                  PhotoPreuveScreen(
                    commandeId: 4, // ← dynamique
                    typePreuve: 'LIVRAISON_CLIENT',
                    titre: 'Preuve livraison',
                  )));
          },
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

  // ── Action card ────────────────────────────────────
  Widget _buildActionCard(
    IconData icon,
    String title,
    String desc,
    Color color,
    Color bgColor, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment:
            CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                  BorderRadius.circular(10),
              ),
              child: Icon(icon,
                color: color, size: 20),
            ),
            const Spacer(),
            Text(title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(desc,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══ PAGE MES COMMANDES ════════════════════════════
  // Widget _buildMesCommandes() {
  //   return Scaffold(
  //     backgroundColor: AppColors.background,
  //     appBar: AppBar(
  //       backgroundColor: AppColors.green,
  //       automaticallyImplyLeading: false,
  //       title: Text("Mes missions",
  //         style: GoogleFonts.poppins(
  //           color: Colors.white,
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //         ),
  //       ),
  //     ),
  //     body: Center(
  //       child: Column(
  //         mainAxisAlignment:
  //           MainAxisAlignment.center,
  //         children: [
  //           const Icon(
  //             Icons.delivery_dining_outlined,
  //             size: 60,
  //             color: AppColors.textMuted),
  //           const SizedBox(height: 16),
  //           Text(
  //             "Aucune mission assignée",
  //             style: GoogleFonts.poppins(
  //               fontSize: 15,
  //               color: AppColors.textSecond,
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             "Votre prestataire vous assignera\n"
  //             "des missions bientôt",
  //             textAlign: TextAlign.center,
  //             style: GoogleFonts.poppins(
  //               fontSize: 12,
  //               color: AppColors.textMuted,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // ══ PAGE PROFIL ═══════════════════════════════════
  Widget _buildProfil() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        automaticallyImplyLeading: false,
        title: Text("Mon profil",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const SizedBox(height: 20),

            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius:
                  BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.green
                    .withValues(alpha: 0.3),
                  width: 2),
              ),
              child: Center(
                child: Text(_initiales,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(_nomComplet,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius:
                  BorderRadius.circular(20),
              ),
              child: Text("Agent ServiProx",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Statut disponibilité
            _buildProfilItem(
              Icons.circle,
              "Statut",
              _disponible
                ? "Disponible" : "En mission",
              color: _disponible
                ? AppColors.green : AppColors.amber,
            ),
            _buildProfilItem(
              Icons.phone_outlined,
              "Téléphone",
              _telephone,
            ),
            _buildProfilItem(
              Icons.work_outline,
              "Rôle",
              "Agent / Livreur",
            ),

            const SizedBox(height: 24),

            // Déconnexion
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                    color: Colors.red),
                  padding:
                    const EdgeInsets.symmetric(
                      vertical: 12),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: Text("Déconnexion",
                  style: GoogleFonts.poppins(
                    fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilItem(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon,
            color: color ?? AppColors.green,
            size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment:
              CrossAxisAlignment.start,
            children: [
              Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecond,
                ),
              ),
              Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color ??
                    AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
}