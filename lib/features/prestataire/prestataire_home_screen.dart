import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:memoireserviprox/features/prestataire/CommandeDetailScreen.dart';
import 'package:memoireserviprox/features/prestataire/PrestataireConfigScreen.dart';
import 'package:memoireserviprox/features/prestataire/parametres_screen.dart';
import 'package:memoireserviprox/features/prestataire/prestataire_agents_screen.dart';
import 'package:memoireserviprox/features/prestataire/prestataire_commandes_screen.dart';
import 'package:memoireserviprox/features/prestataire/prestataire_statistiques_screen.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

import '../auth/login_screen.dart';

class PrestataireHomeScreen extends StatefulWidget {
  const PrestataireHomeScreen({super.key});

  @override
  State<PrestataireHomeScreen> createState() =>
      _PrestataireHomeScreenState();
}

class _PrestataireHomeScreenState
    extends State<PrestataireHomeScreen> {

  // ── Variables d'état ──────────────────────────────
  int _currentIndex = 0;
  String _nomCommercial = '';
  String _prenom = '';
  String _nom = '';
  String _email = '';
  String _zone = '';
  int _countCommandes = 0;
  int _countEnCours = 0;
  int _countAgents = 0;
  bool _isLoading = true;
  int? _prestataireId;

  // Variables config récapitulatif
  bool _configExiste = false;
  //Map<String, dynamic> _tarifs = {};
  Map<String, dynamic> _options = {};
  List<Map<String, dynamic>> _prestationsConfig = [];
  // ← AJOUT en haut de la classe
  List<dynamic> _dernieresCommandes = [];
  String _zoneConfig = '';

  // ── Initiales ─────────────────────────────────────
  String get _initiales {
    return _nomCommercial
      .trim()
      .split(' ')
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


  // ── Charger données ───────────────────────────────
//   
  Future<void> _loadData() async {
  final prenom = await AuthStorage.getPrenom();
  final nom    = await AuthStorage.getNom();
  final email  = await AuthStorage.getEmail();
  final zone   = await AuthStorage.getAdresse();
  final userId = await AuthStorage.getUserId();
  final token  = await AuthStorage.getToken();

  // ← Charger config + compteurs en parallèle
  await Future.wait([
    _loadConfig(userId, token),
    _loadCompteurs(userId, token),
  ]);

  if (mounted) {
    setState(() {
      _prenom        = prenom;
      _nom           = nom;
      _email         = email;
      _prestataireId = userId;
      _nomCommercial =
        prenom.isNotEmpty
          ? '$prenom $nom' : nom;
      _isLoading = false;
    });
  }
}

// ── Charger config prestataire ────────────────────
Future<void> _loadConfig(
    int? userId, String? token) async {
  try {
    final configResp = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/prestataire'
        '/config/$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (configResp.statusCode == 200) {
      final data = jsonDecode(configResp.body);

      // Parser les tarifs
      Map<String, dynamic> tarifs = {};
      if (data['tarifsPersonnalises'] != null) {
        tarifs = jsonDecode(
          data['tarifsPersonnalises']);
      }

      // Parser les options
      Map<String, dynamic> options = {};
      if (data['optionsActives'] != null) {
        options = jsonDecode(
          data['optionsActives']);
      }

      // Parser les prestations
      List<Map<String, dynamic>> prestations = [];
          if (data['prestationsAjoutees'] != null) {
            final raw = jsonDecode(
              data['prestationsAjoutees']) as List;
            for (final item in raw) {
              if (item is Map) {
                // ← Nouveau format JSON
                prestations.add({
                  'nom':   item['nom']?.toString() ?? '',
                  'prix':  item['prix'] ?? 0,
                  'unite': item['unite']?.toString()
                          ?? 'pièce',
                });
              } else {
                // ← Ancien format "nom:prix"
                final parts = item.toString().split(':');
                prestations.add({
                  'nom':   parts[0].trim(),
                  'prix':  double.tryParse(
                    parts.length > 1
                      ? parts[1].trim() : '0') ?? 0,
                  'unite': 'pièce',
                });
              }
            }
          }
          // ← AJOUT : charger aussi tarifsPersonnalises
          // (si prestationsAjoutees vide)
          if (prestations.isEmpty &&
              data['tarifsPersonnalises'] != null) {
            final tarifs = jsonDecode(
              data['tarifsPersonnalises'])
              as Map<String, dynamic>;
            for (final entry in tarifs.entries) {
              prestations.add({
                'nom':   entry.key,
                'prix':  entry.value ?? 0,
                'unite': 'pièce',
              });
            }
          }

      if (mounted) {
        setState(() {
          _configExiste      = true;
          //_tarifs            = tarifs;
          _options           = options;
          _prestationsConfig = prestations;
          _zoneConfig =
            data['zoneCouverture'] ?? '';
          _zone = _zoneConfig;
        });
      }
    }
  } catch (e) {
    debugPrint("Erreur config: $e");
  }
}

// ── Charger compteurs dynamiques ──────────────────
Future<void> _loadCompteurs(
    int? userId, String? token) async {
  try {

    // 1. ← Compteur commandes
    final cmdResp = await http.get(
      Uri.parse(
        '${ApiConstants.commandes}'
        '/prestataire/$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (cmdResp.statusCode == 200) {
      final List<dynamic> commandes =
          jsonDecode(cmdResp.body);

      // ← Compter par statut
      final enCours = commandes.where((c) =>
        c['statut'] == 'CREE' ||
        c['statut'] == 'CONFIRMEE' ||
        c['statut'] == 'EN_TRAITEMENT'
      ).length;

      if (mounted) {
        setState(() {
          _countCommandes = commandes.length;
          _countEnCours   = enCours;
        });
      }
    }

    // 2. ← Compteur agents actifs
    final agentResp = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/agent'
        '/prestataire/$userId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );

    if (agentResp.statusCode == 200) {
      final List<dynamic> agents =
          jsonDecode(agentResp.body);

      if (mounted) {
        setState(() {
          _countAgents = agents
            .where((a) =>
              a['statut'] == 'ACTIF')
            .length;
        });
      }
    }

  } catch (e) {
    debugPrint("Erreur compteurs: $e");
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
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildAccueil(),
          const PrestataireCommandesScreen(),
          const PrestataireAgentsScreen(), 
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
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(
              Icons.people, color: AppColors.green),
            label: 'Agents',
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

  // 
  Widget _buildDrawer() {
  return Drawer(
    backgroundColor: Colors.white,
    child: Column(
      children: [

        // ── Header vert ───────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            20, 50, 20, 24),
          color: AppColors.green,
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.white
                    .withValues(alpha: 0.2),
                  borderRadius:
                    BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(_initiales,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                    CrossAxisAlignment.start,
                  children: [
                    Text(_nomCommercial,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(_email,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                        const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white
                          .withValues(alpha: 0.2),
                        borderRadius:
                          BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Pressing · Actif",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Items du menu ─────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
            children: [

              // Mon profil
              _drawerItem(
                icon: Icons.person_outline,
                label: "Mon profil",
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 3);
                }),

              // Mes commandes
              _drawerItem(
                icon: Icons.list_alt_outlined,
                label: "Mes commandes",
                badge: _countCommandes > 0
                  ? '$_countCommandes' : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 1);
                }),

              // Configurer mon service
              _drawerItem(
                icon: Icons.settings_outlined,
                label: "Configurer mon service",
                onTap: () async {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const PrestataireConfigScreen()),
                  );
                    // ← Recharger config au retour !
                       _loadData();
                  
                }),

              // Statistiques
              _drawerItem(
                icon: Icons.bar_chart_outlined,
                label: "Statistiques",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const PrestataireStatistiquesScreen()));
                }),

              // Paramètres
              _drawerItem(
                icon: Icons.tune_outlined,
                label: "Mes paramètres",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const ParametresScreen()));
                }),

              // Aide & Support
              _drawerItem(
                icon: Icons.headset_mic_outlined,
                label: "Aide & Support",
                onTap: () => Navigator.pop(context)),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ← Déconnexion en rouge
              _drawerItem(
                icon: Icons.logout,
                label: "Se déconnecter",
                isLogout: true,
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                }),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Item drawer style épuré ───────────────────────
Widget _drawerItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool isLogout = false,
  String? badge,
}) {
  final Color iconColor = isLogout
    ? Colors.red : AppColors.green;
  final Color iconBg = isLogout
    ? const Color(0xFFFCEBEB)
    : AppColors.greenLight;
  final Color textColor = isLogout
    ? Colors.red : AppColors.textPrimary;

  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 2),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
          color: iconColor, size: 20),
      ),
      title: Text(label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: badge != null
        // Badge commandes
        ? Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius:
                BorderRadius.circular(20)),
            child: Text(badge,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        // Flèche →
        : Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isLogout
              ? Colors.red
              : AppColors.textMuted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    ),
  );
}



  // ── Helper : unité selon le service ───────────────
        String _getUnite(String nom) {
          final n = nom.toLowerCase();
          if (n.contains('kilo') || n.contains('kg')) {
            return '/ kg';
          }
          return '/ pièce';
        }      

  // ══ PAGE ACCUEIL ══════════════════════════════════
 Widget _buildAccueil() {
  return Column(
    children: [

      // ── Header vert ──────────────────────────────
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
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () =>
                          Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white
                              .withValues(alpha: 0.15),
                            borderRadius:
                              BorderRadius.circular(10)),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 20),
                        ),
                      ),
                    ),
                    Stack(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white
                              .withValues(alpha: 0.15),
                            borderRadius:
                              BorderRadius.circular(10)),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.green,
                                width: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Infos prestataire
                Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white
                          .withValues(alpha: 0.2),
                        borderRadius:
                          BorderRadius.circular(14)),
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
                        Text(_nomCommercial,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: 13),
                            const SizedBox(width: 4),
                            Text(
                              _zone.isNotEmpty
                                ? _zone
                                : 'Zone non configurée',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets
                            .only(top: 4),
                          padding:
                            const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white
                              .withValues(alpha: 0.2),
                            borderRadius:
                              BorderRadius.circular(20)),
                          child: Text(
                            "Pressing · Actif",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
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

      // ── Body ─────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
              CrossAxisAlignment.start,
            children: [

              // ── Compteurs ──────────────────────
              Row(
                children: [
                  Expanded(child: _buildStatCard(
                    '$_countCommandes',
                    'Commandes',
                    AppColors.green,
                    AppColors.greenLight,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard(
                    '$_countEnCours',
                    'En cours',
                    AppColors.amber,
                    AppColors.amberLight,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard(
                    '$_countAgents',
                    'Agents',
                    AppColors.primary,
                    AppColors.primaryLight,
                  )),
                ],
              ),

              const SizedBox(height: 16),

              // ── Bannière si pas configuré ───────
              if (!_configExiste)
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                          const PrestataireConfigScreen()));
                    _loadData();
                  },
                  child: Container(
                    margin: const EdgeInsets
                      .only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius:
                        BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.amber
                          .withValues(alpha: 0.3))),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: AppColors.amber,
                          size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Configurez votre service",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amber,
                                ),
                              ),
                              Text(
                                "Ajoutez vos tarifs pour "
                                "être visible par les clients",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.amber,
                          size: 14),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ── Actions ────────────────────────
              Text("Mes actions",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // ← AJUSTER : plus petit = plus haut
                childAspectRatio: 0.85,
                children: [

                  // ── Mon service ───────────────
                  // 
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                            const PrestataireConfigScreen()));
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _configExiste
                            ? AppColors.green
                            : AppColors.border,
                          width: _configExiste ? 1.5 : 0.5)),
                      child: Column(
                        crossAxisAlignment:
                          CrossAxisAlignment.start,
                        children: [

                          // Header
                          Row(
                            mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.greenLight,
                                  borderRadius:
                                    BorderRadius.circular(8)),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.green,
                                  size: 16),
                              ),
                              Container(
                                padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _configExiste
                                    ? AppColors.greenLight
                                    : AppColors.amberLight,
                                  borderRadius:
                                    BorderRadius.circular(20)),
                                child: Text(
                                  _configExiste
                                    ? "✅ OK"
                                    : "⚠️",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: _configExiste
                                      ? AppColors.green
                                      : AppColors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text("Mon service",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 6),
                          const Divider(height: 1),
                          const SizedBox(height: 6),

                          // ← Prestations en chips
                          if (_configExiste &&
                              _prestationsConfig.isNotEmpty)
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: _prestationsConfig
                                      .take(7)
                                      .map((presta) =>
                                        Container(
                                          padding:
                                            const EdgeInsets
                                              .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors
                                              .greenLight,
                                            borderRadius:
                                              BorderRadius
                                                .circular(20),
                                          ),
                                          child: Text(
                                            "${presta['nom']}"
                                            " · ${(presta['prix']
                                              as num).toInt()}F",
                                            style:
                                              GoogleFonts.poppins(
                                                fontSize: 9,
                                                color:
                                                  AppColors.green,
                                                fontWeight:
                                                  FontWeight.w500,
                                              ),
                                          ),
                                        ),
                                      ).toList(),
                                  ),

                                  if (_prestationsConfig.length > 7)
                                    Padding(
                                      padding: const EdgeInsets
                                        .only(top: 3),
                                      child: Text(
                                        "+${_prestationsConfig.length - 7} autres",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: AppColors.textSecond,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),

                                  const Spacer(),

                                  // ← Options en bas
                                  Wrap(
                                    spacing: 3,
                                    runSpacing: 3,
                                    children: [
                                      if (_options['express'] == true)
                                        _chip("⚡", AppColors.amber),
                                      if (_options['collecte'] == true)
                                        _chip("🏠", AppColors.primary),
                                      if (_options['livraison'] == true)
                                        _chip("🚚", AppColors.primary),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: Text(
                                "Appuyez pour configurer",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.textSecond,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),


                // GridView.count(
                // crossAxisCount: 2,
                // shrinkWrap: true,
                // physics:
                //   const NeverScrollableScrollPhysics(),
                // crossAxisSpacing: 10,
                // mainAxisSpacing: 10,
                // childAspectRatio: 1.3,
                // children: [

                  // ── Ma zone ───────────────────
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                            const PrestataireConfigScreen()));
                      _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                          BorderRadius.circular(14),
                        border: Border.all(
                          color: _zoneConfig.isNotEmpty
                            ? AppColors.amber
                            : AppColors.border,
                          width: _zoneConfig.isNotEmpty
                            ? 1.5 : 0.5)),
                      child: Column(
                        crossAxisAlignment:
                          CrossAxisAlignment.start,
                        children: [

                          // Header
                          Row(
                            mainAxisAlignment:
                              MainAxisAlignment
                                .spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color:
                                        AppColors.amberLight,
                                      borderRadius:
                                        BorderRadius
                                          .circular(10)),
                                    child: const Icon(
                                      Icons
                                        .location_on_outlined,
                                      color: AppColors.amber,
                                      size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text("Ma zone",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight:
                                        FontWeight.w600,
                                      color:
                                        AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              // ← Badge zone
                              Container(
                                padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: _zoneConfig.isNotEmpty
                                    ? AppColors.amberLight
                                    : AppColors.background,
                                  borderRadius:
                                    BorderRadius.circular(20)),
                                child: Text(
                                  _zoneConfig.isNotEmpty
                                    ? "✅ OK"
                                    : "⚠️ Vide",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: _zoneConfig.isNotEmpty
                                      ? AppColors.amber
                                      : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ← Contenu zone
                          if (_zoneConfig.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.amber,
                                  size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _zoneConfig,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              "Définissez votre zone",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.textSecond,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Commandes ─────────────────
                  _buildActionCard(
                    Icons.list_alt_outlined,
                    "Commandes",
                    "Gérer les demandes",
                    AppColors.primary,
                    AppColors.primaryLight,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                          const PrestataireCommandesScreen())),
                  ),

                  // ── Mes avis ──────────────────
                  _buildActionCard(
                    Icons.star_outline,
                    "Mes avis",
                    "Évaluations clients",
                    AppColors.purple,
                    AppColors.purpleLight,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Dernières commandes ────────────
              Text("Dernières commandes",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              _dernieresCommandes.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                        BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        width: 0.5)),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            color: AppColors.textMuted,
                            size: 36),
                          const SizedBox(height: 8),
                          Text(
                            "Aucune commande pour l'instant",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecond,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: _dernieresCommandes
                      .map((cmd) =>
                        _buildCommandeRecente(cmd))
                      .toList(),
                  ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ],
  );
}

  // ── Stat card ──────────────────────────────────────
  Widget _buildStatCard(
    String count,
    String label,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(count,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
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

Widget _chip(String emoji, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: color.withValues(alpha: 0.3)),
    ),
    child: Text(emoji,
      style: const TextStyle(fontSize: 10)),
  );
}

  // ══ PAGE STATISTIQUES ════════════════════════════
  // Widget _buildStatistiques() {
  //   return const PrestataireCommandesScreen();
  // }

  // ══ PAGE AGENTS ══════════════════════════════════
  Widget _buildAgents() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        automaticallyImplyLeading: false,
        title: Text("Mes agents",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_add_outlined,
              color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 60,
              color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text("Aucun agent",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text("Ajoutez vos livreurs et collecteurs",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecond,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: Text("Ajouter un agent",
                style: GoogleFonts.poppins(
                  fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ══ PAGE PROFIL ══════════════════════════════════
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

            // Avatar
            const SizedBox(height: 20),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
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
            Text(_nomCommercial,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(_zone,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecond,
              ),
            ),

            const SizedBox(height: 24),

            // Infos
            _buildProfilItem(
              Icons.person_outline, "Nom complet",
              '$_prenom $_nom'),
            _buildProfilItem(
              Icons.email_outlined, "Email", _email),
            _buildProfilItem(
              Icons.location_on_outlined,
              "Zone", _zone),
            _buildProfilItem(
              Icons.work_outline,
              "Type de service", "Pressing"),

            const SizedBox(height: 24),

            // Bouton déconnexion
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                    color: Colors.red),
                  padding: const EdgeInsets.symmetric(
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
      IconData icon, String label, String value) {
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
            color: AppColors.green, size: 20),
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
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionBadge(String label, bool active) {
  return Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: active
        ? AppColors.greenLight
        : AppColors.background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: active
          ? AppColors.green
          : AppColors.textMuted,
      ),
    ),
  );
}
void _showLogoutDialog() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)),
      title: Text("Déconnexion",
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        "Voulez-vous vraiment vous déconnecter ?",
        style: GoogleFonts.poppins(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Annuler",
            style: GoogleFonts.poppins(
              color: AppColors.textSecond)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            _logout();
          },
          icon: const Icon(
            Icons.logout, size: 16),
          label: Text("Déconnexion",
            style: GoogleFonts.poppins(
              fontSize: 13)),
        ),
      ],
    ),
  );
}


Widget _buildCommandeRecente(
    Map<String, dynamic> cmd) {
  final statut = cmd['statut'] ?? '';
  final config = _getStatutConfig(statut);

  return GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommandeDetailScreen(
          commandeId: cmd['id']))),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 0.5)),
      child: Row(
        children: [

          // ← Icône statut
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: config['bgColor'] as Color,
              borderRadius:
                BorderRadius.circular(10)),
            child: Icon(
              config['icon'] as IconData,
              color: config['color'] as Color,
              size: 20),
          ),
          const SizedBox(width: 10),

          // ← Infos commande
          Expanded(
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [
                Text(
                  cmd['nomClient'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  "${cmd['motDepot'] == 'COLLECTE_DOMICILE' ? 'Collecte' : 'Dépôt'}"
                  " · ${cmd['dateCommande'] ?? ''}",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecond,
                  ),
                ),
              ],
            ),
          ),

          // ← Montant + badge statut
          Column(
            crossAxisAlignment:
              CrossAxisAlignment.end,
            children: [
              Text(
                "${(cmd['montantTotal'] ?? 0).toInt()} FCFA",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: config['bgColor'] as Color,
                  borderRadius:
                    BorderRadius.circular(20)),
                child: Text(
                  config['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: config['color'] as Color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 18),
        ],
      ),
    ),
  );
}

// ← Config statut avec icône
Map<String, dynamic> _getStatutConfig(
    String statut) {
  switch (statut) {
    case 'CREE':
      return {
        'label': 'Nouvelle',
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
        'icon': Icons.fiber_new_outlined,
      };
    case 'CONFIRMEE':
      return {
        'label': 'Confirmée',
        'color': AppColors.green,
        'bgColor': AppColors.greenLight,
        'icon': Icons.check_circle_outline,
      };
    case 'EN_VERIFICATION':
      return {
        'label': 'Vérification',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'icon': Icons.verified_outlined,
      };
    case 'EN_TRAITEMENT':
      return {
        'label': 'En cours',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'icon': Icons.local_laundry_service_outlined,
      };
    case 'TRAITEMENT_TERMINE':
      return {
        'label': 'Terminé',
        'color': AppColors.purple,
        'bgColor': AppColors.purpleLight,
        'icon': Icons.done_all_outlined,
      };
    case 'PAIEMENT_RECU':
      return {
        'label': 'Payée',
        'color': AppColors.green,
        'bgColor': AppColors.greenLight,
        'icon': Icons.payments_outlined,
      };
    case 'EN_LIVRAISON':
      return {
        'label': 'Livraison',
        'color': AppColors.primary,
        'bgColor': AppColors.primaryLight,
        'icon': Icons.local_shipping_outlined,
      };
    case 'VERIFICATION_FINALE':
      return {
        'label': 'Vérif. finale',
        'color': AppColors.amber,
        'bgColor': AppColors.amberLight,
        'icon': Icons.fact_check_outlined,
      };
    case 'TERMINEE':
      return {
        'label': 'Terminée',
        'color': AppColors.green,
        'bgColor': AppColors.greenLight,
        'icon': Icons.check_circle_outline,
      };
    case 'CLOTUREE':
      return {
        'label': 'Clôturée ✅',
        'color': AppColors.green,
        'bgColor': AppColors.greenLight,
        'icon': Icons.lock_outline,
      };
    case 'ANNULEE':
      return {
        'label': 'Annulée',
        'color': Colors.red,
        'bgColor': const Color(0xFFFCEBEB),
        'icon': Icons.cancel_outlined,
      };
    case 'LITIGE':
      return {
        'label': 'Litige',
        'color': Colors.orange,
        'bgColor': const Color(0xFFFFF3E0),
        'icon': Icons.warning_amber_outlined,
      };
    default:
      return {
        'label': statut,
        'color': Colors.grey,
        'bgColor': AppColors.background,
        'icon': Icons.help_outline,
      };
  }
}

      // ← AJOUT dans PrestataireHomeScreen
      IconData _getIconPrestation(String nom) {
        final n = nom.toLowerCase();
        if (n.contains('kilo') ||
            n.contains('lavage')) {
          return Icons.local_laundry_service_outlined;
        } else if (n.contains('boubou') ||
                  n.contains('bazin')) {
          return Icons.checkroom_outlined;
        } else if (n.contains('sec')) {
          return Icons.dry_cleaning_outlined;
        } else if (n.contains('repassage')) {
          return Icons.iron_outlined;
        } else if (n.contains('coiffure')) {
          return Icons.content_cut_outlined;
        } else if (n.contains('nettoyage') ||
                  n.contains('menage') ||
                  n.contains('ménage')) {
          return Icons.cleaning_services_outlined;
        } else if (n.contains('diagnostic') ||
                  n.contains('reparation') ||
                  n.contains('réparation')) {
          return Icons.build_outlined;
        } else {
          return Icons.star_outline;
        }
      }
}