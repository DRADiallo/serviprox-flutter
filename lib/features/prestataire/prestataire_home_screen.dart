// ═══════════════════════════════════════════════════════
// PrestataireHomeScreen.dart
//
// RÔLE : Tableau de bord principal du prestataire
//        (Accueil, Commandes, Agents, Profil)
//
// Navigation depuis :
//   - SplashScreen  → const PrestataireHomeScreen()
//   - OtpScreen     → const PrestataireHomeScreen()
//
// Données chargées depuis AuthStorage + API backend
// SÉCURITÉ : JWT Bearer token sur TOUS les appels HTTP
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import 'prestataire_commandes_screen.dart';
import 'prestataire_agents_screen.dart';
import 'prestataire_statistiques_screen.dart';
import 'parametres_screen.dart';
import 'ConfigurerServiceScreen.dart';

class PrestataireHomeScreen extends StatefulWidget {
  const PrestataireHomeScreen({super.key});

  @override
  State<PrestataireHomeScreen> createState() =>
      _PrestataireHomeScreenState();
}

class _PrestataireHomeScreenState
    extends State<PrestataireHomeScreen> {

  // ── Onglet actif ──────────────────────────────────
  int _selectedIndex = 0;

  // ── Données utilisateur ───────────────────────────
  String _prenom      = '';
  String _nom         = '';
  String _email       = '';
  String _adresse     = 'Dakar, Sénégal';
  String _typeService = '';
  int    _userId      = 0;

  // ── Config prestataire ────────────────────────────
  bool   _avecAgent   = false;
  bool   _disponible  = true;

  // ── Statistiques commandes ────────────────────────
  int    _totalCommandes    = 0;
  int    _enCours           = 0;
  int    _terminees         = 0;
  int    _nouvelles         = 0;

  // ── Chargement ────────────────────────────────────
  bool   _isLoading   = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─────────────────────────────────────────────────
  // CHARGEMENT PRINCIPAL
  // ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Lire les infos locales (sans réseau)
    final prenom      = await AuthStorage.getPrenom();
    final nom         = await AuthStorage.getNom();
    final email       = await AuthStorage.getEmail();
    final adresse     = await AuthStorage.getAdresse();
    final typeService = await AuthStorage.getTypeService();
    final userId      = await AuthStorage.getUserId();

    if (!mounted) return;
    setState(() {
      _prenom      = prenom;
      _nom         = nom;
      _email       = email;
      _adresse     = adresse.isEmpty ? 'Dakar, Sénégal' : adresse;
      _typeService = typeService;
      _userId      = userId ?? 0;
    });

    // 2. Charger depuis le backend (en parallèle)
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    await Future.wait([
      _loadConfig(token),
      _loadCommandes(token),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  // ─────────────────────────────────────────────────
  // CONFIG PRESTATAIRE  —  GET /api/prestataire/config/{id}
  // ─────────────────────────────────────────────────
  Future<void> _loadConfig(String token) async {
    if (_userId == 0) return;
    try {
      final uri = Uri.parse(
        '${ApiConstants.prestataireConfig}/$_userId',
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final typeFromConfig = data['typeService'] as String? ?? '';
        if (mounted) {
          setState(() {
            _avecAgent  = data['avecAgent']  as bool? ?? false;
            _disponible = data['disponible'] as bool? ?? true;
            if (typeFromConfig.isNotEmpty && _typeService.isEmpty) {
              _typeService = typeFromConfig;
            }
          });
          // Mettre à jour le type service local si nécessaire
          if (typeFromConfig.isNotEmpty) {
            await AuthStorage.saveTypeService(typeFromConfig);
          }
        }
      }
    } catch (_) {
      // Config pas encore créée → normal pour un nouveau prestataire
    }
  }

  // ─────────────────────────────────────────────────
  // COMMANDES  —  GET /api/commande/prestataire/{id}
  // ─────────────────────────────────────────────────
  Future<void> _loadCommandes(String token) async {
    if (_userId == 0) return;
    try {
      final uri = Uri.parse(
        '${ApiConstants.commandes}/prestataire/$_userId',
      );
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> commandes = json.decode(response.body);
        final total     = commandes.length;
        final nouvelles = commandes.where((c) =>
            c['statut'] == 'CREE').length;
        final enCours   = commandes.where((c) =>
            ['CONFIRMEE','EN_VERIFICATION','EN_TRAITEMENT',
             'TRAITEMENT_TERMINE','EN_LIVRAISON']
                .contains(c['statut'])).length;
        final terminees = commandes.where((c) =>
            ['TERMINEE','CLOTUREE','PAIEMENT_RECU']
                .contains(c['statut'])).length;

        if (mounted) {
          setState(() {
            _totalCommandes = total;
            _nouvelles      = nouvelles;
            _enCours        = enCours;
            _terminees      = terminees;
          });
        }
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────
  // TOGGLE DISPONIBILITÉ
  // PUT /api/prestataire/config/{id}/disponibilite
  // ─────────────────────────────────────────────────
  Future<void> _toggleDisponibilite(bool value) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    try {
      final uri = Uri.parse(
        '${ApiConstants.prestataireConfig}/$_userId/disponibilite?disponible=$value',
      );
      final response = await http.put(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && mounted) {
        setState(() => _disponible = value);
        _showSnack(value
            ? '✅ Disponible pour de nouvelles commandes'
            : '⏸️ Vous êtes marqué indisponible');
      }
    } catch (_) {
      _showSnack('❌ Connexion impossible');
    }
  }

  // ─────────────────────────────────────────────────
  // DÉCONNEXION
  // ─────────────────────────────────────────────────
  Future<void> _logout() async {
    await AuthStorage.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.green,
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // INITIALES (pour l'avatar)
  // ─────────────────────────────────────────────────
  String get _initiales {
    final p = _prenom.isNotEmpty ? _prenom[0].toUpperCase() : '';
    final n = _nom.isNotEmpty    ? _nom[0].toUpperCase()    : '';
    return '$p$n'.isEmpty ? '?' : '$p$n';
  }

  // ─────────────────────────────────────────────────
  // LABEL TYPE SERVICE
  // ─────────────────────────────────────────────────
  String get _labelTypeService {
    switch (_typeService.toLowerCase()) {
      case 'pressing':    return ' Pressing';
      case 'nettoyage':   return '🧹 Nettoyage';
      case 'laverie':     return '👕 Laverie';
      case 'plomberie':   return '🔧 Plomberie';
      case 'electricite': return '⚡ Électricité';
      case 'maconnerie':  return '🏗️ Maçonnerie';
      case 'peinture':    return '🎨 Peinture';
      default:
        return _typeService.isEmpty ? '⚙️ Service' : _typeService;
    }
  }

  // ─────────────────────────────────────────────────
  // ÉCRANS DE NAVIGATION
  // ─────────────────────────────────────────────────
  // List<Widget> get _screens => [
  //   _buildAccueil(),
  //   const PrestataireCommandesScreen(),
  //   if (_avecAgent) const PrestataireAgentsScreen(),
  //   const PrestataireStatistiquesScreen(),
  // ];

  // ─────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.green,
              ),
            )
          : RefreshIndicator(
              color: AppColors.green,
              onRefresh: _loadData,
              child: IndexedStack(
                  index: _avecAgent
                      ? _selectedIndex
                      : const [0, 1, 3][_selectedIndex.clamp(0, 2)],
                  children: [
                      _buildAccueil(),
                      const PrestataireCommandesScreen(),
                      const PrestataireAgentsScreen(),   // ← TOUJOURS là, jamais retiré
                      const PrestataireStatistiquesScreen(),
                  ],
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.green, Color(0xFF3A7A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenue, $_prenom $_nom',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFFFF6B6B), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    _adresse,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Badge disponibilité
            GestureDetector(
              onTap: () => _toggleDisponibilite(!_disponible),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _disponible
                      ? Colors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _disponible
                            ? const Color(0xFF7ED56F)
                            : Colors.red[200],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _disponible ? 'Disponible' : 'Indisponible',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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

  // ─────────────────────────────────────────────────
  // DRAWER
  // ─────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header gradient vert
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green, Color(0xFF3A7A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar initiales
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    _initiales,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_prenom $_nom',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _email,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                // Badge type service
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(
                    _labelTypeService,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  icon: Icons.home_rounded,
                  label: 'Tableau de bord',
                  selected: _selectedIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                _drawerItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Mes commandes',
                  badge: _nouvelles > 0 ? '$_nouvelles' : null,
                  selected: _selectedIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                if (_avecAgent)
                  _drawerItem(
                    icon: Icons.people_rounded,
                    label: 'Mes agents',
                    selected: _selectedIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 2);
                    },
                  ),
                _drawerItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Statistiques',
                  selected: _selectedIndex == (_avecAgent ? 3 : 2),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() =>
                        _selectedIndex = _avecAgent ? 3 : 2);
                  },
                ),

                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 4),

                _drawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Configurer mon service',
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ConfigurerServiceScreenV2()),
                    );
                    // Recharger après retour config
                    _loadData();
                  },
                ),
                _drawerItem(
                  icon: Icons.person_rounded,
                  label: 'Mon profil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ParametresScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Déconnexion
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: AppColors.redLight,
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.red),
              title: Text(
                'Déconnexion',
                style: GoogleFonts.poppins(
                  color: AppColors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    bool selected = false,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.greenLight,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(
        icon,
        color: selected ? AppColors.green : AppColors.textSecond,
        size: 22,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: selected
                    ? AppColors.green
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  // ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: 'Accueil',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: _nouvelles > 0,
          label: Text('$_nouvelles'),
          child: const Icon(Icons.shopping_bag_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: _nouvelles > 0,
          label: Text('$_nouvelles'),
          child: const Icon(Icons.shopping_bag_rounded),
        ),
        label: 'Commandes',
      ),
      if (_avecAgent)
        const NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Agents',
        ),
      const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart_rounded),
        label: 'Statistiques',
      ),
    ];

    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) =>
          setState(() => _selectedIndex = i),
      backgroundColor: Colors.white,
      indicatorColor: AppColors.greenLight,
      destinations: destinations,
    );
  }

  // ─────────────────────────────────────────────────
  // ÉCRAN ACCUEIL
  // ─────────────────────────────────────────────────
  Widget _buildAccueil() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cartes stats
        _buildStatsRow(),
        const SizedBox(height: 20),

        // Actions rapides
        Text(
          'Actions rapides',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionsRapides(),
        const SizedBox(height: 20),

        // Alerte si pas de config
        if (_typeService.isEmpty) _buildAlertConfig(),

        // Nouvelles commandes
        if (_nouvelles > 0) ...[
          Text(
            'Nouvelles commandes ($_nouvelles)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildNouvelles(),
        ],
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: _statCard('Total', '$_totalCommandes',
                Icons.receipt_long_rounded, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('Nouvelles', '$_nouvelles',
                Icons.fiber_new_rounded, const Color(0xFFFF6B6B))),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('En cours', '$_enCours',
                Icons.autorenew_rounded, AppColors.amber)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('Terminées', '$_terminees',
                Icons.check_circle_rounded, AppColors.green)),
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRapides() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.settings_rounded,
            label: 'Configurer',
            color: AppColors.green,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ConfigurerServiceScreenV2()),
              );
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Commandes',
            color: AppColors.primary,
            onTap: () => setState(() => _selectedIndex = 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionCard(
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            color: AppColors.amber,
            onTap: () => setState(
                () => _selectedIndex = _avecAgent ? 3 : 2),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertConfig() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service non configuré',
                  style: GoogleFonts.poppins(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Configurez votre service pour recevoir des commandes',
                  style: GoogleFonts.poppins(
                    color: AppColors.amber,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ConfigurerServiceScreenV2()),
              );
              _loadData();
            },
            child: Text(
              'Configurer',
              style: GoogleFonts.poppins(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNouvelles() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fiber_new_rounded,
                color: Color(0xFFFF6B6B), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_nouvelles nouvelle${_nouvelles > 1 ? 's' : ''} commande${_nouvelles > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'En attente de confirmation',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedIndex = 1),
            child: Text(
              'Voir',
              style: GoogleFonts.poppins(
                color: AppColors.green,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


///#################################///////////

// // lib/features/prestataire/prestataire_home_screen.dart
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:memoireserviprox/features/prestataire/Commande_detail_screen.dart';

// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';
// import '../auth/login_screen.dart';
// import 'prestataire_commandes_screen.dart';
// import 'prestataire_agents_screen.dart';
// import 'prestataire_statistiques_screen.dart';
// // ✅ CORRECTION — ParametresServiceScreen (métamodèle config) remplace PrestataireConfigScreen
// import 'parametres_service_screen.dart';
// import 'parametres_screen.dart' hide ParametresServiceScreen;
// //import '../prestataire/Commande_detail_screen.dart'

// class PrestataireHomeScreen extends StatefulWidget {
//   // ✅ prestataireId required (splash + otp le passent)
//   final int prestataireId;
//   const PrestataireHomeScreen({
//     super.key,
//     required this.prestataireId,
//   });

//   @override
//   State<PrestataireHomeScreen> createState() =>
//       _PrestataireHomeScreenState();
// }

// class _PrestataireHomeScreenState
//     extends State<PrestataireHomeScreen> {

//   // ── Variables d'état ──────────────────────────────
//   int _currentIndex = 0;
//   String _nomCommercial = '';
//   String _prenom = '';
//   String _nom = '';
//   String _email = '';
//   String _zone = '';
//   int _countCommandes = 0;
//   int _countEnCours = 0;
//   int _countAgents = 0;
//   bool _isLoading = true;
//   String _typeService = '';
//   bool _avecAgent = true;

//   // Variables config récapitulatif
//   bool _configExiste = false;
//   Map<String, dynamic> _options = {};
//   List<Map<String, dynamic>> _prestationsConfig = [];
//   List<dynamic> _dernieresCommandes = [];
//   String _zoneConfig = '';

//   // pour CommandeDetailScreen (nouveau constructeur)
//   List<String> _etapesEffectives = [];
//   List<Map<String, dynamic>> _agents = [];

//   // ── Initiales ─────────────────────────────────────
//   String get _initiales {
//     return _nomCommercial
//         .trim()
//         .split(' ')
//         .where((w) => w.isNotEmpty)
//         .take(2)
//         .map((w) => w[0].toUpperCase())
//         .join();
//   }

//   // ✅ CORRECTION OpenEHR — libellé générique depuis l'API
//   // Plus de switch(_typeService) hardcodé
//   String get _labelService {
//     if (_typeService.isEmpty) return 'En activité';
//     final label = _typeService[0].toUpperCase() +
//         _typeService.substring(1).toLowerCase();
//     return '$label · Actif';
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   // ── Charger données ───────────────────────────────
//   Future<void> _loadData() async {
//     final prenom = await AuthStorage.getPrenom();
//     final nom    = await AuthStorage.getNom();
//     final email  = await AuthStorage.getEmail();
//     final token  = await AuthStorage.getToken();

//     await Future.wait([
//       _loadConfig(widget.prestataireId, token),
//       _loadCompteurs(widget.prestataireId, token),
//     ]);

//     if (mounted) {
//       setState(() {
//         _prenom        = prenom;
//         _nom           = nom;
//         _email         = email;
//         _nomCommercial = prenom.isNotEmpty ? '$prenom $nom' : nom;
//         _isLoading     = false;
//       });
//     }
//   }

//   // ── Charger config prestataire ────────────────────
//   Future<void> _loadConfig(int? userId, String? token) async {
//     try {
//       final configResp = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/prestataire/config/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (configResp.statusCode == 200) {
//         final data = jsonDecode(configResp.body);

//         // Parser les options
//         Map<String, dynamic> options = {};
//         if (data['optionsActives'] != null) {
//           options = jsonDecode(data['optionsActives']);
//         }

//         // Parser les prestations
//         List<Map<String, dynamic>> prestations = [];
//         if (data['prestationsAjoutees'] != null) {
//           final raw = jsonDecode(data['prestationsAjoutees']) as List;
//           for (final item in raw) {
//             if (item is Map) {
//               prestations.add({
//                 'nom':   item['nom']?.toString() ?? '',
//                 'prix':  item['prix'] ?? 0,
//                 'unite': item['unite']?.toString() ?? 'pièce',
//               });
//             } else {
//               final parts = item.toString().split(':');
//               prestations.add({
//                 'nom':   parts[0].trim(),
//                 'prix':  double.tryParse(
//                   parts.length > 1 ? parts[1].trim() : '0') ?? 0,
//                 'unite': 'pièce',
//               });
//             }
//           }
//         }
//         if (prestations.isEmpty && data['tarifsPersonnalises'] != null) {
//           final tarifs = jsonDecode(data['tarifsPersonnalises'])
//               as Map<String, dynamic>;
//           for (final entry in tarifs.entries) {
//             prestations.add({
//               'nom':   entry.key,
//               'prix':  entry.value ?? 0,
//               'unite': 'pièce',
//             });
//           }
//         }

//         // Charger etapesEffectives pour CommandeDetailScreen
//         List<String> etapes = [];
//         if (data['etapesEffectives'] != null) {
//           etapes = (data['etapesEffectives'] as List)
//               .map((e) => e.toString())
//               .toList();
//         }

//         if (mounted) {
//           setState(() {
//             _configExiste       = true;
//             _options            = options;
//             _prestationsConfig  = prestations;
//             _zoneConfig         = data['zoneCouverture'] ?? '';
//             _zone               = _zoneConfig;
//             _typeService        = data['typeService'] ?? '';
//             _avecAgent          = data['avecAgent'] as bool?
//                 ?? (data['service'] as Map<String, dynamic>?)?['avecAgent']
//                     as bool? ?? true;
//             _etapesEffectives   = etapes;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Erreur config: $e");
//     }
//   }

//   // ── Charger compteurs + agents ────────────────────
//   Future<void> _loadCompteurs(int? userId, String? token) async {
//     try {
//       // 1. Commandes
//       final cmdResp = await http.get(
//         Uri.parse('${ApiConstants.commandes}/prestataire/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (cmdResp.statusCode == 200) {
//         final List<dynamic> commandes = jsonDecode(cmdResp.body);
//         final enCours = commandes.where((c) =>
//           c['statut'] == 'CREE' ||
//           c['statut'] == 'CONFIRMEE' ||
//           c['statut'] == 'EN_TRAITEMENT'
//         ).length;

//         if (mounted) {
//           setState(() {
//             _countCommandes     = commandes.length;
//             _countEnCours       = enCours;
//             _dernieresCommandes = commandes.take(5).toList();
//           });
//         }
//       }

//       // 2. Agents
//       final agentResp = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/agents/prestataire/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (agentResp.statusCode == 200) {
//         final List<dynamic> agents = jsonDecode(agentResp.body);
//         if (mounted) {
//           setState(() {
//             _agents      = agents.cast<Map<String, dynamic>>();
//             _countAgents = agents
//                 .where((a) => a['statut'] == 'ACTIF')
//                 .length;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Erreur compteurs: $e");
//     }
//   }

//   // ── Déconnexion ───────────────────────────────────
//   Future<void> _logout() async {
//     await AuthStorage.logout();
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//         (route) => false,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       drawer: _buildDrawer(),
//       body: IndexedStack(
//         index: _currentIndex,
//         children: [
//           _buildAccueil(),
//           const PrestataireCommandesScreen(),
//           if (_avecAgent) const PrestataireAgentsScreen(),
//           _buildProfil(),
//         ],
//       ),
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _currentIndex,
//         onDestinationSelected: (i) =>
//             setState(() => _currentIndex = i),
//         backgroundColor: Colors.white,
//         indicatorColor: AppColors.greenLight,
//         destinations: [
//           const NavigationDestination(
//             icon: Icon(Icons.home_outlined),
//             selectedIcon: Icon(
//                 Icons.home, color: AppColors.green),
//             label: 'Accueil',
//           ),
//           const NavigationDestination(
//             icon: Icon(Icons.list_alt_outlined),
//             selectedIcon: Icon(
//                 Icons.list_alt, color: AppColors.green),
//             label: 'Commandes',
//           ),
//           if (_avecAgent)
//             const NavigationDestination(
//               icon: Icon(Icons.people_outline),
//               selectedIcon: Icon(
//                   Icons.people, color: AppColors.green),
//               label: 'Agents',
//             ),
//           const NavigationDestination(
//             icon: Icon(Icons.person_outline),
//             selectedIcon: Icon(
//                 Icons.person, color: AppColors.green),
//             label: 'Profil',
//           ),
//         ],
//       ),
//     );
//   }

//   // ══ DRAWER (menu burger) ══════════════════════════
//   Widget _buildDrawer() {
//     return Drawer(
//       backgroundColor: Colors.white,
//       child: Column(
//         children: [

//           // ── Header vert ───────────────────────────
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
//             color: AppColors.green,
//             child: Row(
//               children: [
//                 Container(
//                   width: 56, height: 56,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Center(
//                     child: Text(_initiales,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                     children: [
//                       Text(_nomCommercial,
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       Text(_email,
//                         style: GoogleFonts.poppins(
//                           color: Colors.white70,
//                           fontSize: 11,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.white
//                               .withValues(alpha: 0.2),
//                           borderRadius:
//                               BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           _labelService,
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Items du menu ─────────────────────────
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 16, vertical: 12),
//               children: [

//                 _drawerItem(
//                   icon: Icons.person_outline,
//                   label: "Mon profil",
//                   onTap: () {
//                     Navigator.pop(context);
//                     setState(() => _currentIndex =
//                         _avecAgent ? 3 : 2);
//                   }),

//                 _drawerItem(
//                   icon: Icons.list_alt_outlined,
//                   label: "Mes commandes",
//                   badge: _countCommandes > 0
//                       ? '$_countCommandes' : null,
//                   onTap: () {
//                     Navigator.pop(context);
//                     setState(() => _currentIndex = 1);
//                   }),

//                 // ✅ CORRECTION — ParametresServiceScreen (métamodèle)
//                 _drawerItem(
//                   icon: Icons.settings_outlined,
//                   label: "Configurer mon service",
//                   onTap: () async {
//                     Navigator.pop(context);
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => ParametresServiceScreen(
//                           prestataireId: widget.prestataireId,
//                         ),
//                       ),
//                     );
//                     _loadData();
//                   }),

//                 _drawerItem(
//                   icon: Icons.bar_chart_outlined,
//                   label: "Statistiques",
//                   onTap: () {
//                     Navigator.pop(context);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                             const PrestataireStatistiquesScreen()));
//                   }),

//                 // _drawerItem(
//                 //   icon: Icons.tune_outlined,
//                 //   label: "Mes paramètres",
//                 //   onTap: () {
//                 //     Navigator.pop(context);
//                 //     Navigator.push(
//                 //       context,
//                 //       MaterialPageRoute(
//                 //         builder: (_) =>
//                 //             const ParametresScreen()));
//                 //   }),

//                 _drawerItem(
//                   icon: Icons.headset_mic_outlined,
//                   label: "Aide & Support",
//                   onTap: () => Navigator.pop(context)),

//                 const SizedBox(height: 8),
//                 const Divider(height: 1),
//                 const SizedBox(height: 8),

//                 _drawerItem(
//                   icon: Icons.logout,
//                   label: "Se déconnecter",
//                   isLogout: true,
//                   onTap: () {
//                     Navigator.pop(context);
//                     _showLogoutDialog();
//                   }),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Item drawer épuré ─────────────────────────────
//   Widget _drawerItem({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     bool isLogout = false,
//     String? badge,
//   }) {
//     // ✅ CORRECTION — AppColors.red / AppColors.redLight (pas Colors.red / Color(0xFFFCEBEB))
//     final Color iconColor = isLogout
//         ? AppColors.red : AppColors.green;
//     final Color iconBg = isLogout
//         ? AppColors.redLight
//         : AppColors.greenLight;
//     final Color textColor = isLogout
//         ? AppColors.red : AppColors.textPrimary;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 4),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(
//             horizontal: 8, vertical: 2),
//         leading: Container(
//           width: 42, height: 42,
//           decoration: BoxDecoration(
//             color: iconBg,
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon,
//               color: iconColor, size: 20),
//         ),
//         title: Text(label,
//           style: GoogleFonts.poppins(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: textColor,
//           ),
//         ),
//         trailing: badge != null
//             ? Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: AppColors.green,
//                   borderRadius:
//                       BorderRadius.circular(20)),
//                 child: Text(badge,
//                   style: GoogleFonts.poppins(
//                     fontSize: 11,
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               )
//             : Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 14,
//                 color: isLogout
//                     ? AppColors.red
//                     : AppColors.textMuted),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12)),
//         onTap: onTap,
//       ),
//     );
//   }

//   // ══ PAGE ACCUEIL ══════════════════════════════════
//   Widget _buildAccueil() {
//     return Column(
//       children: [

//         // ── Header vert ──────────────────────────────
//         Container(
//           color: AppColors.green,
//           child: SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(
//                   16, 8, 16, 20),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment:
//                         MainAxisAlignment.spaceBetween,
//                     children: [
//                       Builder(
//                         builder: (ctx) => GestureDetector(
//                           onTap: () =>
//                               Scaffold.of(ctx).openDrawer(),
//                           child: Container(
//                             width: 34, height: 34,
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.15),
//                               borderRadius:
//                                   BorderRadius.circular(10)),
//                             child: const Icon(
//                               Icons.menu,
//                               color: Colors.white,
//                               size: 20),
//                           ),
//                         ),
//                       ),
//                       Stack(
//                         children: [
//                           Container(
//                             width: 34, height: 34,
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.15),
//                               borderRadius:
//                                   BorderRadius.circular(10)),
//                             child: const Icon(
//                               Icons.notifications_outlined,
//                               color: Colors.white,
//                               size: 20),
//                           ),
//                           Positioned(
//                             top: 6, right: 6,
//                             child: Container(
//                               width: 8, height: 8,
//                               decoration: BoxDecoration(
//                                 // ✅ AppColors.red
//                                 color: AppColors.red,
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: AppColors.green,
//                                   width: 1.5)),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 16),

//                   // Infos prestataire
//                   Row(
//                     children: [
//                       Container(
//                         width: 50, height: 50,
//                         decoration: BoxDecoration(
//                           color: Colors.white
//                               .withValues(alpha: 0.2),
//                           borderRadius:
//                               BorderRadius.circular(14)),
//                         child: Center(
//                           child: Text(_initiales,
//                             style: GoogleFonts.poppins(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Column(
//                         crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                         children: [
//                           Text(_nomCommercial,
//                             style: GoogleFonts.poppins(
//                               color: Colors.white,
//                               fontSize: 17,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.location_on_outlined,
//                                 color: Colors.white70,
//                                 size: 13),
//                               const SizedBox(width: 4),
//                               Text(
//                                 _zone.isNotEmpty
//                                     ? _zone
//                                     : 'Zone non configurée',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.white70,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             margin: const EdgeInsets
//                                 .only(top: 4),
//                             padding:
//                                 const EdgeInsets.symmetric(
//                                     horizontal: 10,
//                                     vertical: 2),
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.2),
//                               borderRadius:
//                                   BorderRadius.circular(20)),
//                             child: Text(
//                               _labelService,
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),

//         // ── Body ─────────────────────────────────────
//         Expanded(
//           child: _isLoading
//               ? const Center(child: CircularProgressIndicator(
//                   color: AppColors.green))
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(14),
//                   child: Column(
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                     children: [

//                       // ── Compteurs ──────────────────
//                       Row(
//                         children: [
//                           Expanded(child: _buildStatCard(
//                             '$_countCommandes', 'Commandes',
//                             AppColors.green, AppColors.greenLight)),
//                           const SizedBox(width: 8),
//                           Expanded(child: _buildStatCard(
//                             '$_countEnCours', 'En cours',
//                             AppColors.amber, AppColors.amberLight)),
//                           if (_avecAgent) ...[
//                             const SizedBox(width: 8),
//                             Expanded(child: _buildStatCard(
//                               '$_countAgents', 'Agents',
//                               AppColors.primary,
//                               AppColors.primaryLight)),
//                           ],
//                         ],
//                       ),

//                       const SizedBox(height: 16),

//                       // ── Bannière si pas configuré ──
//                       if (!_configExiste)
//                         // ✅ CORRECTION — ParametresServiceScreen
//                         GestureDetector(
//                           onTap: () async {
//                             await Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (_) =>
//                                     ParametresServiceScreen(
//                                       prestataireId:
//                                           widget.prestataireId,
//                                     )));
//                             _loadData();
//                           },
//                           child: Container(
//                             margin: const EdgeInsets
//                                 .only(bottom: 16),
//                             padding:
//                                 const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: AppColors.amberLight,
//                               borderRadius:
//                                   BorderRadius.circular(12),
//                               border: Border.all(
//                                 color: AppColors.amber
//                                     .withValues(alpha: 0.3))),
//                             child: Row(
//                               children: [
//                                 const Icon(
//                                   Icons.settings_outlined,
//                                   color: AppColors.amber,
//                                   size: 20),
//                                 const SizedBox(width: 10),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment
//                                             .start,
//                                     children: [
//                                       Text(
//                                         "Configurez votre service",
//                                         style:
//                                             GoogleFonts.poppins(
//                                           fontSize: 12,
//                                           fontWeight:
//                                               FontWeight.w600,
//                                           color:
//                                               AppColors.amber,
//                                         ),
//                                       ),
//                                       Text(
//                                         "Ajoutez vos tarifs pour "
//                                         "être visible par les clients",
//                                         style:
//                                             GoogleFonts.poppins(
//                                           fontSize: 11,
//                                           color: AppColors.amber,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const Icon(
//                                   Icons.arrow_forward_ios,
//                                   color: AppColors.amber,
//                                   size: 14),
//                               ],
//                             ),
//                           ),
//                         ),

//                       const SizedBox(height: 8),

//                       // ── Actions ────────────────────
//                       Text("Mes actions",
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                       const SizedBox(height: 10),

//                       GridView.count(
//                         crossAxisCount: 2,
//                         shrinkWrap: true,
//                         physics:
//                             const NeverScrollableScrollPhysics(),
//                         crossAxisSpacing: 10,
//                         mainAxisSpacing: 10,
//                         childAspectRatio: 0.85,
//                         children: [

//                           // ✅ CORRECTION — Mon service → ParametresServiceScreen
//                           GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) =>
//                                       ParametresServiceScreen(
//                                         prestataireId:
//                                             widget.prestataireId,
//                                       )));
//                               _loadData();
//                             },
//                             child: Container(
//                               padding:
//                                   const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(14),
//                                 border: Border.all(
//                                   color: _configExiste
//                                       ? AppColors.green
//                                       : AppColors.border,
//                                   width: _configExiste
//                                       ? 1.5 : 0.5)),
//                               child: Column(
//                                 crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment
//                                             .spaceBetween,
//                                     children: [
//                                       Container(
//                                         width: 32,
//                                         height: 32,
//                                         decoration: BoxDecoration(
//                                           color:
//                                               AppColors.greenLight,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(8)),
//                                         child: const Icon(
//                                           Icons.settings_outlined,
//                                           color: AppColors.green,
//                                           size: 16),
//                                       ),
//                                       Container(
//                                         padding:
//                                             const EdgeInsets
//                                                 .symmetric(
//                                                   horizontal: 6,
//                                                   vertical: 2),
//                                         decoration: BoxDecoration(
//                                           color: _configExiste
//                                               ? AppColors
//                                                   .greenLight
//                                               : AppColors
//                                                   .amberLight,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(20)),
//                                         child: Text(
//                                           _configExiste
//                                               ? "✅ OK"
//                                               : "⚠️",
//                                           style:
//                                               GoogleFonts.poppins(
//                                             fontSize: 9,
//                                             fontWeight:
//                                                 FontWeight.w500,
//                                             color: _configExiste
//                                                 ? AppColors.green
//                                                 : AppColors.amber,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text("Mon service",
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w600,
//                                       color:
//                                           AppColors.textPrimary,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   const Divider(height: 1),
//                                   const SizedBox(height: 6),
//                                   if (_configExiste &&
//                                       _prestationsConfig
//                                           .isNotEmpty)
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment
//                                                 .start,
//                                         children: [
//                                           Expanded(
//                                             child:
//                                                 SingleChildScrollView(
//                                               child: Wrap(
//                                                 spacing: 4,
//                                                 runSpacing: 4,
//                                                 children:
//                                                     _prestationsConfig
//                                                         .map((presta) =>
//                                                           Container(
//                                                             padding: const EdgeInsets
//                                                                 .symmetric(
//                                                                   horizontal:
//                                                                       6,
//                                                                   vertical:
//                                                                       2),
//                                                             decoration:
//                                                                 BoxDecoration(
//                                                               color: AppColors
//                                                                   .greenLight,
//                                                               borderRadius:
//                                                                   BorderRadius
//                                                                       .circular(
//                                                                           20),
//                                                             ),
//                                                             child: Text(
//                                                               "${presta['nom']}"
//                                                               " · ${(presta['prix'] as num).toInt()}F",
//                                                               style:
//                                                                   GoogleFonts
//                                                                       .poppins(
//                                                                 fontSize: 9,
//                                                                 color: AppColors
//                                                                     .green,
//                                                                 fontWeight:
//                                                                     FontWeight
//                                                                         .w500,
//                                                               ),
//                                                             ),
//                                                           ))
//                                                         .toList(),
//                                               ),
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Wrap(
//                                             spacing: 3,
//                                             runSpacing: 3,
//                                             children: [
//                                               if (_options[
//                                                       'express'] ==
//                                                   true)
//                                                 _chip("⚡",
//                                                     AppColors
//                                                         .amber),
//                                               if (_options[
//                                                       'collecte'] ==
//                                                   true)
//                                                 _chip("🏠",
//                                                     AppColors
//                                                         .primary),
//                                               if (_options[
//                                                       'livraison'] ==
//                                                   true)
//                                                 _chip("🚚",
//                                                     AppColors
//                                                         .primary),
//                                             ],
//                                           ),
//                                         ],
//                                       ),
//                                     )
//                                   else
//                                     Expanded(
//                                       child: Text(
//                                         "Appuyez pour configurer",
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 10,
//                                           color: AppColors
//                                               .textSecond,
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ),

//                           // ✅ CORRECTION — Ma zone → ParametresServiceScreen
//                           GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) =>
//                                       ParametresServiceScreen( prestataireId:
//                                             widget.prestataireId, )));
//                               _loadData();
//                             },
//                             child: Container(
//                               padding:
//                                   const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(14),
//                                 border: Border.all(
//                                   color: _zoneConfig.isNotEmpty
//                                       ? AppColors.amber
//                                       : AppColors.border,
//                                   width: _zoneConfig.isNotEmpty
//                                       ? 1.5 : 0.5)),
//                               child: Column(
//                                 crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment
//                                             .spaceBetween,
//                                     children: [
//                                       Expanded(
//                                         child: Row(
//                                           children: [
//                                             Container(
//                                               width: 32,
//                                               height: 32,
//                                               decoration: BoxDecoration(
//                                                 color: AppColors
//                                                     .amberLight,
//                                                 borderRadius:
//                                                     BorderRadius
//                                                         .circular(
//                                                             10)),
//                                               child: const Icon(
//                                                 Icons
//                                                     .location_on_outlined,
//                                                 color:
//                                                     AppColors.amber,
//                                                 size: 18),
//                                             ),
//                                             const SizedBox(
//                                                 width: 6),
//                                             Text("Ma zone",
//                                               style:
//                                                   GoogleFonts
//                                                       .poppins(
//                                                 fontSize: 13,
//                                                 fontWeight:
//                                                     FontWeight.w600,
//                                                 color: AppColors
//                                                     .textPrimary,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Container(
//                                         padding:
//                                             const EdgeInsets
//                                                 .symmetric(
//                                                   horizontal: 8,
//                                                   vertical: 3),
//                                         decoration: BoxDecoration(
//                                           color:
//                                               _zoneConfig.isNotEmpty
//                                                   ? AppColors
//                                                       .amberLight
//                                                   : AppColors
//                                                       .background,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(20)),
//                                         child: Text(
//                                           _zoneConfig.isNotEmpty
//                                               ? "✅ OK"
//                                               : "⚠️ Vide",
//                                           style:
//                                               GoogleFonts.poppins(
//                                             fontSize: 9,
//                                             fontWeight:
//                                                 FontWeight.w500,
//                                             color: _zoneConfig
//                                                     .isNotEmpty
//                                                 ? AppColors.amber
//                                                 : AppColors
//                                                     .textMuted,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   if (_zoneConfig.isNotEmpty) ...[
//                                     const SizedBox(height: 8),
//                                     const Divider(height: 1),
//                                     const SizedBox(height: 8),
//                                     Expanded(
//                                       child:
//                                           SingleChildScrollView(
//                                         child: Row(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment
//                                                   .start,
//                                           children: [
//                                             const Icon(
//                                               Icons
//                                                   .location_on_rounded,
//                                               color:
//                                                   AppColors.amber,
//                                               size: 14),
//                                             const SizedBox(
//                                                 width: 4),
//                                             Expanded(
//                                               child: Text(
//                                                 _zoneConfig,
//                                                 style: GoogleFonts
//                                                     .poppins(
//                                                   fontSize: 11,
//                                                   color: AppColors
//                                                       .textPrimary,
//                                                   fontWeight:
//                                                       FontWeight
//                                                           .w500,
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                   ] else ...[
//                                     const SizedBox(height: 8),
//                                     Expanded(
//                                       child: Text(
//                                         "Définissez votre zone",
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 10,
//                                           color: AppColors
//                                               .textSecond,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ],
//                               ),
//                             ),
//                           ),

//                           // Commandes
//                           _buildActionCard(
//                             Icons.list_alt_outlined,
//                             "Commandes",
//                             "Gérer les demandes",
//                             AppColors.primary,
//                             AppColors.primaryLight,
//                             onTap: () =>
//                                 setState(() => _currentIndex = 1),
//                           ),

//                           // Mes avis
//                           _buildActionCard(
//                             Icons.star_outline,
//                             "Mes avis",
//                             "Évaluations clients",
//                             AppColors.purple,
//                             AppColors.purpleLight,
//                             onTap: () {},
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 16),

//                       // ── Dernières commandes ────────
//                       Text("Dernières commandes",
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                       const SizedBox(height: 8),

//                       _dernieresCommandes.isEmpty
//                           ? Container(
//                               padding:
//                                   const EdgeInsets.all(20),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: AppColors.border,
//                                   width: 0.5)),
//                               child: Center(
//                                 child: Column(
//                                   children: [
//                                     const Icon(
//                                       Icons.inbox_outlined,
//                                       color: AppColors.textMuted,
//                                       size: 36),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       "Aucune commande pour l'instant",
//                                       style: GoogleFonts.poppins(
//                                         fontSize: 12,
//                                         color:
//                                             AppColors.textSecond,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             )
//                           : Column(
//                               children: _dernieresCommandes
//                                   .map((cmd) =>
//                                     _buildCommandeRecente(
//                                       cmd as Map<String, dynamic>))
//                                   .toList(),
//                             ),

//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//         ),
//       ],
//     );
//   }

//   // ── Stat card ──────────────────────────────────────
//   Widget _buildStatCard(
//     String count, String label,
//     Color color, Color bgColor,
//   ) {
//     return Container(
//       padding: const EdgeInsets.symmetric(
//           vertical: 14, horizontal: 8),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: color.withValues(alpha: 0.2)),
//       ),
//       child: Column(
//         children: [
//           Text(count,
//             style: GoogleFonts.poppins(
//               fontSize: 22,
//               fontWeight: FontWeight.w700,
//               color: color,
//             ),
//           ),
//           Text(label,
//             style: GoogleFonts.poppins(
//               fontSize: 10,
//               color: color,
//               fontWeight: FontWeight.w500,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Action card ────────────────────────────────────
//   Widget _buildActionCard(
//     IconData icon, String title, String desc,
//     Color color, Color bgColor, {
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//               color: AppColors.border, width: 0.5),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 38, height: 38,
//               decoration: BoxDecoration(
//                 color: bgColor,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, color: color, size: 20),
//             ),
//             const SizedBox(height: 8),
//             Text(title,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(desc,
//               style: GoogleFonts.poppins(
//                 fontSize: 10,
//                 color: AppColors.textSecond,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _chip(String emoji, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(
//           horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//             color: color.withValues(alpha: 0.3)),
//       ),
//       child: Text(emoji,
//           style: const TextStyle(fontSize: 10)),
//     );
//   }

//   // ── Commande récente (home) ────────────────────────
//   Widget _buildCommandeRecente(
//       Map<String, dynamic> cmd) {
//     final statut = cmd['statut'] as String? ?? '';
//     // Afficher étapeActuelle si disponible (étapes dynamiques), sinon statut
//     final etapeActuelle = cmd['etapeActuelle'] as String?
//         ?? cmd['etapeCourante'] as String?
//         ?? '';
//     final clefAffichage = etapeActuelle.isNotEmpty ? etapeActuelle : statut;
//     final config = _getEtatConfig(clefAffichage);

//     return GestureDetector(
//       onTap: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => CommandeDetailScreen(
//             commande:         cmd,
//             etapesEffectives: _etapesEffectives,
//             agents:           _agents,
//             prestataireId:    widget.prestataireId,
//           ),
//         ),
//       ).then((_) => _loadData()),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 8),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//               color: AppColors.border, width: 0.5)),
//         child: Row(
//           children: [
//             Container(
//               width: 42, height: 42,
//               decoration: BoxDecoration(
//                 color: config['bgColor'] as Color,
//                 borderRadius:
//                     BorderRadius.circular(10)),
//               child: Icon(
//                 config['icon'] as IconData,
//                 color: config['color'] as Color,
//                 size: 20),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment:
//                     CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     cmd['nomClient'] as String? ?? '',
//                     style: GoogleFonts.poppins(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       color: AppColors.textPrimary,
//                     ),
//                   ),
//                   Text(
//                     "${cmd['motDepot'] == 'COLLECTE_DOMICILE' ? 'Collecte' : 'Dépôt'}"
//                     " · ${cmd['dateCommande'] ?? ''}",
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       color: AppColors.textSecond,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               crossAxisAlignment:
//                   CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   "${(cmd['montantTotal'] as num? ?? 0).toInt()} FCFA",
//                   style: GoogleFonts.poppins(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.green,
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 8, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: config['bgColor'] as Color,
//                     borderRadius:
//                         BorderRadius.circular(20)),
//                   child: Text(
//                     config['label'] as String,
//                     style: GoogleFonts.poppins(
//                       fontSize: 9,
//                       color: config['color'] as Color,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(width: 6),
//             const Icon(
//               Icons.chevron_right,
//               color: AppColors.textMuted,
//               size: 18),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Config état : statuts fixes du cycle de vie ──────
//   // Les étapes dynamiques (etapesEffectives) viennent de l'API
//   // et sont affichées via le fallback générique.
//   // Naboopay gère le paiement → pas de cas PAIEMENT_RECU ici.
//   Map<String, dynamic> _getEtatConfig(String clef) {
//     switch (clef) {

//       // ── Statuts fixes ─────────────────────────────────
//       case 'CREE':
//         return { 'label': 'Nouvelle',    'color': AppColors.primary,
//           'bgColor': AppColors.primaryLight, 'icon': Icons.fiber_new_outlined };
//       case 'CONFIRMEE':
//         return { 'label': 'Confirmée',   'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.check_circle_outline };
//       case 'TERMINEE':
//         return { 'label': 'Terminée',    'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.check_circle_outline };
//       case 'CLOTUREE':
//         return { 'label': 'Clôturée ✅', 'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.lock_outline };
//       case 'ANNULEE':
//         return { 'label': 'Annulée',     'color': AppColors.red,
//           'bgColor': AppColors.redLight,    'icon': Icons.cancel_outlined };
//       case 'LITIGE':
//         return { 'label': 'Litige',      'color': AppColors.amber,
//           'bgColor': AppColors.amberLight,  'icon': Icons.warning_amber_outlined };

//       // ── Étape dynamique quelconque (API etapesEffectives) ─
//       // "EN_DEPOT", "EN_REPARATION", etc. → formaté automatiquement
//       default:
//         if (clef.isNotEmpty) {
//           final label = clef
//               .replaceAll('_', ' ')
//               .toLowerCase()
//               .replaceFirstMapped(
//                   RegExp(r'^.'), (m) => m[0]!.toUpperCase());
//           return { 'label': label,  'color': AppColors.primary,
//             'bgColor': AppColors.primaryLight,
//             'icon': Icons.pending_outlined };
//         }
//         return { 'label': '—', 'color': AppColors.textMuted,
//           'bgColor': AppColors.background, 'icon': Icons.help_outline };
//     }
//   }

//   // ══ PAGE PROFIL ══════════════════════════════════
//   Widget _buildProfil() {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         automaticallyImplyLeading: false,
//         title: Text("Mon profil",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             const SizedBox(height: 20),
//             Container(
//               width: 80, height: 80,
//               decoration: BoxDecoration(
//                 color: AppColors.greenLight,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: AppColors.green
//                       .withValues(alpha: 0.3),
//                   width: 2),
//               ),
//               child: Center(
//                 child: Text(_initiales,
//                   style: GoogleFonts.poppins(
//                     fontSize: 28,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.green,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(_nomCommercial,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(_zone,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: AppColors.textSecond,
//               ),
//             ),
//             const SizedBox(height: 24),
//             _buildProfilItem(Icons.person_outline,
//                 "Nom complet", '$_prenom $_nom'),
//             _buildProfilItem(Icons.email_outlined,
//                 "Email", _email),
//             _buildProfilItem(Icons.location_on_outlined,
//                 "Zone", _zone.isNotEmpty ? _zone : 'Non configurée'),
//             _buildProfilItem(Icons.work_outline,
//                 "Type de service",
//                 _typeService.isNotEmpty
//                     ? _typeService : 'Non configuré'),
//             const SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               // ✅ CORRECTION — AppColors.red (pas Colors.red)
//               child: OutlinedButton.icon(
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: AppColors.red,
//                   side: const BorderSide(color: AppColors.red),
//                   padding: const EdgeInsets.symmetric(
//                       vertical: 12),
//                 ),
//                 onPressed: _logout,
//                 icon: const Icon(Icons.logout),
//                 label: Text("Déconnexion",
//                   style: GoogleFonts.poppins(fontSize: 14)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProfilItem(
//       IconData icon, String label, String value) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: AppColors.border, width: 0.5),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, color: AppColors.green, size: 20),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment:
//                 CrossAxisAlignment.start,
//             children: [
//               Text(label,
//                 style: GoogleFonts.poppins(
//                   fontSize: 11,
//                   color: AppColors.textSecond,
//                 ),
//               ),
//               Text(value,
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Dialog déconnexion ────────────────────────────
//   void _showLogoutDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16)),
//         title: Text("Déconnexion",
//           style: GoogleFonts.poppins(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         content: Text(
//           "Voulez-vous vraiment vous déconnecter ?",
//           style: GoogleFonts.poppins(fontSize: 13),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Annuler",
//               style: GoogleFonts.poppins(
//                   color: AppColors.textSecond)),
//           ),
//           // ✅ CORRECTION — AppColors.red
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.red,
//               foregroundColor: Colors.white,
//             ),
//             onPressed: () {
//               Navigator.pop(context);
//               _logout();
//             },
//             icon: const Icon(Icons.logout, size: 16),
//             label: Text("Déconnexion",
//               style: GoogleFonts.poppins(fontSize: 13)),
//           ),
//         ],
//       ),
//     );
//   }
// }

///#################################///////////






// // prestataire_home_screen.dart
// // Tableau de bord principal du prestataire.
// //
// // BUGS CORRIGÉS (3) :
// //   ✅ Bug 1 — "Pressing · Actif" hardcodé × 2 → remplacé par _labelService (getter dynamique)
// //   ✅ Bug 2 — Profil nav index toujours 3 → setState(() => _currentIndex = _avecAgent ? 3 : 2)
// //   ✅ Bug 3 — bool _avecAgent = true (défaut) → remplacé par false (valeur API)

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// // Imports du projet (adapter selon la structure réelle)
// // import '../../core/constants/app_colors.dart';
// // import '../../core/constants/api_constants.dart';
// // import '../../core/services/auth_storage.dart';
// // import 'prestataire_commandes_screen.dart';
// // import 'prestataire_statistiques_screen.dart';
// // import 'prestataire_agents_screen.dart';
// // import 'prestataire_config_screen.dart';
// // import 'parametres_screen.dart';

// class PrestataireHomeScreen extends StatefulWidget {
//   final int prestataireId;

//   const PrestataireHomeScreen({
//     super.key,
//     required this.prestataireId,
//   });

//   @override
//   State<PrestataireHomeScreen> createState() => _PrestataireHomeScreenState();
// }

// class _PrestataireHomeScreenState extends State<PrestataireHomeScreen> {
//   static const Color _teal = Color(0xFF0F766E);
//   static const Color _tealLight = Color(0xFFCCFBF1);
//   static const String _baseUrl = 'http://localhost:7090';

//   // ── BUG 3 CORRIGÉ : _avecAgent initialisé à false (valeur API) ───────────
//   bool _avecAgent = false;

//   Map<String, dynamic> _prestataire = {};
//   Map<String, dynamic> _config = {};
//   List<Map<String, dynamic>> _commandes = [];
//   bool _loading = true;
//   int _currentIndex = 0;
//   int _notifCount = 0;

//   // ── BUG 1 CORRIGÉ : getter dynamique au lieu de chaîne hardcodée ─────────
//   /// Renvoie ex: "Pressing", "Réparation", "Soins" selon la config API
//   String get _labelService =>
//       _config['typeServiceNom'] as String? ??
//       _prestataire['typeServiceNom'] as String? ??
//       'Service';

//   /// "Actif" ou "Inactif" selon le statut du prestataire
//   String get _labelStatut =>
//       (_prestataire['actif'] as bool? ?? true) ? 'Actif' : 'Inactif';

//   // Statistiques rapides
//   int get _enAttente => _commandes.where((c) => c['statut'] == 'CREE').length;
//   int get _enCours => _commandes.where((c) {
//         final s = c['statut'] as String? ?? '';
//         return s != 'CREE' && s != 'CLOTUREE' && s != 'ANNULEE';
//       }).length;
//   int get _terminees =>
//       _commandes.where((c) => c['statut'] == 'CLOTUREE').length;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => _loading = true);
//     await Future.wait([
//       _loadPrestataire(),
//       _loadConfig(),
//       _loadCommandes(),
//     ]);
//     setState(() => _loading = false);
//   }

//   Future<void> _loadPrestataire() async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         setState(() =>
//             _prestataire = jsonDecode(res.body) as Map<String, dynamic>);
//       }
//     } catch (_) {
//       _prestataire = _demoPrestataire();
//     }
//   }

//   Future<void> _loadConfig() async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         final config = jsonDecode(res.body) as Map<String, dynamic>;
//         setState(() {
//           _config = config;
//           // ── BUG 3 CORRIGÉ : avecAgent vient de l'API ─────────────────
//           _avecAgent = config['avecAgent'] as bool? ?? false;
//         });
//       }
//     } catch (_) {
//       _config = _demoConfig();
//       _avecAgent = false; // valeur par défaut sûre
//     }
//   }

//   Future<void> _loadCommandes() async {
//     try {
//       final res = await http.get(
//         Uri.parse(
//             '$_baseUrl/api/commandes/prestataire/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         final list = jsonDecode(res.body) as List;
//         setState(() {
//           _commandes = list.cast<Map<String, dynamic>>();
//           _notifCount =
//               _commandes.where((c) => c['statut'] == 'CREE').length;
//         });
//       }
//     } catch (_) {
//       _commandes = _demoCommandes();
//       _notifCount = _commandes.where((c) => c['statut'] == 'CREE').length;
//     }
//   }

//   Map<String, dynamic> _demoPrestataire() => {
//     'id': widget.prestataireId,
//     'nom': 'Express Laverie Pro',
//     'typeServiceNom': 'Pressing',
//     'actif': true,
//     'adresse': 'Quartier Liberté, Dakar',
//     'telephone': '+221 77 123 45 67',
//   };

//   Map<String, dynamic> _demoConfig() => {
//     'typeServiceNom': 'Pressing',
//     'avecAgent': false,
//     'etapesEffectives': [
//       'CREE', 'CONFIRMEE', 'EN_COLLECTE', 'EN_TRAITEMENT', 'EN_LIVRAISON', 'CLOTUREE'
//     ],
//   };

//   List<Map<String, dynamic>> _demoCommandes() => [
//     {'id': 1, 'statut': 'CREE', 'clientNom': 'Fatou Diallo', 'totalEstime': 3100},
//     {'id': 2, 'statut': 'EN_TRAITEMENT', 'clientNom': 'Ibrahima Sow', 'totalEstime': 5500},
//     {'id': 3, 'statut': 'CLOTUREE', 'clientNom': 'Mariama Ba', 'totalEstime': 2000},
//   ];

//   // ── Navigation items dynamique selon _avecAgent ───────────────────────────
//   List<BottomNavigationBarItem> get _navItems => [
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.home_rounded),
//       label: 'Accueil',
//     ),
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.receipt_long_rounded),
//       label: 'Commandes',
//     ),
//     // Agents seulement si avecAgent = true
//     if (_avecAgent)
//       const BottomNavigationBarItem(
//         icon: Icon(Icons.people_rounded),
//         label: 'Agents',
//       ),
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.person_rounded),
//       label: 'Profil',
//     ),
//   ];

//   void _onNavTap(int idx) => setState(() => _currentIndex = idx);

//   Widget _buildScreen(int idx) {
//     if (idx == 0) return _buildAccueil();
//     if (idx == 1) return _buildCommandesPlaceholder();
//     if (idx == 2 && _avecAgent) return _buildAgentsPlaceholder();
//     // ── BUG 2 CORRIGÉ : index profil = _avecAgent ? 3 : 2 ────────────────
//     final profilIdx = _avecAgent ? 3 : 2;
//     if (idx == profilIdx) return _buildProfilPlaceholder();
//     return _buildAccueil();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: _buildAppBar(),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _buildScreen(_currentIndex),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: _onNavTap,
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: _teal,
//         unselectedItemColor: const Color(0xFF94A3B8),
//         selectedLabelStyle: const TextStyle(
//           fontWeight: FontWeight.w700,
//           fontSize: 11,
//         ),
//         unselectedLabelStyle: const TextStyle(fontSize: 11),
//         elevation: 16,
//         items: _navItems,
//       ),
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: _teal,
//       foregroundColor: Colors.white,
//       elevation: 0,
//       title: const Text(
//         'ServiProx',
//         style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
//       ),
//       actions: [
//         // Cloche notification avec badge
//         Stack(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.notifications_outlined),
//               onPressed: () => setState(() => _currentIndex = 1),
//               tooltip: 'Nouvelles commandes',
//             ),
//             if (_notifCount > 0)
//               Positioned(
//                 top: 8,
//                 right: 8,
//                 child: Container(
//                   width: 18,
//                   height: 18,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFEF4444),
//                     shape: BoxShape.circle,
//                     border: Border.all(color: _teal, width: 2),
//                   ),
//                   child: Center(
//                     child: Text(
//                       '$_notifCount',
//                       style: const TextStyle(
//                         fontSize: 9,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         IconButton(
//           icon: const Icon(Icons.settings_outlined),
//           onPressed: () {
//             Navigator.pushNamed(context, '/parametres');
//           },
//           tooltip: 'Paramètres',
//         ),
//       ],
//     );
//   }

//   // ── ACCUEIL ───────────────────────────────────────────────────────────────
//   Widget _buildAccueil() {
//     final nomPrestataire = _prestataire['nom'] as String? ?? 'Mon établissement';

//     return RefreshIndicator(
//       color: _teal,
//       onRefresh: _loadData,
//       child: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Carte identité prestataire ──────────────────────────────
//             _buildCartePrestataire(nomPrestataire),

//             const SizedBox(height: 16),

//             // ── Stats rapides ────────────────────────────────────────────
//             _buildStatsRapides(),

//             const SizedBox(height: 24),

//             // ── Raccourcis ────────────────────────────────────────────────
//             const Text(
//               'Accès rapide',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             const SizedBox(height: 12),
//             _buildRaccourcis(),

//             const SizedBox(height: 24),

//             // ── Dernières commandes ───────────────────────────────────────
//             Row(
//               children: [
//                 const Text(
//                   'Commandes récentes',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 const Spacer(),
//                 TextButton(
//                   onPressed: () => setState(() => _currentIndex = 1),
//                   child: const Text('Tout voir →'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             ..._commandes.take(3).map(_buildCommandeCard),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCartePrestataire(String nom) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [_teal, _teal.withValues(alpha: 0.8)],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: _teal.withValues(alpha: 0.3),
//             blurRadius: 16,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 56,
//                 height: 56,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Center(
//                   child: Text(
//                     nom.isNotEmpty ? nom[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       nom,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     // ── BUG 1 CORRIGÉ : _labelService + _labelStatut ────────
//                     Text(
//                       '$_labelService · $_labelStatut',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withValues(alpha: 0.8),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 10, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 7,
//                       height: 7,
//                       decoration: const BoxDecoration(
//                         color: Color(0xFF4ADE80),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 5),
//                     const Text(
//                       'En ligne',
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           // ── BUG 1 CORRIGÉ : label dynamique ────────────────────────────
//           Text(
//             '$_labelService · Tableau de bord',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.white.withValues(alpha: 0.6),
//               letterSpacing: 0.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatsRapides() {
//     return Row(
//       children: [
//         _buildStatBadge(
//           label: 'En attente',
//           count: _enAttente,
//           color: const Color(0xFFF59E0B),
//           bg: const Color(0xFFFEF3C7),
//           icon: '⏳',
//         ),
//         const SizedBox(width: 10),
//         _buildStatBadge(
//           label: 'En cours',
//           count: _enCours,
//           color: const Color(0xFF3B82F6),
//           bg: const Color(0xFFEFF6FF),
//           icon: '⚙️',
//         ),
//         const SizedBox(width: 10),
//         _buildStatBadge(
//           label: 'Terminées',
//           count: _terminees,
//           color: const Color(0xFF16A34A),
//           bg: const Color(0xFFDCFCE7),
//           icon: '✅',
//         ),
//       ],
//     );
//   }

//   Widget _buildStatBadge({
//     required String label,
//     required int count,
//     required Color color,
//     required Color bg,
//     required String icon,
//   }) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
//               child: Center(
//                 child: Text(icon, style: const TextStyle(fontSize: 16)),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w900,
//                 color: color,
//               ),
//             ),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 11,
//                 color: Color(0xFF64748B),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRaccourcis() {
//     final items = [
//       {
//         'icon': Icons.receipt_long_rounded,
//         'label': 'Commandes',
//         'nav': 1,
//       },
//       {
//         'icon': Icons.bar_chart_rounded,
//         'label': 'Statistiques',
//         'route': '/prestataire/statistiques',
//       },
//       {
//         'icon': Icons.settings_rounded,
//         'label': 'Configuration',
//         'route': '/prestataire/config',
//       },
//       if (_avecAgent)
//         {
//           'icon': Icons.people_rounded,
//           'label': 'Agents',
//           'nav': 2,
//         },
//     ];

//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3,
//         crossAxisSpacing: 10,
//         mainAxisSpacing: 10,
//         childAspectRatio: 1.1,
//       ),
//       itemCount: items.length,
//       itemBuilder: (context, i) {
//         final item = items[i];
//         return GestureDetector(
//           onTap: () {
//             if (item.containsKey('nav')) {
//               setState(() => _currentIndex = item['nav'] as int);
//             } else if (item.containsKey('route')) {
//               Navigator.pushNamed(context, item['route'] as String);
//             }
//           },
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(14),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(item['icon'] as IconData, size: 28, color: _teal),
//                 const SizedBox(height: 6),
//                 Text(
//                   item['label'] as String,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildCommandeCard(Map<String, dynamic> c) {
//     final statut = c['statut'] as String? ?? '';
//     final client = c['clientNom'] as String? ?? 'Client';
//     final total = c['totalEstime'] as int? ?? 0;

//     const labels = {
//       'CREE': 'En attente',
//       'CONFIRMEE': 'Confirmée',
//       'EN_COLLECTE': 'En collecte',
//       'EN_TRAITEMENT': 'En traitement',
//       'EN_LIVRAISON': 'En livraison',
//       'CLOTUREE': 'Clôturée',
//       'ANNULEE': 'Annulée',
//     };
//     const colors = {
//       'CREE': Color(0xFFF59E0B),
//       'CONFIRMEE': Color(0xFF3B82F6),
//       'EN_COLLECTE': Color(0xFF8B5CF6),
//       'EN_TRAITEMENT': Color(0xFFF97316),
//       'EN_LIVRAISON': Color(0xFF06B6D4),
//       'CLOTUREE': Color(0xFF16A34A),
//       'ANNULEE': Color(0xFFDC2626),
//     };

//     final statColor = colors[statut] ?? const Color(0xFF94A3B8);
//     final statLabel = labels[statut] ?? statut;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 10,
//             height: 10,
//             decoration: BoxDecoration(
//               color: statColor,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   client,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 Text(
//                   statLabel,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: statColor,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Text(
//             '$total FCFA',
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── PLACEHOLDER SCREENS (naviguer vers les vraies classes) ────────────────
//   Widget _buildCommandesPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer PrestataireCommandesScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }

//   Widget _buildAgentsPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer PrestataireAgentsScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }

//   Widget _buildProfilPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer ProfilScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }
// }




///#################################///////////

// // lib/features/prestataire/prestataire_home_screen.dart
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:memoireserviprox/features/prestataire/Commande_detail_screen.dart';

// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';
// import '../auth/login_screen.dart';
// import 'prestataire_commandes_screen.dart';
// import 'prestataire_agents_screen.dart';
// import 'prestataire_statistiques_screen.dart';
// // ✅ CORRECTION — ParametresServiceScreen (métamodèle config) remplace PrestataireConfigScreen
// import 'parametres_service_screen.dart';
// import 'parametres_screen.dart' hide ParametresServiceScreen;
// //import '../prestataire/Commande_detail_screen.dart'

// class PrestataireHomeScreen extends StatefulWidget {
//   // ✅ prestataireId required (splash + otp le passent)
//   final int prestataireId;
//   const PrestataireHomeScreen({
//     super.key,
//     required this.prestataireId,
//   });

//   @override
//   State<PrestataireHomeScreen> createState() =>
//       _PrestataireHomeScreenState();
// }

// class _PrestataireHomeScreenState
//     extends State<PrestataireHomeScreen> {

//   // ── Variables d'état ──────────────────────────────
//   int _currentIndex = 0;
//   String _nomCommercial = '';
//   String _prenom = '';
//   String _nom = '';
//   String _email = '';
//   String _zone = '';
//   int _countCommandes = 0;
//   int _countEnCours = 0;
//   int _countAgents = 0;
//   bool _isLoading = true;
//   String _typeService = '';
//   bool _avecAgent = true;

//   // Variables config récapitulatif
//   bool _configExiste = false;
//   Map<String, dynamic> _options = {};
//   List<Map<String, dynamic>> _prestationsConfig = [];
//   List<dynamic> _dernieresCommandes = [];
//   String _zoneConfig = '';

//   // pour CommandeDetailScreen (nouveau constructeur)
//   List<String> _etapesEffectives = [];
//   List<Map<String, dynamic>> _agents = [];

//   // ── Initiales ─────────────────────────────────────
//   String get _initiales {
//     return _nomCommercial
//         .trim()
//         .split(' ')
//         .where((w) => w.isNotEmpty)
//         .take(2)
//         .map((w) => w[0].toUpperCase())
//         .join();
//   }

//   // ✅ CORRECTION OpenEHR — libellé générique depuis l'API
//   // Plus de switch(_typeService) hardcodé
//   String get _labelService {
//     if (_typeService.isEmpty) return 'En activité';
//     final label = _typeService[0].toUpperCase() +
//         _typeService.substring(1).toLowerCase();
//     return '$label · Actif';
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   // ── Charger données ───────────────────────────────
//   Future<void> _loadData() async {
//     final prenom = await AuthStorage.getPrenom();
//     final nom    = await AuthStorage.getNom();
//     final email  = await AuthStorage.getEmail();
//     final token  = await AuthStorage.getToken();

//     await Future.wait([
//       _loadConfig(widget.prestataireId, token),
//       _loadCompteurs(widget.prestataireId, token),
//     ]);

//     if (mounted) {
//       setState(() {
//         _prenom        = prenom;
//         _nom           = nom;
//         _email         = email;
//         _nomCommercial = prenom.isNotEmpty ? '$prenom $nom' : nom;
//         _isLoading     = false;
//       });
//     }
//   }

//   // ── Charger config prestataire ────────────────────
//   Future<void> _loadConfig(int? userId, String? token) async {
//     try {
//       final configResp = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/prestataire/config/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (configResp.statusCode == 200) {
//         final data = jsonDecode(configResp.body);

//         // Parser les options
//         Map<String, dynamic> options = {};
//         if (data['optionsActives'] != null) {
//           options = jsonDecode(data['optionsActives']);
//         }

//         // Parser les prestations
//         List<Map<String, dynamic>> prestations = [];
//         if (data['prestationsAjoutees'] != null) {
//           final raw = jsonDecode(data['prestationsAjoutees']) as List;
//           for (final item in raw) {
//             if (item is Map) {
//               prestations.add({
//                 'nom':   item['nom']?.toString() ?? '',
//                 'prix':  item['prix'] ?? 0,
//                 'unite': item['unite']?.toString() ?? 'pièce',
//               });
//             } else {
//               final parts = item.toString().split(':');
//               prestations.add({
//                 'nom':   parts[0].trim(),
//                 'prix':  double.tryParse(
//                   parts.length > 1 ? parts[1].trim() : '0') ?? 0,
//                 'unite': 'pièce',
//               });
//             }
//           }
//         }
//         if (prestations.isEmpty && data['tarifsPersonnalises'] != null) {
//           final tarifs = jsonDecode(data['tarifsPersonnalises'])
//               as Map<String, dynamic>;
//           for (final entry in tarifs.entries) {
//             prestations.add({
//               'nom':   entry.key,
//               'prix':  entry.value ?? 0,
//               'unite': 'pièce',
//             });
//           }
//         }

//         // Charger etapesEffectives pour CommandeDetailScreen
//         List<String> etapes = [];
//         if (data['etapesEffectives'] != null) {
//           etapes = (data['etapesEffectives'] as List)
//               .map((e) => e.toString())
//               .toList();
//         }

//         if (mounted) {
//           setState(() {
//             _configExiste       = true;
//             _options            = options;
//             _prestationsConfig  = prestations;
//             _zoneConfig         = data['zoneCouverture'] ?? '';
//             _zone               = _zoneConfig;
//             _typeService        = data['typeService'] ?? '';
//             _avecAgent          = data['avecAgent'] as bool?
//                 ?? (data['service'] as Map<String, dynamic>?)?['avecAgent']
//                     as bool? ?? true;
//             _etapesEffectives   = etapes;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Erreur config: $e");
//     }
//   }

//   // ── Charger compteurs + agents ────────────────────
//   Future<void> _loadCompteurs(int? userId, String? token) async {
//     try {
//       // 1. Commandes
//       final cmdResp = await http.get(
//         Uri.parse('${ApiConstants.commandes}/prestataire/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (cmdResp.statusCode == 200) {
//         final List<dynamic> commandes = jsonDecode(cmdResp.body);
//         final enCours = commandes.where((c) =>
//           c['statut'] == 'CREE' ||
//           c['statut'] == 'CONFIRMEE' ||
//           c['statut'] == 'EN_TRAITEMENT'
//         ).length;

//         if (mounted) {
//           setState(() {
//             _countCommandes     = commandes.length;
//             _countEnCours       = enCours;
//             _dernieresCommandes = commandes.take(5).toList();
//           });
//         }
//       }

//       // 2. Agents
//       final agentResp = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/agents/prestataire/$userId'),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (agentResp.statusCode == 200) {
//         final List<dynamic> agents = jsonDecode(agentResp.body);
//         if (mounted) {
//           setState(() {
//             _agents      = agents.cast<Map<String, dynamic>>();
//             _countAgents = agents
//                 .where((a) => a['statut'] == 'ACTIF')
//                 .length;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("Erreur compteurs: $e");
//     }
//   }

//   // ── Déconnexion ───────────────────────────────────
//   Future<void> _logout() async {
//     await AuthStorage.logout();
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//         (route) => false,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       drawer: _buildDrawer(),
//       body: IndexedStack(
//         index: _currentIndex,
//         children: [
//           _buildAccueil(),
//           const PrestataireCommandesScreen(),
//           if (_avecAgent) const PrestataireAgentsScreen(),
//           _buildProfil(),
//         ],
//       ),
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _currentIndex,
//         onDestinationSelected: (i) =>
//             setState(() => _currentIndex = i),
//         backgroundColor: Colors.white,
//         indicatorColor: AppColors.greenLight,
//         destinations: [
//           const NavigationDestination(
//             icon: Icon(Icons.home_outlined),
//             selectedIcon: Icon(
//                 Icons.home, color: AppColors.green),
//             label: 'Accueil',
//           ),
//           const NavigationDestination(
//             icon: Icon(Icons.list_alt_outlined),
//             selectedIcon: Icon(
//                 Icons.list_alt, color: AppColors.green),
//             label: 'Commandes',
//           ),
//           if (_avecAgent)
//             const NavigationDestination(
//               icon: Icon(Icons.people_outline),
//               selectedIcon: Icon(
//                   Icons.people, color: AppColors.green),
//               label: 'Agents',
//             ),
//           const NavigationDestination(
//             icon: Icon(Icons.person_outline),
//             selectedIcon: Icon(
//                 Icons.person, color: AppColors.green),
//             label: 'Profil',
//           ),
//         ],
//       ),
//     );
//   }

//   // ══ DRAWER (menu burger) ══════════════════════════
//   Widget _buildDrawer() {
//     return Drawer(
//       backgroundColor: Colors.white,
//       child: Column(
//         children: [

//           // ── Header vert ───────────────────────────
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
//             color: AppColors.green,
//             child: Row(
//               children: [
//                 Container(
//                   width: 56, height: 56,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withValues(alpha: 0.2),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Center(
//                     child: Text(_initiales,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                     children: [
//                       Text(_nomCommercial,
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       Text(_email,
//                         style: GoogleFonts.poppins(
//                           color: Colors.white70,
//                           fontSize: 11,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.white
//                               .withValues(alpha: 0.2),
//                           borderRadius:
//                               BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           _labelService,
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Items du menu ─────────────────────────
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 16, vertical: 12),
//               children: [

//                 _drawerItem(
//                   icon: Icons.person_outline,
//                   label: "Mon profil",
//                   onTap: () {
//                     Navigator.pop(context);
//                     setState(() => _currentIndex =
//                         _avecAgent ? 3 : 2);
//                   }),

//                 _drawerItem(
//                   icon: Icons.list_alt_outlined,
//                   label: "Mes commandes",
//                   badge: _countCommandes > 0
//                       ? '$_countCommandes' : null,
//                   onTap: () {
//                     Navigator.pop(context);
//                     setState(() => _currentIndex = 1);
//                   }),

//                 // ✅ CORRECTION — ParametresServiceScreen (métamodèle)
//                 _drawerItem(
//                   icon: Icons.settings_outlined,
//                   label: "Configurer mon service",
//                   onTap: () async {
//                     Navigator.pop(context);
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => ParametresServiceScreen(
//                           prestataireId: widget.prestataireId,
//                         ),
//                       ),
//                     );
//                     _loadData();
//                   }),

//                 _drawerItem(
//                   icon: Icons.bar_chart_outlined,
//                   label: "Statistiques",
//                   onTap: () {
//                     Navigator.pop(context);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                             const PrestataireStatistiquesScreen()));
//                   }),

//                 // _drawerItem(
//                 //   icon: Icons.tune_outlined,
//                 //   label: "Mes paramètres",
//                 //   onTap: () {
//                 //     Navigator.pop(context);
//                 //     Navigator.push(
//                 //       context,
//                 //       MaterialPageRoute(
//                 //         builder: (_) =>
//                 //             const ParametresScreen()));
//                 //   }),

//                 _drawerItem(
//                   icon: Icons.headset_mic_outlined,
//                   label: "Aide & Support",
//                   onTap: () => Navigator.pop(context)),

//                 const SizedBox(height: 8),
//                 const Divider(height: 1),
//                 const SizedBox(height: 8),

//                 _drawerItem(
//                   icon: Icons.logout,
//                   label: "Se déconnecter",
//                   isLogout: true,
//                   onTap: () {
//                     Navigator.pop(context);
//                     _showLogoutDialog();
//                   }),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Item drawer épuré ─────────────────────────────
//   Widget _drawerItem({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     bool isLogout = false,
//     String? badge,
//   }) {
//     // ✅ CORRECTION — AppColors.red / AppColors.redLight (pas Colors.red / Color(0xFFFCEBEB))
//     final Color iconColor = isLogout
//         ? AppColors.red : AppColors.green;
//     final Color iconBg = isLogout
//         ? AppColors.redLight
//         : AppColors.greenLight;
//     final Color textColor = isLogout
//         ? AppColors.red : AppColors.textPrimary;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 4),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(
//             horizontal: 8, vertical: 2),
//         leading: Container(
//           width: 42, height: 42,
//           decoration: BoxDecoration(
//             color: iconBg,
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon,
//               color: iconColor, size: 20),
//         ),
//         title: Text(label,
//           style: GoogleFonts.poppins(
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//             color: textColor,
//           ),
//         ),
//         trailing: badge != null
//             ? Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: AppColors.green,
//                   borderRadius:
//                       BorderRadius.circular(20)),
//                 child: Text(badge,
//                   style: GoogleFonts.poppins(
//                     fontSize: 11,
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               )
//             : Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 14,
//                 color: isLogout
//                     ? AppColors.red
//                     : AppColors.textMuted),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12)),
//         onTap: onTap,
//       ),
//     );
//   }

//   // ══ PAGE ACCUEIL ══════════════════════════════════
//   Widget _buildAccueil() {
//     return Column(
//       children: [

//         // ── Header vert ──────────────────────────────
//         Container(
//           color: AppColors.green,
//           child: SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(
//                   16, 8, 16, 20),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment:
//                         MainAxisAlignment.spaceBetween,
//                     children: [
//                       Builder(
//                         builder: (ctx) => GestureDetector(
//                           onTap: () =>
//                               Scaffold.of(ctx).openDrawer(),
//                           child: Container(
//                             width: 34, height: 34,
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.15),
//                               borderRadius:
//                                   BorderRadius.circular(10)),
//                             child: const Icon(
//                               Icons.menu,
//                               color: Colors.white,
//                               size: 20),
//                           ),
//                         ),
//                       ),
//                       Stack(
//                         children: [
//                           Container(
//                             width: 34, height: 34,
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.15),
//                               borderRadius:
//                                   BorderRadius.circular(10)),
//                             child: const Icon(
//                               Icons.notifications_outlined,
//                               color: Colors.white,
//                               size: 20),
//                           ),
//                           Positioned(
//                             top: 6, right: 6,
//                             child: Container(
//                               width: 8, height: 8,
//                               decoration: BoxDecoration(
//                                 // ✅ AppColors.red
//                                 color: AppColors.red,
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: AppColors.green,
//                                   width: 1.5)),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 16),

//                   // Infos prestataire
//                   Row(
//                     children: [
//                       Container(
//                         width: 50, height: 50,
//                         decoration: BoxDecoration(
//                           color: Colors.white
//                               .withValues(alpha: 0.2),
//                           borderRadius:
//                               BorderRadius.circular(14)),
//                         child: Center(
//                           child: Text(_initiales,
//                             style: GoogleFonts.poppins(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Column(
//                         crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                         children: [
//                           Text(_nomCommercial,
//                             style: GoogleFonts.poppins(
//                               color: Colors.white,
//                               fontSize: 17,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.location_on_outlined,
//                                 color: Colors.white70,
//                                 size: 13),
//                               const SizedBox(width: 4),
//                               Text(
//                                 _zone.isNotEmpty
//                                     ? _zone
//                                     : 'Zone non configurée',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.white70,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             margin: const EdgeInsets
//                                 .only(top: 4),
//                             padding:
//                                 const EdgeInsets.symmetric(
//                                     horizontal: 10,
//                                     vertical: 2),
//                             decoration: BoxDecoration(
//                               color: Colors.white
//                                   .withValues(alpha: 0.2),
//                               borderRadius:
//                                   BorderRadius.circular(20)),
//                             child: Text(
//                               _labelService,
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white,
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),

//         // ── Body ─────────────────────────────────────
//         Expanded(
//           child: _isLoading
//               ? const Center(child: CircularProgressIndicator(
//                   color: AppColors.green))
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(14),
//                   child: Column(
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                     children: [

//                       // ── Compteurs ──────────────────
//                       Row(
//                         children: [
//                           Expanded(child: _buildStatCard(
//                             '$_countCommandes', 'Commandes',
//                             AppColors.green, AppColors.greenLight)),
//                           const SizedBox(width: 8),
//                           Expanded(child: _buildStatCard(
//                             '$_countEnCours', 'En cours',
//                             AppColors.amber, AppColors.amberLight)),
//                           if (_avecAgent) ...[
//                             const SizedBox(width: 8),
//                             Expanded(child: _buildStatCard(
//                               '$_countAgents', 'Agents',
//                               AppColors.primary,
//                               AppColors.primaryLight)),
//                           ],
//                         ],
//                       ),

//                       const SizedBox(height: 16),

//                       // ── Bannière si pas configuré ──
//                       if (!_configExiste)
//                         // ✅ CORRECTION — ParametresServiceScreen
//                         GestureDetector(
//                           onTap: () async {
//                             await Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (_) =>
//                                     ParametresServiceScreen(
//                                       prestataireId:
//                                           widget.prestataireId,
//                                     )));
//                             _loadData();
//                           },
//                           child: Container(
//                             margin: const EdgeInsets
//                                 .only(bottom: 16),
//                             padding:
//                                 const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: AppColors.amberLight,
//                               borderRadius:
//                                   BorderRadius.circular(12),
//                               border: Border.all(
//                                 color: AppColors.amber
//                                     .withValues(alpha: 0.3))),
//                             child: Row(
//                               children: [
//                                 const Icon(
//                                   Icons.settings_outlined,
//                                   color: AppColors.amber,
//                                   size: 20),
//                                 const SizedBox(width: 10),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment
//                                             .start,
//                                     children: [
//                                       Text(
//                                         "Configurez votre service",
//                                         style:
//                                             GoogleFonts.poppins(
//                                           fontSize: 12,
//                                           fontWeight:
//                                               FontWeight.w600,
//                                           color:
//                                               AppColors.amber,
//                                         ),
//                                       ),
//                                       Text(
//                                         "Ajoutez vos tarifs pour "
//                                         "être visible par les clients",
//                                         style:
//                                             GoogleFonts.poppins(
//                                           fontSize: 11,
//                                           color: AppColors.amber,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const Icon(
//                                   Icons.arrow_forward_ios,
//                                   color: AppColors.amber,
//                                   size: 14),
//                               ],
//                             ),
//                           ),
//                         ),

//                       const SizedBox(height: 8),

//                       // ── Actions ────────────────────
//                       Text("Mes actions",
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                       const SizedBox(height: 10),

//                       GridView.count(
//                         crossAxisCount: 2,
//                         shrinkWrap: true,
//                         physics:
//                             const NeverScrollableScrollPhysics(),
//                         crossAxisSpacing: 10,
//                         mainAxisSpacing: 10,
//                         childAspectRatio: 0.85,
//                         children: [

//                           // ✅ CORRECTION — Mon service → ParametresServiceScreen
//                           GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) =>
//                                       ParametresServiceScreen(
//                                         prestataireId:
//                                             widget.prestataireId,
//                                       )));
//                               _loadData();
//                             },
//                             child: Container(
//                               padding:
//                                   const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(14),
//                                 border: Border.all(
//                                   color: _configExiste
//                                       ? AppColors.green
//                                       : AppColors.border,
//                                   width: _configExiste
//                                       ? 1.5 : 0.5)),
//                               child: Column(
//                                 crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment
//                                             .spaceBetween,
//                                     children: [
//                                       Container(
//                                         width: 32,
//                                         height: 32,
//                                         decoration: BoxDecoration(
//                                           color:
//                                               AppColors.greenLight,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(8)),
//                                         child: const Icon(
//                                           Icons.settings_outlined,
//                                           color: AppColors.green,
//                                           size: 16),
//                                       ),
//                                       Container(
//                                         padding:
//                                             const EdgeInsets
//                                                 .symmetric(
//                                                   horizontal: 6,
//                                                   vertical: 2),
//                                         decoration: BoxDecoration(
//                                           color: _configExiste
//                                               ? AppColors
//                                                   .greenLight
//                                               : AppColors
//                                                   .amberLight,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(20)),
//                                         child: Text(
//                                           _configExiste
//                                               ? "✅ OK"
//                                               : "⚠️",
//                                           style:
//                                               GoogleFonts.poppins(
//                                             fontSize: 9,
//                                             fontWeight:
//                                                 FontWeight.w500,
//                                             color: _configExiste
//                                                 ? AppColors.green
//                                                 : AppColors.amber,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text("Mon service",
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w600,
//                                       color:
//                                           AppColors.textPrimary,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   const Divider(height: 1),
//                                   const SizedBox(height: 6),
//                                   if (_configExiste &&
//                                       _prestationsConfig
//                                           .isNotEmpty)
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment
//                                                 .start,
//                                         children: [
//                                           Expanded(
//                                             child:
//                                                 SingleChildScrollView(
//                                               child: Wrap(
//                                                 spacing: 4,
//                                                 runSpacing: 4,
//                                                 children:
//                                                     _prestationsConfig
//                                                         .map((presta) =>
//                                                           Container(
//                                                             padding: const EdgeInsets
//                                                                 .symmetric(
//                                                                   horizontal:
//                                                                       6,
//                                                                   vertical:
//                                                                       2),
//                                                             decoration:
//                                                                 BoxDecoration(
//                                                               color: AppColors
//                                                                   .greenLight,
//                                                               borderRadius:
//                                                                   BorderRadius
//                                                                       .circular(
//                                                                           20),
//                                                             ),
//                                                             child: Text(
//                                                               "${presta['nom']}"
//                                                               " · ${(presta['prix'] as num).toInt()}F",
//                                                               style:
//                                                                   GoogleFonts
//                                                                       .poppins(
//                                                                 fontSize: 9,
//                                                                 color: AppColors
//                                                                     .green,
//                                                                 fontWeight:
//                                                                     FontWeight
//                                                                         .w500,
//                                                               ),
//                                                             ),
//                                                           ))
//                                                         .toList(),
//                                               ),
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Wrap(
//                                             spacing: 3,
//                                             runSpacing: 3,
//                                             children: [
//                                               if (_options[
//                                                       'express'] ==
//                                                   true)
//                                                 _chip("⚡",
//                                                     AppColors
//                                                         .amber),
//                                               if (_options[
//                                                       'collecte'] ==
//                                                   true)
//                                                 _chip("🏠",
//                                                     AppColors
//                                                         .primary),
//                                               if (_options[
//                                                       'livraison'] ==
//                                                   true)
//                                                 _chip("🚚",
//                                                     AppColors
//                                                         .primary),
//                                             ],
//                                           ),
//                                         ],
//                                       ),
//                                     )
//                                   else
//                                     Expanded(
//                                       child: Text(
//                                         "Appuyez pour configurer",
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 10,
//                                           color: AppColors
//                                               .textSecond,
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                           ),

//                           // ✅ CORRECTION — Ma zone → ParametresServiceScreen
//                           GestureDetector(
//                             onTap: () async {
//                               await Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) =>
//                                       ParametresServiceScreen( prestataireId:
//                                             widget.prestataireId, )));
//                               _loadData();
//                             },
//                             child: Container(
//                               padding:
//                                   const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(14),
//                                 border: Border.all(
//                                   color: _zoneConfig.isNotEmpty
//                                       ? AppColors.amber
//                                       : AppColors.border,
//                                   width: _zoneConfig.isNotEmpty
//                                       ? 1.5 : 0.5)),
//                               child: Column(
//                                 crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment
//                                             .spaceBetween,
//                                     children: [
//                                       Expanded(
//                                         child: Row(
//                                           children: [
//                                             Container(
//                                               width: 32,
//                                               height: 32,
//                                               decoration: BoxDecoration(
//                                                 color: AppColors
//                                                     .amberLight,
//                                                 borderRadius:
//                                                     BorderRadius
//                                                         .circular(
//                                                             10)),
//                                               child: const Icon(
//                                                 Icons
//                                                     .location_on_outlined,
//                                                 color:
//                                                     AppColors.amber,
//                                                 size: 18),
//                                             ),
//                                             const SizedBox(
//                                                 width: 6),
//                                             Text("Ma zone",
//                                               style:
//                                                   GoogleFonts
//                                                       .poppins(
//                                                 fontSize: 13,
//                                                 fontWeight:
//                                                     FontWeight.w600,
//                                                 color: AppColors
//                                                     .textPrimary,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Container(
//                                         padding:
//                                             const EdgeInsets
//                                                 .symmetric(
//                                                   horizontal: 8,
//                                                   vertical: 3),
//                                         decoration: BoxDecoration(
//                                           color:
//                                               _zoneConfig.isNotEmpty
//                                                   ? AppColors
//                                                       .amberLight
//                                                   : AppColors
//                                                       .background,
//                                           borderRadius:
//                                               BorderRadius
//                                                   .circular(20)),
//                                         child: Text(
//                                           _zoneConfig.isNotEmpty
//                                               ? "✅ OK"
//                                               : "⚠️ Vide",
//                                           style:
//                                               GoogleFonts.poppins(
//                                             fontSize: 9,
//                                             fontWeight:
//                                                 FontWeight.w500,
//                                             color: _zoneConfig
//                                                     .isNotEmpty
//                                                 ? AppColors.amber
//                                                 : AppColors
//                                                     .textMuted,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   if (_zoneConfig.isNotEmpty) ...[
//                                     const SizedBox(height: 8),
//                                     const Divider(height: 1),
//                                     const SizedBox(height: 8),
//                                     Expanded(
//                                       child:
//                                           SingleChildScrollView(
//                                         child: Row(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment
//                                                   .start,
//                                           children: [
//                                             const Icon(
//                                               Icons
//                                                   .location_on_rounded,
//                                               color:
//                                                   AppColors.amber,
//                                               size: 14),
//                                             const SizedBox(
//                                                 width: 4),
//                                             Expanded(
//                                               child: Text(
//                                                 _zoneConfig,
//                                                 style: GoogleFonts
//                                                     .poppins(
//                                                   fontSize: 11,
//                                                   color: AppColors
//                                                       .textPrimary,
//                                                   fontWeight:
//                                                       FontWeight
//                                                           .w500,
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                   ] else ...[
//                                     const SizedBox(height: 8),
//                                     Expanded(
//                                       child: Text(
//                                         "Définissez votre zone",
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 10,
//                                           color: AppColors
//                                               .textSecond,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ],
//                               ),
//                             ),
//                           ),

//                           // Commandes
//                           _buildActionCard(
//                             Icons.list_alt_outlined,
//                             "Commandes",
//                             "Gérer les demandes",
//                             AppColors.primary,
//                             AppColors.primaryLight,
//                             onTap: () =>
//                                 setState(() => _currentIndex = 1),
//                           ),

//                           // Mes avis
//                           _buildActionCard(
//                             Icons.star_outline,
//                             "Mes avis",
//                             "Évaluations clients",
//                             AppColors.purple,
//                             AppColors.purpleLight,
//                             onTap: () {},
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 16),

//                       // ── Dernières commandes ────────
//                       Text("Dernières commandes",
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                       const SizedBox(height: 8),

//                       _dernieresCommandes.isEmpty
//                           ? Container(
//                               padding:
//                                   const EdgeInsets.all(20),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius:
//                                     BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: AppColors.border,
//                                   width: 0.5)),
//                               child: Center(
//                                 child: Column(
//                                   children: [
//                                     const Icon(
//                                       Icons.inbox_outlined,
//                                       color: AppColors.textMuted,
//                                       size: 36),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       "Aucune commande pour l'instant",
//                                       style: GoogleFonts.poppins(
//                                         fontSize: 12,
//                                         color:
//                                             AppColors.textSecond,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             )
//                           : Column(
//                               children: _dernieresCommandes
//                                   .map((cmd) =>
//                                     _buildCommandeRecente(
//                                       cmd as Map<String, dynamic>))
//                                   .toList(),
//                             ),

//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//         ),
//       ],
//     );
//   }

//   // ── Stat card ──────────────────────────────────────
//   Widget _buildStatCard(
//     String count, String label,
//     Color color, Color bgColor,
//   ) {
//     return Container(
//       padding: const EdgeInsets.symmetric(
//           vertical: 14, horizontal: 8),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: color.withValues(alpha: 0.2)),
//       ),
//       child: Column(
//         children: [
//           Text(count,
//             style: GoogleFonts.poppins(
//               fontSize: 22,
//               fontWeight: FontWeight.w700,
//               color: color,
//             ),
//           ),
//           Text(label,
//             style: GoogleFonts.poppins(
//               fontSize: 10,
//               color: color,
//               fontWeight: FontWeight.w500,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Action card ────────────────────────────────────
//   Widget _buildActionCard(
//     IconData icon, String title, String desc,
//     Color color, Color bgColor, {
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//               color: AppColors.border, width: 0.5),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 38, height: 38,
//               decoration: BoxDecoration(
//                 color: bgColor,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, color: color, size: 20),
//             ),
//             const SizedBox(height: 8),
//             Text(title,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(desc,
//               style: GoogleFonts.poppins(
//                 fontSize: 10,
//                 color: AppColors.textSecond,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _chip(String emoji, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(
//           horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//             color: color.withValues(alpha: 0.3)),
//       ),
//       child: Text(emoji,
//           style: const TextStyle(fontSize: 10)),
//     );
//   }

//   // ── Commande récente (home) ────────────────────────
//   Widget _buildCommandeRecente(
//       Map<String, dynamic> cmd) {
//     final statut = cmd['statut'] as String? ?? '';
//     // Afficher étapeActuelle si disponible (étapes dynamiques), sinon statut
//     final etapeActuelle = cmd['etapeActuelle'] as String?
//         ?? cmd['etapeCourante'] as String?
//         ?? '';
//     final clefAffichage = etapeActuelle.isNotEmpty ? etapeActuelle : statut;
//     final config = _getEtatConfig(clefAffichage);

//     return GestureDetector(
//       onTap: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => CommandeDetailScreen(
//             commande:         cmd,
//             etapesEffectives: _etapesEffectives,
//             agents:           _agents,
//             prestataireId:    widget.prestataireId,
//           ),
//         ),
//       ).then((_) => _loadData()),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 8),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//               color: AppColors.border, width: 0.5)),
//         child: Row(
//           children: [
//             Container(
//               width: 42, height: 42,
//               decoration: BoxDecoration(
//                 color: config['bgColor'] as Color,
//                 borderRadius:
//                     BorderRadius.circular(10)),
//               child: Icon(
//                 config['icon'] as IconData,
//                 color: config['color'] as Color,
//                 size: 20),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment:
//                     CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     cmd['nomClient'] as String? ?? '',
//                     style: GoogleFonts.poppins(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       color: AppColors.textPrimary,
//                     ),
//                   ),
//                   Text(
//                     "${cmd['motDepot'] == 'COLLECTE_DOMICILE' ? 'Collecte' : 'Dépôt'}"
//                     " · ${cmd['dateCommande'] ?? ''}",
//                     style: GoogleFonts.poppins(
//                       fontSize: 11,
//                       color: AppColors.textSecond,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               crossAxisAlignment:
//                   CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   "${(cmd['montantTotal'] as num? ?? 0).toInt()} FCFA",
//                   style: GoogleFonts.poppins(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.green,
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 8, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: config['bgColor'] as Color,
//                     borderRadius:
//                         BorderRadius.circular(20)),
//                   child: Text(
//                     config['label'] as String,
//                     style: GoogleFonts.poppins(
//                       fontSize: 9,
//                       color: config['color'] as Color,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(width: 6),
//             const Icon(
//               Icons.chevron_right,
//               color: AppColors.textMuted,
//               size: 18),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Config état : statuts fixes du cycle de vie ──────
//   // Les étapes dynamiques (etapesEffectives) viennent de l'API
//   // et sont affichées via le fallback générique.
//   // Naboopay gère le paiement → pas de cas PAIEMENT_RECU ici.
//   Map<String, dynamic> _getEtatConfig(String clef) {
//     switch (clef) {

//       // ── Statuts fixes ─────────────────────────────────
//       case 'CREE':
//         return { 'label': 'Nouvelle',    'color': AppColors.primary,
//           'bgColor': AppColors.primaryLight, 'icon': Icons.fiber_new_outlined };
//       case 'CONFIRMEE':
//         return { 'label': 'Confirmée',   'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.check_circle_outline };
//       case 'TERMINEE':
//         return { 'label': 'Terminée',    'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.check_circle_outline };
//       case 'CLOTUREE':
//         return { 'label': 'Clôturée ✅', 'color': AppColors.green,
//           'bgColor': AppColors.greenLight,  'icon': Icons.lock_outline };
//       case 'ANNULEE':
//         return { 'label': 'Annulée',     'color': AppColors.red,
//           'bgColor': AppColors.redLight,    'icon': Icons.cancel_outlined };
//       case 'LITIGE':
//         return { 'label': 'Litige',      'color': AppColors.amber,
//           'bgColor': AppColors.amberLight,  'icon': Icons.warning_amber_outlined };

//       // ── Étape dynamique quelconque (API etapesEffectives) ─
//       // "EN_DEPOT", "EN_REPARATION", etc. → formaté automatiquement
//       default:
//         if (clef.isNotEmpty) {
//           final label = clef
//               .replaceAll('_', ' ')
//               .toLowerCase()
//               .replaceFirstMapped(
//                   RegExp(r'^.'), (m) => m[0]!.toUpperCase());
//           return { 'label': label,  'color': AppColors.primary,
//             'bgColor': AppColors.primaryLight,
//             'icon': Icons.pending_outlined };
//         }
//         return { 'label': '—', 'color': AppColors.textMuted,
//           'bgColor': AppColors.background, 'icon': Icons.help_outline };
//     }
//   }

//   // ══ PAGE PROFIL ══════════════════════════════════
//   Widget _buildProfil() {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         automaticallyImplyLeading: false,
//         title: Text("Mon profil",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             const SizedBox(height: 20),
//             Container(
//               width: 80, height: 80,
//               decoration: BoxDecoration(
//                 color: AppColors.greenLight,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: AppColors.green
//                       .withValues(alpha: 0.3),
//                   width: 2),
//               ),
//               child: Center(
//                 child: Text(_initiales,
//                   style: GoogleFonts.poppins(
//                     fontSize: 28,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.green,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(_nomCommercial,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(_zone,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: AppColors.textSecond,
//               ),
//             ),
//             const SizedBox(height: 24),
//             _buildProfilItem(Icons.person_outline,
//                 "Nom complet", '$_prenom $_nom'),
//             _buildProfilItem(Icons.email_outlined,
//                 "Email", _email),
//             _buildProfilItem(Icons.location_on_outlined,
//                 "Zone", _zone.isNotEmpty ? _zone : 'Non configurée'),
//             _buildProfilItem(Icons.work_outline,
//                 "Type de service",
//                 _typeService.isNotEmpty
//                     ? _typeService : 'Non configuré'),
//             const SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               // ✅ CORRECTION — AppColors.red (pas Colors.red)
//               child: OutlinedButton.icon(
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: AppColors.red,
//                   side: const BorderSide(color: AppColors.red),
//                   padding: const EdgeInsets.symmetric(
//                       vertical: 12),
//                 ),
//                 onPressed: _logout,
//                 icon: const Icon(Icons.logout),
//                 label: Text("Déconnexion",
//                   style: GoogleFonts.poppins(fontSize: 14)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProfilItem(
//       IconData icon, String label, String value) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//             color: AppColors.border, width: 0.5),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, color: AppColors.green, size: 20),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment:
//                 CrossAxisAlignment.start,
//             children: [
//               Text(label,
//                 style: GoogleFonts.poppins(
//                   fontSize: 11,
//                   color: AppColors.textSecond,
//                 ),
//               ),
//               Text(value,
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Dialog déconnexion ────────────────────────────
//   void _showLogoutDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16)),
//         title: Text("Déconnexion",
//           style: GoogleFonts.poppins(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         content: Text(
//           "Voulez-vous vraiment vous déconnecter ?",
//           style: GoogleFonts.poppins(fontSize: 13),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Annuler",
//               style: GoogleFonts.poppins(
//                   color: AppColors.textSecond)),
//           ),
//           // ✅ CORRECTION — AppColors.red
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.red,
//               foregroundColor: Colors.white,
//             ),
//             onPressed: () {
//               Navigator.pop(context);
//               _logout();
//             },
//             icon: const Icon(Icons.logout, size: 16),
//             label: Text("Déconnexion",
//               style: GoogleFonts.poppins(fontSize: 13)),
//           ),
//         ],
//       ),
//     );
//   }
// }

///#################################///////////






// // prestataire_home_screen.dart
// // Tableau de bord principal du prestataire.
// //
// // BUGS CORRIGÉS (3) :
// //   ✅ Bug 1 — "Pressing · Actif" hardcodé × 2 → remplacé par _labelService (getter dynamique)
// //   ✅ Bug 2 — Profil nav index toujours 3 → setState(() => _currentIndex = _avecAgent ? 3 : 2)
// //   ✅ Bug 3 — bool _avecAgent = true (défaut) → remplacé par false (valeur API)

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// // Imports du projet (adapter selon la structure réelle)
// // import '../../core/constants/app_colors.dart';
// // import '../../core/constants/api_constants.dart';
// // import '../../core/services/auth_storage.dart';
// // import 'prestataire_commandes_screen.dart';
// // import 'prestataire_statistiques_screen.dart';
// // import 'prestataire_agents_screen.dart';
// // import 'prestataire_config_screen.dart';
// // import 'parametres_screen.dart';

// class PrestataireHomeScreen extends StatefulWidget {
//   final int prestataireId;

//   const PrestataireHomeScreen({
//     super.key,
//     required this.prestataireId,
//   });

//   @override
//   State<PrestataireHomeScreen> createState() => _PrestataireHomeScreenState();
// }

// class _PrestataireHomeScreenState extends State<PrestataireHomeScreen> {
//   static const Color _teal = Color(0xFF0F766E);
//   static const Color _tealLight = Color(0xFFCCFBF1);
//   static const String _baseUrl = 'http://localhost:7090';

//   // ── BUG 3 CORRIGÉ : _avecAgent initialisé à false (valeur API) ───────────
//   bool _avecAgent = false;

//   Map<String, dynamic> _prestataire = {};
//   Map<String, dynamic> _config = {};
//   List<Map<String, dynamic>> _commandes = [];
//   bool _loading = true;
//   int _currentIndex = 0;
//   int _notifCount = 0;

//   // ── BUG 1 CORRIGÉ : getter dynamique au lieu de chaîne hardcodée ─────────
//   /// Renvoie ex: "Pressing", "Réparation", "Soins" selon la config API
//   String get _labelService =>
//       _config['typeServiceNom'] as String? ??
//       _prestataire['typeServiceNom'] as String? ??
//       'Service';

//   /// "Actif" ou "Inactif" selon le statut du prestataire
//   String get _labelStatut =>
//       (_prestataire['actif'] as bool? ?? true) ? 'Actif' : 'Inactif';

//   // Statistiques rapides
//   int get _enAttente => _commandes.where((c) => c['statut'] == 'CREE').length;
//   int get _enCours => _commandes.where((c) {
//         final s = c['statut'] as String? ?? '';
//         return s != 'CREE' && s != 'CLOTUREE' && s != 'ANNULEE';
//       }).length;
//   int get _terminees =>
//       _commandes.where((c) => c['statut'] == 'CLOTUREE').length;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => _loading = true);
//     await Future.wait([
//       _loadPrestataire(),
//       _loadConfig(),
//       _loadCommandes(),
//     ]);
//     setState(() => _loading = false);
//   }

//   Future<void> _loadPrestataire() async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         setState(() =>
//             _prestataire = jsonDecode(res.body) as Map<String, dynamic>);
//       }
//     } catch (_) {
//       _prestataire = _demoPrestataire();
//     }
//   }

//   Future<void> _loadConfig() async {
//     try {
//       final res = await http.get(
//         Uri.parse('$_baseUrl/api/prestataire/config/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         final config = jsonDecode(res.body) as Map<String, dynamic>;
//         setState(() {
//           _config = config;
//           // ── BUG 3 CORRIGÉ : avecAgent vient de l'API ─────────────────
//           _avecAgent = config['avecAgent'] as bool? ?? false;
//         });
//       }
//     } catch (_) {
//       _config = _demoConfig();
//       _avecAgent = false; // valeur par défaut sûre
//     }
//   }

//   Future<void> _loadCommandes() async {
//     try {
//       final res = await http.get(
//         Uri.parse(
//             '$_baseUrl/api/commandes/prestataire/${widget.prestataireId}'),
//       );
//       if (res.statusCode == 200) {
//         final list = jsonDecode(res.body) as List;
//         setState(() {
//           _commandes = list.cast<Map<String, dynamic>>();
//           _notifCount =
//               _commandes.where((c) => c['statut'] == 'CREE').length;
//         });
//       }
//     } catch (_) {
//       _commandes = _demoCommandes();
//       _notifCount = _commandes.where((c) => c['statut'] == 'CREE').length;
//     }
//   }

//   Map<String, dynamic> _demoPrestataire() => {
//     'id': widget.prestataireId,
//     'nom': 'Express Laverie Pro',
//     'typeServiceNom': 'Pressing',
//     'actif': true,
//     'adresse': 'Quartier Liberté, Dakar',
//     'telephone': '+221 77 123 45 67',
//   };

//   Map<String, dynamic> _demoConfig() => {
//     'typeServiceNom': 'Pressing',
//     'avecAgent': false,
//     'etapesEffectives': [
//       'CREE', 'CONFIRMEE', 'EN_COLLECTE', 'EN_TRAITEMENT', 'EN_LIVRAISON', 'CLOTUREE'
//     ],
//   };

//   List<Map<String, dynamic>> _demoCommandes() => [
//     {'id': 1, 'statut': 'CREE', 'clientNom': 'Fatou Diallo', 'totalEstime': 3100},
//     {'id': 2, 'statut': 'EN_TRAITEMENT', 'clientNom': 'Ibrahima Sow', 'totalEstime': 5500},
//     {'id': 3, 'statut': 'CLOTUREE', 'clientNom': 'Mariama Ba', 'totalEstime': 2000},
//   ];

//   // ── Navigation items dynamique selon _avecAgent ───────────────────────────
//   List<BottomNavigationBarItem> get _navItems => [
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.home_rounded),
//       label: 'Accueil',
//     ),
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.receipt_long_rounded),
//       label: 'Commandes',
//     ),
//     // Agents seulement si avecAgent = true
//     if (_avecAgent)
//       const BottomNavigationBarItem(
//         icon: Icon(Icons.people_rounded),
//         label: 'Agents',
//       ),
//     const BottomNavigationBarItem(
//       icon: Icon(Icons.person_rounded),
//       label: 'Profil',
//     ),
//   ];

//   void _onNavTap(int idx) => setState(() => _currentIndex = idx);

//   Widget _buildScreen(int idx) {
//     if (idx == 0) return _buildAccueil();
//     if (idx == 1) return _buildCommandesPlaceholder();
//     if (idx == 2 && _avecAgent) return _buildAgentsPlaceholder();
//     // ── BUG 2 CORRIGÉ : index profil = _avecAgent ? 3 : 2 ────────────────
//     final profilIdx = _avecAgent ? 3 : 2;
//     if (idx == profilIdx) return _buildProfilPlaceholder();
//     return _buildAccueil();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: _buildAppBar(),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _buildScreen(_currentIndex),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: _onNavTap,
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: _teal,
//         unselectedItemColor: const Color(0xFF94A3B8),
//         selectedLabelStyle: const TextStyle(
//           fontWeight: FontWeight.w700,
//           fontSize: 11,
//         ),
//         unselectedLabelStyle: const TextStyle(fontSize: 11),
//         elevation: 16,
//         items: _navItems,
//       ),
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: _teal,
//       foregroundColor: Colors.white,
//       elevation: 0,
//       title: const Text(
//         'ServiProx',
//         style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
//       ),
//       actions: [
//         // Cloche notification avec badge
//         Stack(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.notifications_outlined),
//               onPressed: () => setState(() => _currentIndex = 1),
//               tooltip: 'Nouvelles commandes',
//             ),
//             if (_notifCount > 0)
//               Positioned(
//                 top: 8,
//                 right: 8,
//                 child: Container(
//                   width: 18,
//                   height: 18,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFEF4444),
//                     shape: BoxShape.circle,
//                     border: Border.all(color: _teal, width: 2),
//                   ),
//                   child: Center(
//                     child: Text(
//                       '$_notifCount',
//                       style: const TextStyle(
//                         fontSize: 9,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         IconButton(
//           icon: const Icon(Icons.settings_outlined),
//           onPressed: () {
//             Navigator.pushNamed(context, '/parametres');
//           },
//           tooltip: 'Paramètres',
//         ),
//       ],
//     );
//   }

//   // ── ACCUEIL ───────────────────────────────────────────────────────────────
//   Widget _buildAccueil() {
//     final nomPrestataire = _prestataire['nom'] as String? ?? 'Mon établissement';

//     return RefreshIndicator(
//       color: _teal,
//       onRefresh: _loadData,
//       child: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Carte identité prestataire ──────────────────────────────
//             _buildCartePrestataire(nomPrestataire),

//             const SizedBox(height: 16),

//             // ── Stats rapides ────────────────────────────────────────────
//             _buildStatsRapides(),

//             const SizedBox(height: 24),

//             // ── Raccourcis ────────────────────────────────────────────────
//             const Text(
//               'Accès rapide',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             const SizedBox(height: 12),
//             _buildRaccourcis(),

//             const SizedBox(height: 24),

//             // ── Dernières commandes ───────────────────────────────────────
//             Row(
//               children: [
//                 const Text(
//                   'Commandes récentes',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 const Spacer(),
//                 TextButton(
//                   onPressed: () => setState(() => _currentIndex = 1),
//                   child: const Text('Tout voir →'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             ..._commandes.take(3).map(_buildCommandeCard),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCartePrestataire(String nom) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [_teal, _teal.withValues(alpha: 0.8)],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: _teal.withValues(alpha: 0.3),
//             blurRadius: 16,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 56,
//                 height: 56,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Center(
//                   child: Text(
//                     nom.isNotEmpty ? nom[0].toUpperCase() : '?',
//                     style: const TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       nom,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w800,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     // ── BUG 1 CORRIGÉ : _labelService + _labelStatut ────────
//                     Text(
//                       '$_labelService · $_labelStatut',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.white.withValues(alpha: 0.8),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 10, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 7,
//                       height: 7,
//                       decoration: const BoxDecoration(
//                         color: Color(0xFF4ADE80),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 5),
//                     const Text(
//                       'En ligne',
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           // ── BUG 1 CORRIGÉ : label dynamique ────────────────────────────
//           Text(
//             '$_labelService · Tableau de bord',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.white.withValues(alpha: 0.6),
//               letterSpacing: 0.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatsRapides() {
//     return Row(
//       children: [
//         _buildStatBadge(
//           label: 'En attente',
//           count: _enAttente,
//           color: const Color(0xFFF59E0B),
//           bg: const Color(0xFFFEF3C7),
//           icon: '⏳',
//         ),
//         const SizedBox(width: 10),
//         _buildStatBadge(
//           label: 'En cours',
//           count: _enCours,
//           color: const Color(0xFF3B82F6),
//           bg: const Color(0xFFEFF6FF),
//           icon: '⚙️',
//         ),
//         const SizedBox(width: 10),
//         _buildStatBadge(
//           label: 'Terminées',
//           count: _terminees,
//           color: const Color(0xFF16A34A),
//           bg: const Color(0xFFDCFCE7),
//           icon: '✅',
//         ),
//       ],
//     );
//   }

//   Widget _buildStatBadge({
//     required String label,
//     required int count,
//     required Color color,
//     required Color bg,
//     required String icon,
//   }) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.05),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
//               child: Center(
//                 child: Text(icon, style: const TextStyle(fontSize: 16)),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w900,
//                 color: color,
//               ),
//             ),
//             Text(
//               label,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 11,
//                 color: Color(0xFF64748B),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRaccourcis() {
//     final items = [
//       {
//         'icon': Icons.receipt_long_rounded,
//         'label': 'Commandes',
//         'nav': 1,
//       },
//       {
//         'icon': Icons.bar_chart_rounded,
//         'label': 'Statistiques',
//         'route': '/prestataire/statistiques',
//       },
//       {
//         'icon': Icons.settings_rounded,
//         'label': 'Configuration',
//         'route': '/prestataire/config',
//       },
//       if (_avecAgent)
//         {
//           'icon': Icons.people_rounded,
//           'label': 'Agents',
//           'nav': 2,
//         },
//     ];

//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3,
//         crossAxisSpacing: 10,
//         mainAxisSpacing: 10,
//         childAspectRatio: 1.1,
//       ),
//       itemCount: items.length,
//       itemBuilder: (context, i) {
//         final item = items[i];
//         return GestureDetector(
//           onTap: () {
//             if (item.containsKey('nav')) {
//               setState(() => _currentIndex = item['nav'] as int);
//             } else if (item.containsKey('route')) {
//               Navigator.pushNamed(context, item['route'] as String);
//             }
//           },
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(14),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withValues(alpha: 0.05),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(item['icon'] as IconData, size: 28, color: _teal),
//                 const SizedBox(height: 6),
//                 Text(
//                   item['label'] as String,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildCommandeCard(Map<String, dynamic> c) {
//     final statut = c['statut'] as String? ?? '';
//     final client = c['clientNom'] as String? ?? 'Client';
//     final total = c['totalEstime'] as int? ?? 0;

//     const labels = {
//       'CREE': 'En attente',
//       'CONFIRMEE': 'Confirmée',
//       'EN_COLLECTE': 'En collecte',
//       'EN_TRAITEMENT': 'En traitement',
//       'EN_LIVRAISON': 'En livraison',
//       'CLOTUREE': 'Clôturée',
//       'ANNULEE': 'Annulée',
//     };
//     const colors = {
//       'CREE': Color(0xFFF59E0B),
//       'CONFIRMEE': Color(0xFF3B82F6),
//       'EN_COLLECTE': Color(0xFF8B5CF6),
//       'EN_TRAITEMENT': Color(0xFFF97316),
//       'EN_LIVRAISON': Color(0xFF06B6D4),
//       'CLOTUREE': Color(0xFF16A34A),
//       'ANNULEE': Color(0xFFDC2626),
//     };

//     final statColor = colors[statut] ?? const Color(0xFF94A3B8);
//     final statLabel = labels[statut] ?? statut;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 10,
//             height: 10,
//             decoration: BoxDecoration(
//               color: statColor,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   client,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 Text(
//                   statLabel,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: statColor,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Text(
//             '$total FCFA',
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── PLACEHOLDER SCREENS (naviguer vers les vraies classes) ────────────────
//   Widget _buildCommandesPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer PrestataireCommandesScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }

//   Widget _buildAgentsPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer PrestataireAgentsScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }

//   Widget _buildProfilPlaceholder() {
//     return const Center(
//       child: Text(
//         'Insérer ProfilScreen ici',
//         style: TextStyle(color: Color(0xFF94A3B8)),
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:memoireserviprox/features/prestataire/CommandeDetailScreen.dart';
// import 'package:memoireserviprox/features/prestataire/PrestataireConfigScreen.dart';
// import 'package:memoireserviprox/features/prestataire/parametres_screen.dart';
// import 'package:memoireserviprox/features/prestataire/prestataire_agents_screen.dart';
// import 'package:memoireserviprox/features/prestataire/prestataire_commandes_screen.dart';
// import 'package:memoireserviprox/features/prestataire/prestataire_statistiques_screen.dart';
// import 'dart:convert';
// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';

// import '../auth/login_screen.dart';

// class PrestataireHomeScreen extends StatefulWidget {
//   const PrestataireHomeScreen({super.key});

//   @override
//   State<PrestataireHomeScreen> createState() =>
//       _PrestataireHomeScreenState();
// }

// class _PrestataireHomeScreenState
//     extends State<PrestataireHomeScreen> {

//   // ── Variables d'état ──────────────────────────────
//   int _currentIndex = 0;
//   String _nomCommercial = '';
//   String _prenom = '';
//   String _nom = '';
//   String _email = '';
//   String _zone = '';
//   int _countCommandes = 0;
//   int _countEnCours = 0;
//   int _countAgents = 0;
//   bool _isLoading = true;
//   int? _prestataireId;
//   String _typeService = '';  // ← AJOUT
//   bool _avecAgent = true; // ← AJOUT

//   // Variables config récapitulatif
//   bool _configExiste = false;
//   //Map<String, dynamic> _tarifs = {};
//   Map<String, dynamic> _options = {};
//   List<Map<String, dynamic>> _prestationsConfig = [];
//   // ← AJOUT en haut de la classe
//   List<dynamic> _dernieresCommandes = [];
//   String _zoneConfig = '';

//   // ── Initiales ─────────────────────────────────────
//   String get _initiales {
//     return _nomCommercial
//       .trim()
//       .split(' ')
//       .where((w) => w.isNotEmpty)
//       .take(2)
//       .map((w) => w[0].toUpperCase())
//       .join();
//   }

//   String get _labelService {
//   switch (_typeService.toLowerCase()) {
//     case 'pressing':   return 'Pressing · Actif';
//     case 'reparation': return 'Réparation · Actif';
//     case 'domicile':   return 'Domicile · Actif';
//     default: return _typeService.isNotEmpty
//       ? '$_typeService · Actif' : 'En activité';
//   }
// }


//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }


//   // ── Charger données ───────────────────────────────
// //   
//   Future<void> _loadData() async {
//   final prenom = await AuthStorage.getPrenom();
//   final nom    = await AuthStorage.getNom();
//   final email  = await AuthStorage.getEmail();
//   final zone   = await AuthStorage.getAdresse();
//   final userId = await AuthStorage.getUserId();
//   final token  = await AuthStorage.getToken();

//   // ← Charger config + compteurs en parallèle
//   await Future.wait([
//     _loadConfig(userId, token),
//     _loadCompteurs(userId, token),
//   ]);

//   if (mounted) {
//     setState(() {
//       _prenom        = prenom;
//       _nom           = nom;
//       _email         = email;
//       _prestataireId = userId;
//       _nomCommercial =
//         prenom.isNotEmpty
//           ? '$prenom $nom' : nom;
//       _isLoading = false;
//     });
//   }
// }

// // ── Charger config prestataire ────────────────────
// Future<void> _loadConfig(
//     int? userId, String? token) async {
//   try {
//     final configResp = await http.get(
//       Uri.parse(
//         '${ApiConstants.baseUrl}/prestataire'
//         '/config/$userId'),
//       headers: {
//         'Authorization': 'Bearer $token'},
//     );

//     if (configResp.statusCode == 200) {
//       final data = jsonDecode(configResp.body);

//       // Parser les tarifs
//       Map<String, dynamic> tarifs = {};
//       if (data['tarifsPersonnalises'] != null) {
//         tarifs = jsonDecode(
//           data['tarifsPersonnalises']);
//       }

//       // Parser les options
//       Map<String, dynamic> options = {};
//       if (data['optionsActives'] != null) {
//         options = jsonDecode(
//           data['optionsActives']);
//       }

//       // Parser les prestations
//       List<Map<String, dynamic>> prestations = [];
//           if (data['prestationsAjoutees'] != null) {
//             final raw = jsonDecode(
//               data['prestationsAjoutees']) as List;
//             for (final item in raw) {
//               if (item is Map) {
//                 // ← Nouveau format JSON
//                 prestations.add({
//                   'nom':   item['nom']?.toString() ?? '',
//                   'prix':  item['prix'] ?? 0,
//                   'unite': item['unite']?.toString()
//                           ?? 'pièce',
//                 });
//               } else {
//                 // ← Ancien format "nom:prix"
//                 final parts = item.toString().split(':');
//                 prestations.add({
//                   'nom':   parts[0].trim(),
//                   'prix':  double.tryParse(
//                     parts.length > 1
//                       ? parts[1].trim() : '0') ?? 0,
//                   'unite': 'pièce',
//                 });
//               }
//             }
//           }
//           // ← AJOUT : charger aussi tarifsPersonnalises
//           // (si prestationsAjoutees vide)
//           if (prestations.isEmpty &&
//               data['tarifsPersonnalises'] != null) {
//             final tarifs = jsonDecode(
//               data['tarifsPersonnalises'])
//               as Map<String, dynamic>;
//             for (final entry in tarifs.entries) {
//               prestations.add({
//                 'nom':   entry.key,
//                 'prix':  entry.value ?? 0,
//                 'unite': 'pièce',
//               });
//             }
//           }

//       if (mounted) {
//         setState(() {
//           _configExiste      = true;
//           //_tarifs            = tarifs;
//           _options           = options;
//           _prestationsConfig = prestations;
//           _zoneConfig =
//             data['zoneCouverture'] ?? '';
//           _zone = _zoneConfig;
//           _typeService       = data['typeService'] ?? '';          // ← déjà prévu
//           _avecAgent         = data['avecAgent'] as bool? ??       // ← AJOUT
//       (data['service'] as Map<String, dynamic>?)?['avecAgent'] as bool? ?? true;
//         });
//       }
//     }
//   } catch (e) {
//     debugPrint("Erreur config: $e");
//   }
// }

// // ── Charger compteurs dynamiques ──────────────────
// Future<void> _loadCompteurs(
//     int? userId, String? token) async {
//   try {

//     // 1. ← Compteur commandes
//     final cmdResp = await http.get(
//       Uri.parse(
//         '${ApiConstants.commandes}'
//         '/prestataire/$userId'),
//       headers: {
//         'Authorization': 'Bearer $token'},
//     );

//     if (cmdResp.statusCode == 200) {
//       final List<dynamic> commandes =
//           jsonDecode(cmdResp.body);

//       // ← Compter par statut
//       final enCours = commandes.where((c) =>
//         c['statut'] == 'CREE' ||
//         c['statut'] == 'CONFIRMEE' ||
//         c['statut'] == 'EN_TRAITEMENT'
//       ).length;

//       if (mounted) {
//         setState(() {
//           _countCommandes = commandes.length;
//           _countEnCours   = enCours;
//         });
//       }
//     }

//     // 2. ← Compteur agents actifs
//     final agentResp = await http.get(
//       Uri.parse(
//         '${ApiConstants.baseUrl}/agent'
//         '/prestataire/$userId'),
//       headers: {
//         'Authorization': 'Bearer $token'},
//     );

//     if (agentResp.statusCode == 200) {
//       final List<dynamic> agents =
//           jsonDecode(agentResp.body);

//       if (mounted) {
//         setState(() {
//           _countAgents = agents
//             .where((a) =>
//               a['statut'] == 'ACTIF')
//             .length;
//         });
//       }
//     }

//   } catch (e) {
//     debugPrint("Erreur compteurs: $e");
//   }
// }

//   // ── Déconnexion ───────────────────────────────────
//   Future<void> _logout() async {
//     await AuthStorage.logout();
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const LoginScreen()),
//         (route) => false,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       drawer: _buildDrawer(),
//       body: IndexedStack(
//         index: _currentIndex,
//         children: [
//           _buildAccueil(),
//           const PrestataireCommandesScreen(),
//           if(_avecAgent)   const PrestataireAgentsScreen(), 
//           _buildProfil(),
//         ],
//       ),
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _currentIndex,
//         onDestinationSelected: (i) =>
//             setState(() => _currentIndex = i),
            
//         backgroundColor: Colors.white,
//         indicatorColor: AppColors.greenLight,
//         destinations:  [
//           NavigationDestination(
//             icon: Icon(Icons.home_outlined),
//             selectedIcon: Icon(
//               Icons.home, color: AppColors.green),
//             label: 'Accueil',
//           ),
//           NavigationDestination(
//             icon: Icon(Icons.list_alt_outlined),
//             selectedIcon: Icon(
//               Icons.list_alt, color: AppColors.green),
//             label: 'Commandes',
//           ),

//            if (_avecAgent) 

//           NavigationDestination(
//             icon: Icon(Icons.people_outline),
//             selectedIcon: Icon(
//               Icons.people, color: AppColors.green),
//             label: 'Agents',
//           ),
//           NavigationDestination(
//             icon: Icon(Icons.person_outline),
//             selectedIcon: Icon(
//               Icons.person, color: AppColors.green),
//             label: 'Profil',
//           ),
//         ],
//       ),
//     );
//   }

//   // 
//   Widget _buildDrawer() {
//   return Drawer(
//     backgroundColor: Colors.white,
//     child: Column(
//       children: [

//         // ── Header vert ───────────────────────────
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.fromLTRB(
//             20, 50, 20, 24),
//           color: AppColors.green,
//           child: Row(
//             children: [
//               Container(
//                 width: 56, height: 56,
//                 decoration: BoxDecoration(
//                   color: Colors.white
//                     .withValues(alpha: 0.2),
//                   borderRadius:
//                     BorderRadius.circular(16),
//                 ),
//                 child: Center(
//                   child: Text(_initiales,
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 20,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 14),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment:
//                     CrossAxisAlignment.start,
//                   children: [
//                     Text(_nomCommercial,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(_email,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white70,
//                         fontSize: 11,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 4),
//                     Container(
//                       padding:
//                         const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.white
//                           .withValues(alpha: 0.2),
//                         borderRadius:
//                           BorderRadius.circular(20),
//                       ),
//                       child: Text(
//                         "Pressing · Actif",
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         // ── Items du menu ─────────────────────────
//         Expanded(
//           child: ListView(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 16, vertical: 12),
//             children: [

//               // Mon profil
//               _drawerItem(
//                 icon: Icons.person_outline,
//                 label: "Mon profil",
//                 onTap: () {
//                   Navigator.pop(context);
//                   setState(() => _currentIndex = 3);
//                 }),

//               // Mes commandes
//               _drawerItem(
//                 icon: Icons.list_alt_outlined,
//                 label: "Mes commandes",
//                 badge: _countCommandes > 0
//                   ? '$_countCommandes' : null,
//                 onTap: () {
//                   Navigator.pop(context);
//                   setState(() => _currentIndex = 1);
//                 }),

//               // Configurer mon service
//               _drawerItem(
//                 icon: Icons.settings_outlined,
//                 label: "Configurer mon service",
//                 onTap: () async {
//                   Navigator.pop(context);
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) =>
//                         const PrestataireConfigScreen()),
//                   );
//                     // ← Recharger config au retour !
//                        _loadData();
                  
//                 }),

//               // Statistiques
//               _drawerItem(
//                 icon: Icons.bar_chart_outlined,
//                 label: "Statistiques",
//                 onTap: () {
//                   Navigator.pop(context);
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) =>
//                         const PrestataireStatistiquesScreen()));
//                 }),

//               // Paramètres
//               _drawerItem(
//                 icon: Icons.tune_outlined,
//                 label: "Mes paramètres",
//                 onTap: () {
//                   Navigator.pop(context);
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) =>
//                         const ParametresScreen()));
//                 }),

//               // Aide & Support
//               _drawerItem(
//                 icon: Icons.headset_mic_outlined,
//                 label: "Aide & Support",
//                 onTap: () => Navigator.pop(context)),

//               const SizedBox(height: 8),
//               const Divider(height: 1),
//               const SizedBox(height: 8),

//               // ← Déconnexion en rouge
//               _drawerItem(
//                 icon: Icons.logout,
//                 label: "Se déconnecter",
//                 isLogout: true,
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showLogoutDialog();
//                 }),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }

// // ── Item drawer style épuré ───────────────────────
// Widget _drawerItem({
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
//   bool isLogout = false,
//   String? badge,
// }) {
//   final Color iconColor = isLogout
//     ? Colors.red : AppColors.green;
//   final Color iconBg = isLogout
//     ? const Color(0xFFFCEBEB)
//     : AppColors.greenLight;
//   final Color textColor = isLogout
//     ? Colors.red : AppColors.textPrimary;

//   return Container(
//     margin: const EdgeInsets.only(bottom: 4),
//     child: ListTile(
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: 8, vertical: 2),
//       leading: Container(
//         width: 42, height: 42,
//         decoration: BoxDecoration(
//           color: iconBg,
//           shape: BoxShape.circle,
//         ),
//         child: Icon(icon,
//           color: iconColor, size: 20),
//       ),
//       title: Text(label,
//         style: GoogleFonts.poppins(
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//           color: textColor,
//         ),
//       ),
//       trailing: badge != null
//         // Badge commandes
//         ? Container(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 8, vertical: 2),
//             decoration: BoxDecoration(
//               color: AppColors.green,
//               borderRadius:
//                 BorderRadius.circular(20)),
//             child: Text(badge,
//               style: GoogleFonts.poppins(
//                 fontSize: 11,
//                 color: Colors.white,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           )
//         // Flèche →
//         : Icon(
//             Icons.arrow_forward_ios_rounded,
//             size: 14,
//             color: isLogout
//               ? Colors.red
//               : AppColors.textMuted),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12)),
//       onTap: onTap,
//     ),
//   );
// }



//   // ── Helper : unité selon le service ───────────────
//         String _getUnite(String nom) {
//           final n = nom.toLowerCase();
//           if (n.contains('kilo') || n.contains('kg')) {
//             return '/ kg';
//           }
//           return '/ pièce';
//         }      

//   // ══ PAGE ACCUEIL ══════════════════════════════════
//  Widget _buildAccueil() {
//   return Column(
//     children: [

//       // ── Header vert ──────────────────────────────
//       Container(
//         color: AppColors.green,
//         child: SafeArea(
//           bottom: false,
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(
//               16, 8, 16, 20),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment:
//                     MainAxisAlignment.spaceBetween,
//                   children: [
//                     Builder(
//                       builder: (ctx) => GestureDetector(
//                         onTap: () =>
//                           Scaffold.of(ctx).openDrawer(),
//                         child: Container(
//                           width: 34, height: 34,
//                           decoration: BoxDecoration(
//                             color: Colors.white
//                               .withValues(alpha: 0.15),
//                             borderRadius:
//                               BorderRadius.circular(10)),
//                           child: const Icon(
//                             Icons.menu,
//                             color: Colors.white,
//                             size: 20),
//                         ),
//                       ),
//                     ),
//                     Stack(
//                       children: [
//                         Container(
//                           width: 34, height: 34,
//                           decoration: BoxDecoration(
//                             color: Colors.white
//                               .withValues(alpha: 0.15),
//                             borderRadius:
//                               BorderRadius.circular(10)),
//                           child: const Icon(
//                             Icons.notifications_outlined,
//                             color: Colors.white,
//                             size: 20),
//                         ),
//                         Positioned(
//                           top: 6, right: 6,
//                           child: Container(
//                             width: 8, height: 8,
//                             decoration: BoxDecoration(
//                               color: Colors.red,
//                               shape: BoxShape.circle,
//                               border: Border.all(
//                                 color: AppColors.green,
//                                 width: 1.5)),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 16),

//                 // Infos prestataire
//                 Row(
//                   children: [
//                     Container(
//                       width: 50, height: 50,
//                       decoration: BoxDecoration(
//                         color: Colors.white
//                           .withValues(alpha: 0.2),
//                         borderRadius:
//                           BorderRadius.circular(14)),
//                       child: Center(
//                         child: Text(_initiales,
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 18,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Column(
//                       crossAxisAlignment:
//                         CrossAxisAlignment.start,
//                       children: [
//                         Text(_nomCommercial,
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 17,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         Row(
//                           children: [
//                             const Icon(
//                               Icons.location_on_outlined,
//                               color: Colors.white70,
//                               size: 13),
//                             const SizedBox(width: 4),
//                             Text(
//                               _zone.isNotEmpty
//                                 ? _zone
//                                 : 'Zone non configurée',
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white70,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ],
//                         ),
//                         Container(
//                           margin: const EdgeInsets
//                             .only(top: 4),
//                           padding:
//                             const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 2),
//                           decoration: BoxDecoration(
//                             color: Colors.white
//                               .withValues(alpha: 0.2),
//                             borderRadius:
//                               BorderRadius.circular(20)),
//                           child: Text(
//                             "Pressing · Actif",
//                             style: GoogleFonts.poppins(
//                               color: Colors.white,
//                               fontSize: 10,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),

//       // ── Body ─────────────────────────────────────
//       Expanded(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(14),
//           child: Column(
//             crossAxisAlignment:
//               CrossAxisAlignment.start,
//             children: [

//               // ── Compteurs ──────────────────────
//               Row(
//                 children: [
//                   Expanded(child: _buildStatCard('$_countCommandes','Commandes', AppColors.green, AppColors.greenLight,)),
//                   const SizedBox(width: 8),
//                   Expanded(child: _buildStatCard('$_countEnCours','En cours',AppColors.amber, AppColors.amberLight, )),
//                   if (_avecAgent) ...[
//                     const SizedBox(width: 8),
//                     Expanded(child: _buildStatCard( '$_countAgents', 'Agents', AppColors.primary, AppColors.primaryLight )),
//                   ],
//                 ],
//               ),

//               const SizedBox(height: 16),

//               // ── Bannière si pas configuré ───────
//               if (!_configExiste)
//                 GestureDetector(
//                   onTap: () async {
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                           const PrestataireConfigScreen()));
//                     _loadData();
//                   },
//                   child: Container(
//                     margin: const EdgeInsets
//                       .only(bottom: 16),
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: AppColors.amberLight,
//                       borderRadius:
//                         BorderRadius.circular(12),
//                       border: Border.all(
//                         color: AppColors.amber
//                           .withValues(alpha: 0.3))),
//                     child: Row(
//                       children: [
//                         const Icon(
//                           Icons.settings_outlined,
//                           color: AppColors.amber,
//                           size: 20),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Configurez votre service",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                   color: AppColors.amber,
//                                 ),
//                               ),
//                               Text(
//                                 "Ajoutez vos tarifs pour "
//                                 "être visible par les clients",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 11,
//                                   color: AppColors.amber,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const Icon(
//                           Icons.arrow_forward_ios,
//                           color: AppColors.amber,
//                           size: 14),
//                       ],
//                     ),
//                   ),
//                 ),

//               const SizedBox(height: 16),

//               // ── Actions ────────────────────────
//               Text("Mes actions",
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//               const SizedBox(height: 10),

//               GridView.count(
//                 crossAxisCount: 2,
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 10,
//                 // ← AJUSTER : plus petit = plus haut
//                 childAspectRatio: 0.85,
//                 children: [

//                   // ── Mon service ───────────────
//                   // 
//                   GestureDetector(
//                     onTap: () async {
//                       await Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) =>
//                             const PrestataireConfigScreen()));
//                       _loadData();
//                     },
//                     child: Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(14),
//                         border: Border.all(
//                           color: _configExiste
//                             ? AppColors.green
//                             : AppColors.border,
//                           width: _configExiste ? 1.5 : 0.5)),
//                       child: Column(
//                         crossAxisAlignment:
//                           CrossAxisAlignment.start,
//                         children: [

//                           // Header
//                           Row(
//                             mainAxisAlignment:
//                               MainAxisAlignment.spaceBetween,
//                             children: [
//                               Container(
//                                 width: 32, height: 32,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.greenLight,
//                                   borderRadius:
//                                     BorderRadius.circular(8)),
//                                 child: const Icon(
//                                   Icons.settings_outlined,
//                                   color: AppColors.green,
//                                   size: 16),
//                               ),
//                               Container(
//                                 padding:
//                                   const EdgeInsets.symmetric(
//                                     horizontal: 6, vertical: 2),
//                                 decoration: BoxDecoration(
//                                   color: _configExiste
//                                     ? AppColors.greenLight
//                                     : AppColors.amberLight,
//                                   borderRadius:
//                                     BorderRadius.circular(20)),
//                                 child: Text(
//                                   _configExiste
//                                     ? "✅ OK"
//                                     : "⚠️",
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 9,
//                                     fontWeight: FontWeight.w500,
//                                     color: _configExiste
//                                       ? AppColors.green
//                                       : AppColors.amber,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),

//                           const SizedBox(height: 6),

//                           Text("Mon service",
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                               color: AppColors.textPrimary,
//                             ),
//                           ),

//                           const SizedBox(height: 6),
//                           const Divider(height: 1),
//                           const SizedBox(height: 6),

//                           // ← Prestations en chips
//                           if (_configExiste &&
//                               _prestationsConfig.isNotEmpty)
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                   children: [

//                                     // ← Chips scrollables verticalement
//                                     Expanded(
//                                       child: SingleChildScrollView(
//                                         child: Wrap(
//                                           spacing: 4,
//                                           runSpacing: 4,
//                                           children: _prestationsConfig
//                                             .map((presta) =>
//                                               Container(
//                                                 padding:
//                                                   const EdgeInsets
//                                                     .symmetric(
//                                                       horizontal: 6,
//                                                       vertical: 2),
//                                                 decoration: BoxDecoration(
//                                                   color: AppColors
//                                                     .greenLight,
//                                                   borderRadius:
//                                                     BorderRadius
//                                                       .circular(20),
//                                                 ),
//                                                 child: Text(
//                                                   "${presta['nom']}"
//                                                   " · ${(presta['prix']
//                                                     as num).toInt()}F",
//                                                   style:
//                                                     GoogleFonts.poppins(
//                                                       fontSize: 9,
//                                                       color:
//                                                         AppColors.green,
//                                                       fontWeight:
//                                                         FontWeight.w500,
//                                                     ),
//                                                 ),
//                                               ),
//                                             ).toList(),
//                                         ),
//                                       ),
//                                     ),

//                                     // ← Options en bas (hors scroll)
//                                     const SizedBox(height: 4),
//                                     Wrap(
//                                       spacing: 3,
//                                       runSpacing: 3,
//                                       children: [
//                                         if (_options['express'] == true)
//                                           _chip("⚡", AppColors.amber),
//                                         if (_options['collecte'] == true)
//                                           _chip("🏠", AppColors.primary),
//                                         if (_options['livraison'] == true)
//                                           _chip("🚚", AppColors.primary),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               )
//                           else
//                             Expanded(
//                               child: Text(
//                                 "Appuyez pour configurer",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 10,
//                                   color: AppColors.textSecond,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),


//                 // GridView.count(
//                 // crossAxisCount: 2,
//                 // shrinkWrap: true,
//                 // physics:
//                 //   const NeverScrollableScrollPhysics(),
//                 // crossAxisSpacing: 10,
//                 // mainAxisSpacing: 10,
//                 // childAspectRatio: 1.3,
//                 // children: [

//                   // ── Ma zone ───────────────────
//                   GestureDetector(
//                     onTap: () async {
//                       await Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) =>
//                             const PrestataireConfigScreen()));
//                       _loadData();
//                     },
//                     child: Container(
//                       padding: const EdgeInsets.all(14),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius:
//                           BorderRadius.circular(14),
//                         border: Border.all(
//                           color: _zoneConfig.isNotEmpty
//                             ? AppColors.amber
//                             : AppColors.border,
//                           width: _zoneConfig.isNotEmpty
//                             ? 1.5 : 0.5)),
//                       child: Column(
//                         crossAxisAlignment:
//                           CrossAxisAlignment.start,
//                         children: [

//                           // Header
//                           Row(
//                             mainAxisAlignment:
//                               MainAxisAlignment
//                                 .spaceBetween,
//                             children: [
//                               Expanded(
//                                 child: Row(
//                                   children: [
//                                     Container(
//                                       width: 32, height: 32,
//                                       decoration: BoxDecoration(
//                                         color:
//                                           AppColors.amberLight,
//                                         borderRadius:
//                                           BorderRadius
//                                             .circular(10)),
//                                       child: const Icon(
//                                         Icons
//                                           .location_on_outlined,
//                                         color: AppColors.amber,
//                                         size: 18),
//                                     ),
//                                     const SizedBox(width: 6),
//                                     Text("Ma zone",
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 13,
//                                       fontWeight:
//                                         FontWeight.w600,
//                                       color:
//                                         AppColors.textPrimary,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               ),
//                               // ← Badge zone
//                               Container(
//                                 padding:
//                                   const EdgeInsets.symmetric(
//                                     horizontal: 8,
//                                     vertical: 3),
//                                 decoration: BoxDecoration(
//                                   color: _zoneConfig.isNotEmpty
//                                     ? AppColors.amberLight
//                                     : AppColors.background,
//                                   borderRadius:
//                                     BorderRadius.circular(20)),
//                                 child: Text(
//                                   _zoneConfig.isNotEmpty
//                                     ? "✅ OK"
//                                     : "⚠️ Vide",
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 9,
//                                     fontWeight: FontWeight.w500,
//                                     color: _zoneConfig.isNotEmpty
//                                       ? AppColors.amber
//                                       : AppColors.textMuted,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),

//                           // ← Contenu zone
//                           // ← Contenu zone (scrollable)
//                           if (_zoneConfig.isNotEmpty) ...[
//                             const SizedBox(height: 8),
//                             const Divider(height: 1),
//                             const SizedBox(height: 8),
//                             Expanded(
//                               child: SingleChildScrollView(
//                                 child: Row(
//                                   crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                   children: [
//                                     const Icon(
//                                       Icons.location_on_rounded,
//                                       color: AppColors.amber,
//                                       size: 14),
//                                     const SizedBox(width: 4),
//                                     Expanded(
//                                       child: Text(
//                                         _zoneConfig,
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 11,
//                                           color: AppColors.textPrimary,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ] else ...[
//                             const SizedBox(height: 8),
//                             Expanded(
//                               child: Text(
//                                 "Définissez votre zone",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 10,
//                                   color: AppColors.textSecond,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ),

//                   // ── Commandes ─────────────────
//                   _buildActionCard(
//                     Icons.list_alt_outlined,
//                     "Commandes",
//                     "Gérer les demandes",
//                     AppColors.primary,
//                     AppColors.primaryLight,
//                     onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                           const PrestataireCommandesScreen())),
//                   ),

//                   // ── Mes avis ──────────────────
//                   _buildActionCard(
//                     Icons.star_outline,
//                     "Mes avis",
//                     "Évaluations clients",
//                     AppColors.purple,
//                     AppColors.purpleLight,
//                     onTap: () {},
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 16),

//               // ── Dernières commandes ────────────
//               Text("Dernières commandes",
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//               const SizedBox(height: 8),

//               _dernieresCommandes.isEmpty
//                 ? Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius:
//                         BorderRadius.circular(12),
//                       border: Border.all(
//                         color: AppColors.border,
//                         width: 0.5)),
//                     child: Center(
//                       child: Column(
//                         children: [
//                           const Icon(
//                             Icons.inbox_outlined,
//                             color: AppColors.textMuted,
//                             size: 36),
//                           const SizedBox(height: 8),
//                           Text(
//                             "Aucune commande pour l'instant",
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               color: AppColors.textSecond,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   )
//                 : Column(
//                     children: _dernieresCommandes
//                       .map((cmd) =>
//                         _buildCommandeRecente(cmd))
//                       .toList(),
//                   ),

//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     ],
//   );
// }

//   // ── Stat card ──────────────────────────────────────
//   Widget _buildStatCard(
//     String count,
//     String label,
//     Color color,
//     Color bgColor,
//   ) {
//     return Container(
//       padding: const EdgeInsets.symmetric(
//         vertical: 14, horizontal: 8),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: color.withValues(alpha: 0.2)),
//       ),
//       child: Column(
//         children: [
//           Text(count,
//             style: GoogleFonts.poppins(
//               fontSize: 22,
//               fontWeight: FontWeight.w700,
//               color: color,
//             ),
//           ),
//           Text(label,
//             style: GoogleFonts.poppins(
//               fontSize: 10,
//               color: color,
//               fontWeight: FontWeight.w500,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Action card ────────────────────────────────────
//   Widget _buildActionCard(
//     IconData icon,
//     String title,
//     String desc,
//     Color color,
//     Color bgColor, {
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: AppColors.border, width: 0.5),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 38, height: 38,
//               decoration: BoxDecoration(
//                 color: bgColor,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, color: color, size: 20),
//             ),
//             const SizedBox(height: 8),
//             Text(title,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(desc,
//               style: GoogleFonts.poppins(
//                 fontSize: 10,
//                 color: AppColors.textSecond,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
// }

// Widget _chip(String emoji, Color color) {
//   return Container(
//     padding: const EdgeInsets.symmetric(
//       horizontal: 6, vertical: 2),
//     decoration: BoxDecoration(
//       color: color.withValues(alpha: 0.1),
//       borderRadius: BorderRadius.circular(20),
//       border: Border.all(
//         color: color.withValues(alpha: 0.3)),
//     ),
//     child: Text(emoji,
//       style: const TextStyle(fontSize: 10)),
//   );
// }

//   // ══ PAGE STATISTIQUES ════════════════════════════
//   // Widget _buildStatistiques() {
//   //   return const PrestataireCommandesScreen();
//   // }

//   // ══ PAGE AGENTS ══════════════════════════════════
//   Widget _buildAgents() {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         automaticallyImplyLeading: false,
//         title: Text("Mes agents",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(
//               Icons.person_add_outlined,
//               color: Colors.white),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(
//               Icons.people_outline,
//               size: 60,
//               color: AppColors.textMuted),
//             const SizedBox(height: 16),
//             Text("Aucun agent",
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text("Ajoutez vos livreurs et collecteurs",
//               style: GoogleFonts.poppins(
//                 fontSize: 13,
//                 color: AppColors.textSecond,
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.green,
//                 foregroundColor: Colors.white,
//               ),
//               onPressed: () {},
//               icon: const Icon(Icons.person_add),
//               label: Text("Ajouter un agent",
//                 style: GoogleFonts.poppins(
//                   fontSize: 13)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ══ PAGE PROFIL ══════════════════════════════════
//   Widget _buildProfil() {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         automaticallyImplyLeading: false,
//         title: Text("Mon profil",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [

//             // Avatar
//             const SizedBox(height: 20),
//             Container(
//               width: 80, height: 80,
//               decoration: BoxDecoration(
//                 color: AppColors.greenLight,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                   color: AppColors.green
//                     .withValues(alpha: 0.3),
//                   width: 2),
//               ),
//               child: Center(
//                 child: Text(_initiales,
//                   style: GoogleFonts.poppins(
//                     fontSize: 28,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.green,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(_nomCommercial,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             Text(_zone,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: AppColors.textSecond,
//               ),
//             ),

//             const SizedBox(height: 24),

//             // Infos
//             _buildProfilItem(
//               Icons.person_outline, "Nom complet",
//               '$_prenom $_nom'),
//             _buildProfilItem(
//               Icons.email_outlined, "Email", _email),
//             _buildProfilItem(
//               Icons.location_on_outlined,
//               "Zone", _zone),
//             _buildProfilItem(
//               //Icons.work_outline,"Type de service", "Pressing"),
//               Icons.work_outline, "Type de service",_typeService.isNotEmpty ? _typeService : 'Non configuré'),

//             const SizedBox(height: 24),

//             // Bouton déconnexion
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.red,
//                   side: const BorderSide(
//                     color: Colors.red),
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 12),
//                 ),
//                 onPressed: _logout,
//                 icon: const Icon(Icons.logout),
//                 label: Text("Déconnexion",
//                   style: GoogleFonts.poppins(
//                     fontSize: 14)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProfilItem(
//       IconData icon, String label, String value) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: AppColors.border, width: 0.5),
//       ),
//       child: Row(
//         children: [
//           Icon(icon,
//             color: AppColors.green, size: 20),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment:
//               CrossAxisAlignment.start,
//             children: [
//               Text(label,
//                 style: GoogleFonts.poppins(
//                   fontSize: 11,
//                   color: AppColors.textSecond,
//                 ),
//               ),
//               Text(value,
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _optionBadge(String label, bool active) {
//   return Container(
//     margin: const EdgeInsets.only(right: 6),
//     padding: const EdgeInsets.symmetric(
//       horizontal: 8, vertical: 3),
//     decoration: BoxDecoration(
//       color: active
//         ? AppColors.greenLight
//         : AppColors.background,
//       borderRadius: BorderRadius.circular(20),
//     ),
//     child: Text(label,
//       style: GoogleFonts.poppins(
//         fontSize: 10,
//         fontWeight: FontWeight.w500,
//         color: active
//           ? AppColors.green
//           : AppColors.textMuted,
//       ),
//     ),
//   );
// }
// void _showLogoutDialog() {
//   showDialog(
//     context: context,
//     builder: (_) => AlertDialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16)),
//       title: Text("Déconnexion",
//         style: GoogleFonts.poppins(
//           fontSize: 16,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       content: Text(
//         "Voulez-vous vraiment vous déconnecter ?",
//         style: GoogleFonts.poppins(fontSize: 13),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: Text("Annuler",
//             style: GoogleFonts.poppins(
//               color: AppColors.textSecond)),
//         ),
//         ElevatedButton.icon(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//           ),
//           onPressed: () {
//             Navigator.pop(context);
//             _logout();
//           },
//           icon: const Icon(
//             Icons.logout, size: 16),
//           label: Text("Déconnexion",
//             style: GoogleFonts.poppins(
//               fontSize: 13)),
//         ),
//       ],
//     ),
//   );
// }


// Widget _buildCommandeRecente(
//     Map<String, dynamic> cmd) {
//   final statut = cmd['statut'] ?? '';
//   final config = _getStatutConfig(statut);

//   return GestureDetector(
//     onTap: () => Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => CommandeDetailScreen(
//           commandeId: cmd['id']))),
//     child: Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: AppColors.border,
//           width: 0.5)),
//       child: Row(
//         children: [

//           // ← Icône statut
//           Container(
//             width: 42, height: 42,
//             decoration: BoxDecoration(
//               color: config['bgColor'] as Color,
//               borderRadius:
//                 BorderRadius.circular(10)),
//             child: Icon(
//               config['icon'] as IconData,
//               color: config['color'] as Color,
//               size: 20),
//           ),
//           const SizedBox(width: 10),

//           // ← Infos commande
//           Expanded(
//             child: Column(
//               crossAxisAlignment:
//                 CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   cmd['nomClient'] ?? '',
//                   style: GoogleFonts.poppins(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//                 Text(
//                   "${cmd['motDepot'] == 'COLLECTE_DOMICILE' ? 'Collecte' : 'Dépôt'}"
//                   " · ${cmd['dateCommande'] ?? ''}",
//                   style: GoogleFonts.poppins(
//                     fontSize: 11,
//                     color: AppColors.textSecond,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ← Montant + badge statut
//           Column(
//             crossAxisAlignment:
//               CrossAxisAlignment.end,
//             children: [
//               Text(
//                 "${(cmd['montantTotal'] ?? 0).toInt()} FCFA",
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w700,
//                   color: AppColors.green,
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: config['bgColor'] as Color,
//                   borderRadius:
//                     BorderRadius.circular(20)),
//                 child: Text(
//                   config['label'] as String,
//                   style: GoogleFonts.poppins(
//                     fontSize: 9,
//                     color: config['color'] as Color,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(width: 6),
//           const Icon(
//             Icons.chevron_right,
//             color: AppColors.textMuted,
//             size: 18),
//         ],
//       ),
//     ),
//   );
// }

// // ← Config statut avec icône
// Map<String, dynamic> _getStatutConfig(
//     String statut) {
//   switch (statut) {
//     case 'CREE':
//       return {
//         'label': 'Nouvelle',
//         'color': AppColors.primary,
//         'bgColor': AppColors.primaryLight,
//         'icon': Icons.fiber_new_outlined,
//       };
//     case 'CONFIRMEE':
//       return {
//         'label': 'Confirmée',
//         'color': AppColors.green,
//         'bgColor': AppColors.greenLight,
//         'icon': Icons.check_circle_outline,
//       };
//     case 'EN_VERIFICATION':
//       return {
//         'label': 'Vérification',
//         'color': AppColors.amber,
//         'bgColor': AppColors.amberLight,
//         'icon': Icons.verified_outlined,
//       };
//     case 'EN_TRAITEMENT':
//       return {
//         'label': 'En cours',
//         'color': AppColors.amber,
//         'bgColor': AppColors.amberLight,
//         'icon': Icons.local_laundry_service_outlined,
//       };
//     case 'TRAITEMENT_TERMINE':
//       return {
//         'label': 'Terminé',
//         'color': AppColors.purple,
//         'bgColor': AppColors.purpleLight,
//         'icon': Icons.done_all_outlined,
//       };
//     case 'PAIEMENT_RECU':
//       return {
//         'label': 'Payée',
//         'color': AppColors.green,
//         'bgColor': AppColors.greenLight,
//         'icon': Icons.payments_outlined,
//       };
//     case 'EN_LIVRAISON':
//       return {
//         'label': 'Livraison',
//         'color': AppColors.primary,
//         'bgColor': AppColors.primaryLight,
//         'icon': Icons.local_shipping_outlined,
//       };
//     case 'VERIFICATION_FINALE':
//       return {
//         'label': 'Vérif. finale',
//         'color': AppColors.amber,
//         'bgColor': AppColors.amberLight,
//         'icon': Icons.fact_check_outlined,
//       };
//     case 'TERMINEE':
//       return {
//         'label': 'Terminée',
//         'color': AppColors.green,
//         'bgColor': AppColors.greenLight,
//         'icon': Icons.check_circle_outline,
//       };
//     case 'CLOTUREE':
//       return {
//         'label': 'Clôturée ✅',
//         'color': AppColors.green,
//         'bgColor': AppColors.greenLight,
//         'icon': Icons.lock_outline,
//       };
//     case 'ANNULEE':
//       return {
//         'label': 'Annulée',
//         'color': Colors.red,
//         'bgColor': const Color(0xFFFCEBEB),
//         'icon': Icons.cancel_outlined,
//       };
//     case 'LITIGE':
//       return {
//         'label': 'Litige',
//         'color': Colors.orange,
//         'bgColor': const Color(0xFFFFF3E0),
//         'icon': Icons.warning_amber_outlined,
//       };
//     default:
//       return {
//         'label': statut,
//         'color': Colors.grey,
//         'bgColor': AppColors.background,
//         'icon': Icons.help_outline,
//       };
//   }
// }

//       // ← AJOUT dans PrestataireHomeScreen
//       IconData _getIconPrestation(String nom) {
//         final n = nom.toLowerCase();
//         if (n.contains('kilo') ||
//             n.contains('lavage')) {
//           return Icons.local_laundry_service_outlined;
//         } else if (n.contains('boubou') ||
//                   n.contains('bazin')) {
//           return Icons.checkroom_outlined;
//         } else if (n.contains('sec')) {
//           return Icons.dry_cleaning_outlined;
//         } else if (n.contains('repassage')) {
//           return Icons.iron_outlined;
//         } else if (n.contains('coiffure')) {
//           return Icons.content_cut_outlined;
//         } else if (n.contains('nettoyage') ||
//                   n.contains('menage') ||
//                   n.contains('ménage')) {
//           return Icons.cleaning_services_outlined;
//         } else if (n.contains('diagnostic') ||
//                   n.contains('reparation') ||
//                   n.contains('réparation')) {
//           return Icons.build_outlined;
//         } else {
//           return Icons.star_outline;
//         }
//       }
// }