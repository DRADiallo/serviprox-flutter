import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// http = package pour les appels API REST
import 'package:http/http.dart' as http;
// dart:convert = pour encoder/décoder le JSON
import 'dart:convert';
import 'package:memoireserviprox/features/auth/login_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
// AuthStorage = gère le token JWT en local (SharedPreferences)
import '../../core/services/auth_storage.dart';
import '../pressing/pressing_screen.dart';
import '../reparation/reparation_screen.dart';
import '../soins/soins_screen.dart';

// ══════════════════════════════════════════════════════════
// HomeScreen — Widget racine avec navigation
//
// Architecture de cet écran :
// HomeScreen (StatefulWidget)
// ├── Drawer (menu latéral)
// ├── body → _pages[_currentIndex]
// │   ├── _HomeContent (page Accueil)
// │   ├── _CommandesPage
// │   ├── _NotifsPage
// │   └── _ProfilPage
// └── NavigationBar (barre de navigation en bas)
// ══════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // _currentIndex = page actuellement affichée
  // 0=Accueil, 1=Commandes, 2=Notifs, 3=Profil
  int _currentIndex = 0;

  // Liste des 4 pages de l'application
  // const = créées une seule fois, jamais recréées
  final List<Widget> _pages = const [
    _HomeContent(),
    _CommandesPage(),
    _NotifsPage(),
    _ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // drawer = menu latéral (s'ouvre depuis la gauche)
      drawer: _buildDrawer(context),
      // body = contenu principal → change selon l'index
      body: _pages[_currentIndex],
      // NavigationBar = barre de navigation Material 3
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        // onDestinationSelected = appelé au tap sur un item
        // i = index de l'item sélectionné (0, 1, 2 ou 3)
        onDestinationSelected: (i) =>
            setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        // indicatorColor = couleur du fond de l'icône active
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(
            // icon = état non sélectionné (contour)
            icon: Icon(Icons.home_outlined),
            // selectedIcon = état sélectionné (plein)
            selectedIcon: Icon(
              Icons.home, color: AppColors.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(
              Icons.list_alt, color: AppColors.primary),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(
              Icons.notifications,
              color: AppColors.primary),
            label: 'Notifs',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ── Drawer (menu latéral) ──────────────────────────────
  // Le Drawer s'ouvre quand l'utilisateur swipe depuis
  // le bord gauche ou clique sur le bouton menu (≡)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [

          // ── Header du Drawer avec FutureBuilder ─────
          // FutureBuilder = widget asynchrone
          // Il reconstruit l'UI selon l'état du Future :
          // → snapshot.connectionState = waiting → chargement
          // → snapshot.hasData = true → données disponibles
          // → snapshot.hasError = true → erreur
          FutureBuilder<Map<String, String>>(
            // future = la fonction asynchrone à exécuter
            future: _getUserInfo(),
            // builder = construit l'UI selon l'état
            // context = contexte de ce widget
            // snapshot = état actuel du Future
            builder: (context, snapshot) {
              // ?? '' = si null → utiliser chaîne vide
              final nom    = snapshot.data?['nom']    ?? '';
              final prenom = snapshot.data?['prenom'] ?? '';
              final email  = snapshot.data?['email']  ?? '';
              // Calculer les initiales pour l'avatar
              final initiales = _getInitiales(prenom, nom);

              return Container(
                width: double.infinity,
                // EdgeInsets.fromLTRB = left, top, right, bottom
                padding: const EdgeInsets.fromLTRB(
                  16, 50, 16, 20),
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment:
                    CrossAxisAlignment.start,
                  children: [
                    // CircleAvatar = cercle avec initiales
                    // Affiche "AN" (Abdourahamane N.) au lieu
                    // d'une icône personne générique
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white
                          .withValues(alpha: 0.25),
                      child: Text(initiales,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Affiche "Prenom Nom" sur une ligne
                    Text("$prenom $nom",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(email,
                      style: GoogleFonts.poppins(
                        color: Colors.white
                            .withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Liste des items du menu ──────────────────
          // Expanded = prend tout l'espace vertical restant
          // ListView = liste scrollable si beaucoup d'items
          Expanded(
            child: ListView(
              // EdgeInsets.zero = pas de padding par défaut
              padding: EdgeInsets.zero,
              children: [
                // isActive: true = item actuellement actif
                // → fond coloré + texte en gras
                _drawerItem(
                  Icons.home_outlined, "Accueil",
                  isActive: true,
                  onTap: () => Navigator.pop(context)),
                _drawerItem(
                  Icons.list_alt_outlined,
                  "Mes commandes",
                  onTap: () => Navigator.pop(context)),
                _drawerItem(
                  Icons.notifications_outlined,
                  "Notifications",
                  onTap: () => Navigator.pop(context)),
                _drawerItem(
                  Icons.star_outline,
                  "Mes évaluations",
                  onTap: () => Navigator.pop(context)),
                // Divider = ligne séparatrice horizontale
                const Divider(),
                _drawerItem(
                  Icons.person_outline, "Mon profil",
                  onTap: () => Navigator.pop(context)),
                _drawerItem(
                  Icons.settings_outlined, "Paramètres",
                  onTap: () => Navigator.pop(context)),
                const Divider(),
                // Item déconnexion — en rouge
                _drawerItem(
                  Icons.logout, "Déconnexion",
                  color: Colors.red,
                  // onTap async car AuthStorage.logout()
                  // est une fonction asynchrone
                  onTap: () async {
                    // 1. Supprimer le token stocké localement
                    await AuthStorage.logout();
                    // 2. context.mounted = widget encore affiché ?
                    //    TOUJOURS vérifier après un await !
                    if (context.mounted) {
                      // 3. Fermer le drawer
                      Navigator.pop(context);
                      // 4. Remplacer HomeScreen par LoginScreen
                      // pushReplacement = pas de retour en arrière
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                            const LoginScreen()),
                      );
                    }
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper : charger les infos utilisateur ─────────────
  // Retourne un Map avec nom, prenom, email
  // Lus depuis SharedPreferences (AuthStorage)
  Future<Map<String, String>> _getUserInfo() async {
    return {
      'nom':    await AuthStorage.getNom(),
      'prenom': await AuthStorage.getPrenom(),
      'email':  await AuthStorage.getEmail(),
    };
  }

  // ── Helper : calculer les initiales ───────────────────
  // Ex: prenom="Awa", nom="Seck" → "AS"
  // isNotEmpty = vérifie que la chaîne n'est pas vide
  // [0] = premier caractère de la chaîne
  // toUpperCase() = convertit en majuscule
  String _getInitiales(String prenom, String nom) {
    final p = prenom.isNotEmpty
      ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty
      ? nom[0].toUpperCase() : '';
    return '$p$n';
  }

  // ── Helper : construire un item du drawer ──────────────
  // Widget réutilisable pour chaque item du menu
  // Paramètres optionnels avec {} et valeur par défaut
  Widget _drawerItem(IconData icon, String label, {
    bool isActive = false,  // false par défaut
    Color? color,           // null = utiliser couleur défaut
    required VoidCallback onTap, // obligatoire
  }) {
    return ListTile(
      leading: Icon(icon,
        // Opérateur ?? = si color est null → utiliser défaut
        // Opérateur ternaire : isActive ? couleurActive : couleurDefaut
        color: color ??
          (isActive
            ? AppColors.primary
            : AppColors.textSecond)),
      title: Text(label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isActive
            ? FontWeight.w600   // gras si actif
            : FontWeight.normal,// normal sinon
          color: color ??
            (isActive
              ? AppColors.primary
              : AppColors.textPrimary),
        ),
      ),
      // tileColor = fond de l'item
      // null = transparent (pas de fond)
      tileColor: isActive ? AppColors.primaryLight : null,
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════
// _HomeContent — Contenu de la page Accueil
//
// Changé de StatelessWidget en StatefulWidget car :
// → on charge des données depuis l'API (initState)
// → les données changent → setState() → rebuild
//
// Structure visuelle :
// Column
// ├── Container bleu (header)
// │   ├── Row (menu ≡ et cloche )
// │   ├── Texte "Bonjour, Awa !"
// │   └── TextField (recherche)
// └── Expanded → SingleChildScrollView (body blanc)
//     ├── Row (3 stat cards)
//     ├── Text "Nos services"
//     ├── Column (cartes services dynamiques)
//     └── Section "Récemment utilisés"
// ══════════════════════════════════════════════════════════
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {

  // ── Variables d'état ────────────────────────────────
  // Ces variables déclenchent un rebuild via setState()

  String _nomComplet = '';         // Nom complet utilisateur connecté
  String _adresse = ''; // Adresse affichée
  bool _hasNotif  = true;         // Badge rouge sur la cloche

  // _searchController = contrôle le TextField de recherche
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Compteurs de prestataires par type de service
  // Chargés depuis GET /api/prestataire
  int _countPressing   = 0;
  int _countReparation = 0;
  int _countSoins      = 0;

  // Liste des services depuis l'API
  // Map<String, dynamic> = dictionnaire clé-valeur
  // Ex: {'typeService': 'pressing', 'labelAffiche': 'Pressing'}
  List<Map<String, dynamic>> _services = [];

  List<Map<String, dynamic>> get _filteredServices {
    // Si la recherche est vide → retourner tous les services
    if (_searchQuery.isEmpty) return _services;

    // Sinon → filtrer par typeService ou labelAffiche
     return _services.where((service) {
      final label = (service['labelAffiche'] ?? '')
      .toString().toLowerCase();
      final type = (service['typeService'] ?? '')
      .toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return label.contains(query) || type.contains(query);
    }).toList();
  }

  // true = afficher spinner pendant le chargement
  // false = afficher les cartes de services
  bool _isLoadingServices = true;

  // ── initState ────────────────────────────────────────
  // Appelée UNE SEULE FOIS à la création du widget
  // → Idéal pour charger les données initiales
  @override
  void initState() {
    super.initState(); // ← TOUJOURS en premier !
    // Lancer les 3 chargements en parallèle
    // (pas d'await = ils s'exécutent simultanément)
    _loadUserData();
    _loadPrestataires();
    _loadServices();
  }

  // ── dispose ─────────────────────────────────────────
  @override
  void dispose() {
  // ← AJOUT
  _searchController.dispose();
  super.dispose();
  }

  // ── Charger le prénom depuis SharedPreferences ────────
  // AuthStorage.getPrenom() = lit la valeur stockée lors
  // du login dans SharedPreferences
  Future<void> _loadUserData() async {
    final prenom = await AuthStorage.getPrenom();
    final nom     = await AuthStorage.getNom();
    final adresse = await AuthStorage.getAdresse();
    // mounted = widget encore affiché ?
    // TOUJOURS vérifier avant setState() après await
    if (mounted) {
      setState(() {
        // isNotEmpty = la chaîne n'est pas vide
         _nomComplet = '${prenom.isNotEmpty ? prenom : ''} '
                    '${nom.isNotEmpty ? nom : ''}'.trim();
        //_prenom = prenom.isNotEmpty ? prenom : 'là';
        _adresse = adresse.isNotEmpty
        ? adresse
        : 'Dakar, Sénégal';
      });
    }
  }

  // ── Charger les prestataires et compter par type ──────
  // GET /api/prestataire → liste complète
  // On compte combien sont de type pressing, réparation, soins
  //
  // Innovation openEHR :
  // Si admin ajoute un nouveau service →
  // le compteur apparaît automatiquement
  Future<void> _loadPrestataires() async {
    try {
      // Récupérer le token JWT stocké après login
      final token = await AuthStorage.getToken();

      // Requête HTTP GET avec header Authorization
      // Bearer = schéma d'authentification JWT
      final response = await http.get(
        Uri.parse(ApiConstants.prestataires),
        headers: {
          'Content-Type': 'application/json',
          // Header JWT obligatoire pour les routes protégées
          'Authorization': 'Bearer $token',
        },
      );

      // 200 = HTTP OK = succès
      if (response.statusCode == 200) {
        // jsonDecode = convertit le JSON String en List Dart
        final List<dynamic> data =
            jsonDecode(response.body);

        // Compter par typeService
        int pressing = 0, reparation = 0, soins = 0;

        // for...in = itérer sur chaque élément de la liste
        for (final p in data) {
          // ?? '' = si null → chaîne vide
          // toString() = convertir en String
          // toLowerCase() = tout en minuscules
          final type = (p['typeService'] ?? '')
            .toString().toLowerCase();

          // contains() = vérifie si la chaîne contient
          // le sous-chaîne (insensible à la casse car lowercase)
          if (type.contains('pressing')) pressing++;
          else if (type.contains('reparation') ||
                   type.contains('réparation'))
            reparation++;
          else if (type.contains('soins')) soins++;
        }

        if (mounted) {
          setState(() {
            _countPressing   = pressing;
            _countReparation = reparation;
            _countSoins      = soins;
          });
        }
      }
    } catch (e) {
      // catch(e) = intercepte les erreurs réseau, timeout...
      // debugPrint = affiche dans la console de débogage
      debugPrint("Erreur chargement prestataires: $e");
    }
  }

  // ── Charger les services depuis l'API ─────────────────
  // GET /api/service-config/actifs
  //
  // PRINCIPE openEHR CENTRAL :
  // L'admin ajoute "Jardinage" depuis React →
  // Flutter le reçoit ici automatiquement →
  // Une carte "Jardinage" apparaît sur le HomeScreen
  // SANS modifier une seule ligne de code Flutter !
  Future<void> _loadServices() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.servicesActifs));

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);

        if (mounted) {
          setState(() {
            // cast<T>() = convertit List<dynamic>
            // en List<Map<String, dynamic>>
            _services =
              data.cast<Map<String, dynamic>>();
            // Désactiver le spinner
            _isLoadingServices = false;
          });
        }
      } else {
        // Réponse non-200 → utiliser valeurs par défaut
        _setDefaultServices();
      }
    } catch (e) {
      // Erreur réseau → utiliser valeurs par défaut
      // L'utilisateur peut quand même utiliser l'app
      _setDefaultServices();
    }
  }

  // ── Services par défaut si API indisponible ───────────
  // Fallback = plan B si le réseau est coupé
  // Garantit que l'app fonctionne même hors ligne
  void _setDefaultServices() {
    if (mounted) {
      setState(() {
        _services = [
          {
            'typeService': 'pressing',
            'labelAffiche': 'Pressing',
          },
          {
            'typeService': 'reparation',
            'labelAffiche': 'Réparation',
          },
          {
            'typeService': 'soins',
            'labelAffiche': 'Soins à domicile',
          },
        ];
        _isLoadingServices = false;
      });
    }
  }

  // ── Configuration visuelle par type de service ────────
  // Retourne un Map avec couleur, emoji, description...
  // selon le type de service reçu de l'API
  //
  // Pourquoi pas un switch/case ?
  // → contains() est plus souple pour les variantes
  //   "Réparation" et "reparation" → même résultat
  Map<String, dynamic> _getServiceConfig(String type) {
    // toLowerCase() = normalise pour éviter les problèmes
    // de casse (Pressing ≠ pressing ≠ PRESSING)
    final t = type.toLowerCase();

  if (t.contains('pressing')) {
    return {
        'color': AppColors.primary,
        'lightColor': AppColors.primaryLight,
        // ← CHANGEMENT : icône au lieu d'emoji
        'emoji': null,
        //'icon': Icons.checkroom_rounded, // ← icône chemise/vêtement
        'icon': Icons.local_laundry_service_rounded,
        'description':
          'Collecte de votre linge à domicile, '
          'nettoyage professionnel en atelier et '
          'livraison retour chez vous.',
        'features': [
          'Collecte à domicile',
          'Traitement en atelier',
          'Livraison retour',
          'Double preuve sécurisée',
        ],
        'count': '$_countPressing prestataires',
        'screen': const PressingScreen(),
  };
} else if (t.contains('reparation') ||
               t.contains('réparation')) {
      return {
        'color': AppColors.green,       // Vert
        'lightColor': AppColors.greenLight,
        'emoji': '🔧',
        'description':
          'Réparation de vos appareils électroniques '
          'et électroménagers par des techniciens '
          'qualifiés.',
        'features': [
          'Smartphone & Informatique',
          'Électroménager',
          'Devis obligatoire',
          'Garantie sur réparation',
        ],
        'count': '$_countReparation techniciens',
        'screen': const ReparationScreen(),
      };
    } else if (t.contains('soins')) {
      return {
        'color': AppColors.purple,      // Violet
        'lightColor': AppColors.purpleLight,
        //'emoji': '🏠',
        'emoji': null,
        'icon': Icons.handshake_rounded,
        'description':
          'Des intervenants qualifiés se déplacent '
          'chez vous pour la coiffure et l\'entretien.',
        'features': [
          'Coiffure à domicile',
          'Entretien ménager',
          'Aide & assistance',
          'Désinsectisation',
        ],
        'count': '$_countSoins intervenants',
        'screen': const SoinsScreen(),
      };
    } else {
      // ← Nouveau service ajouté par l'admin !
      // Config générique pour tout service inconnu
      // Garantit que l'app ne plante pas si admin
      // ajoute "Jardinage" ou "Plomberie"
      return {
        'color': AppColors.primary,
        'lightColor': AppColors.primaryLight,
        'emoji': '⚙️',
        'description': 'Service disponible dans votre zone.',
        'features': ['Disponible', 'Professionnel'],
        'count': 'Prestataires disponibles',
        'screen': const PressingScreen(),
      };
    }
  }

  // ══════════════════════════════════════════════════════
  // BUILD — Construction de l'interface
  //
  // build() est appelé à chaque setState()
  // Structure : Column(header bleu + body blanc)
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Column = disposition verticale
    // Les enfants occupent leur hauteur naturelle
    // SAUF ceux dans Expanded (qui prennent le reste)
    return Column(
      children: [

        // ══ HEADER BLEU ════════════════════════════════
        // Container avec couleur = boîte colorée pleine
        Container(
          color: AppColors.primary,
          // SafeArea = évite la barre de statut du téléphone
          // bottom: false = pas de padding en bas du header
          child: SafeArea(
            bottom: false,
            child: Padding(
              // EdgeInsets.fromLTRB = left, top, right, bottom
              padding: const EdgeInsets.fromLTRB(
                16, 8, 16, 20),
              child: Column(
                children: [

                  // ── Ligne : bouton menu + cloche ──────
                  // mainAxisAlignment.spaceBetween =
                  // pousse les enfants aux deux extrémités
                  Row(
                    mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                    children: [

                      // ── Bouton menu (≡) ───────────────
                      // Builder = crée un nouveau context
                      // NÉCESSAIRE pour Scaffold.of(ctx)
                      // Sans Builder → erreur "No Scaffold found"
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () =>
                            // Scaffold.of(ctx) = accède au Scaffold
                            // openDrawer() = ouvre le menu latéral
                            Scaffold.of(ctx).openDrawer(),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              // withValues(alpha:) = opacité
                              // 0.0 = transparent, 1.0 = opaque
                              color: Colors.white
                                .withValues(alpha: 0.15),
                              borderRadius:
                                BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: 20),
                          ),
                        ),
                      ),

                      // ── Cloche + badge rouge ──────────
                      // Stack = superpose des widgets
                      // Comme position:relative en CSS
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              // Marquer les notifs comme lues
                              () => _hasNotif = false),
                            child: Container(
                              width: 36, height: 36,
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
                          ),

                          // Badge rouge — visible seulement
                          // si _hasNotif est true
                          // if (condition) widget = affichage conditionnel
                          if (_hasNotif)
                            Positioned(
                              // Positioned = position absolue dans Stack
                              top: 6, right: 6,
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  // BoxShape.circle = cercle parfait
                                  shape: BoxShape.circle,
                                  // Bordure pour contraste sur fond bleu
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Salutation ────────────────────────
                  // Align = aligne son enfant dans l'espace
                  // centerLeft = coller à gauche
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment:
                        CrossAxisAlignment.start,
                      children: [
                        // $_prenom = variable interpolée dans String
                        // Affiche le vrai prénom depuis SharedPreferences
                        Text("Bonjour, $_nomComplet !",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: 14),
                            const SizedBox(width: 4),
                            // $_adresse = adresse de l'utilisateur
                            Text(
                              "$_adresse — "
                              "Que cherchez-vous ?",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Barre de recherche dans le header ─
                  // Placée DANS le header bleu (différence
                  // avec le code précédent qui l'avait
                  // dans le body blanc)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                        BorderRadius.circular(12),
                    ),
                    // TextField = champ de saisie texte
                    child: TextField(
                      //Controller + onChanged = pour récupérer la saisie
                      controller: _searchController,
                      onChanged: (value) => setState(
                        () => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText:
                          "Rechercher un service...",
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textMuted),
                        // prefixIcon = icône à gauche
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.textMuted,
                                size: 18,),
                              onPressed: ()=> setState(() {
                                // Vider le TextField et la variable
                                 _searchQuery = '';
                                _searchController.clear();
                               
                              }),
                            )
                          : null,
                        // InputBorder.none = pas de bordure
                        border: InputBorder.none,
                        contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ══ BODY BLANC ═════════════════════════════════
        // Expanded = prend TOUT l'espace vertical restant
        // après le header bleu
        // Sans Expanded → erreur "unbounded height"
        Expanded(
          // SingleChildScrollView = rend le contenu scrollable
          // Nécessaire quand le contenu dépasse l'écran
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // ── 3 compteurs dynamiques ────────────
                // Row avec 3 Expanded = chaque carte = 33%
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      count: _countPressing,
                      label: 'Pressings',
                      color: AppColors.primary,
                      bgColor: AppColors.primaryLight,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(
                      count: _countReparation,
                      label: 'Techniciens',
                      color: AppColors.green,
                      bgColor: AppColors.greenLight,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(
                      count: _countSoins,
                      label: 'Intervenants',
                      color: AppColors.purple,
                      bgColor: AppColors.purpleLight,
                    )),
                  ],
                ),

                const SizedBox(height: 20),

                Text("Nos services",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Cartes de services dynamiques ──────
                // Opérateur ternaire :
                // _isLoadingServices true → spinner
                // _isLoadingServices false → cartes
                _isLoadingServices
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        // CircularProgressIndicator = roue de chargement
                        child: CircularProgressIndicator(
                          color: AppColors.primary),
                      ),
                    )
                  // ← Résultat vide si aucun service trouvé
                  : _filteredServices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                color: AppColors.textMuted,
                                size: 48),
                              const SizedBox(height: 12),
                              Text(
                                "Aucun service trouvé\npour \"$_searchQuery\"",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textSecond,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                }),
                                child: Text(
                                  "Effacer la recherche",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ) 
                  : Column(
                      // .asMap() = convertit List en Map<index, valeur>
                      // Permet d'avoir l'index pour savoir si
                      // c'est le dernier élément (pas de SizedBox après)
                      children: _filteredServices
                        .asMap()
                        .entries
                        .map((entry) {
                          // entry.key   = index (0, 1, 2...)
                          // entry.value = le service Map<String, dynamic>

                          // Obtenir config visuelle selon le type
                          final config =
                            _getServiceConfig(
                              entry.value[
                                'typeService'] ?? '');

                          return Column(
                            children: [
                              _buildServiceCard(
                                // Nom affiché vient de l'API
                                label: entry.value[
                                  'labelAffiche'] ?? '',
                                color: config['color'],
                                lightColor:
                                  config['lightColor'],
                                emoji: config['emoji'],
                                icon: config['icon'],
                                description:
                                  config['description'],
                                // List.from() = crée une copie
                                features:
                                  List<String>.from(
                                    config['features']),
                                count: config['count'],
                                onTap: () =>
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                        config['screen']),
                                  ),
                              ),
                              // Espace SEULEMENT entre les cartes
                              // PAS après la dernière
                              // entry.key < longueur - 1 = pas le dernier
                              if (entry.key < _filteredServices.length - 1)
                                const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                    ),

                const SizedBox(height: 24),

                // ── Section récemment utilisés ─────────
                Row(
                  mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Récemment utilisés",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text("Voir tout",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Carte 1 — Pressing Médina Express
                // Statut "Clôturé" = vert (commande terminée)
                _buildRecentCard(
                  avatar: "PM",
                  name: "Pressing Médina Express",
                  subtitle: "Pressing · Hier 14h32",
                  color: AppColors.primary,
                  note: "4.8",
                  statut: "Clôturé",
                  statutColor: AppColors.green,
                  statutBg: AppColors.greenLight,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) =>
                        const PressingScreen())),
                ),

                const SizedBox(height: 8),

                // Carte 2 — Tech Repair
                // Statut "En cours" = amber (en attente)
                _buildRecentCard(
                  avatar: "TR",
                  name: "Tech Repair Plateau",
                  subtitle: "Réparation · Il y a 3 jours",
                  color: AppColors.green,
                  note: "4.6",
                  statut: "En cours",
                  statutColor: AppColors.amber,
                  statutBg: AppColors.amberLight,
                  onTap: () {},
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // WIDGETS RÉUTILISABLES (Helper Widgets)
  //
  // PRINCIPE DRY = Don't Repeat Yourself
  // Ces fonctions retournent des widgets configurables
  // qu'on appelle plusieurs fois avec des paramètres
  // différents au lieu de dupliquer le code
  // ════════════════════════════════════════════════════

  // ── Carte stat (compteur coloré) ──────────────────────
  // Utilisée 3 fois : Pressings, Techniciens, Intervenants
  Widget _buildStatCard({
    required int count,     // nombre à afficher
    required String label,  // texte sous le nombre
    required Color color,   // couleur du texte
    required Color bgColor, // couleur du fond
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        // withValues(alpha: 0.2) = couleur à 20% d'opacité
        border: Border.all(
          color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Nombre principal — gros et gras
          Text('$count',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          // Label sous le nombre — petit
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            // textAlign.center = centré dans sa boîte
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Carte service (grande) ─────────────────────────────
  // Structure :
  // Container blanc (border)
  // ├── Header coloré (bannière)
  // │   ├── Stack (cercle décoratif + contenu)
  // │   └── Row (emoji + nom + badge compteur)
  // └── Body blanc
  //     ├── Text (description)
  //     ├── Wrap (tags features)
  //     └── ElevatedButton (voir prestataires)
  Widget _buildServiceCard({
    required String label,        // Ex: "Pressing"
    required Color color,         // Couleur principale
    required Color lightColor,    // Couleur claire pour les tags
    required String? emoji, 
    IconData? icon,               // Icône alternative à l'emoji       
    required String description,  // Texte descriptif
    required List<String> features, // Ex: ['Collecte', ...]
    required String count,        // Ex: "32 prestataires"
    required VoidCallback onTap,  // Action au tap
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [

          // ── Bannière colorée ─────────────────────────
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                // BorderRadius.only = arrondir SEULEMENT
                // les coins en haut (pas en bas)
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              // Stack = superposer plusieurs widgets
              child: Stack(
                children: [
                  // Cercle décoratif (effet visuel)
                  // Positioned = position absolue dans Stack
                  Positioned(
                    right: -20, top: -20,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white
                          .withValues(alpha: 0.1),
                        // BoxShape.circle = cercle parfait
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Contenu principal par-dessus le cercle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Boîte emoji
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white
                              .withValues(alpha: 0.2),
                            borderRadius:
                              BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: icon != null
                                ? Icon(icon, color: Colors.white, size: 30)
                                : Text(
                                    emoji ?? '⚙️',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontFamilyFallback: [
                                        'Apple Color Emoji',
                                        'Noto Color Emoji',
                                      ],
                                    ),
                                  ),
                            ),
                        ),
                        const SizedBox(width: 12),
                        // Nom du service + badge compteur
                        Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          mainAxisAlignment:
                            MainAxisAlignment.center,
                          children: [
                            Text(label,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Badge compteur (ex: "32 prestataires")
                            Container(
                              padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white
                                  .withValues(alpha: 0.2),
                                borderRadius:
                                  BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize:
                                  MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    color: Colors.white,
                                    size: 12),
                                  const SizedBox(width: 4),
                                  Text(count,
                                    style:
                                      GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight:
                                          FontWeight.w500,
                                      ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Corps de la carte ─────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [
                // Description du service
                Text(description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecond,
                    // height = interligne (1.6 = 160% de la taille)
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Tags features ─────────────────────
                // Wrap = comme Row mais va à la ligne
                // automatiquement si pas assez de place
                Wrap(
                  spacing: 6,    // espace horizontal entre tags
                  runSpacing: 6, // espace vertical entre lignes
                  // .map() = transforme chaque String en widget
                  children: features.map((f) =>
                    Container(
                      padding:
                        const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: lightColor,
                        borderRadius:
                          BorderRadius.circular(20),
                      ),
                      child: Row(
                        // MainAxisSize.min = prend le minimum
                        // d'espace horizontal (pas toute la largeur)
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                            color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(f,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // .toList() = convertit Iterable en List
                  // requis par children: qui attend List<Widget>
                  ).toList(),
                ),

                const SizedBox(height: 12),

                // ── Bouton voir prestataires ──────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      // foregroundColor = couleur du texte/icône
                      // OBLIGATOIRE pour que le texte soit blanc
                      foregroundColor: Colors.white,
                      padding:
                        const EdgeInsets.symmetric(
                          vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                          BorderRadius.circular(10)),
                    ),
                    onPressed: onTap,
                    child: Text(
                      "Voir les prestataires →",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        // color explicite en plus de foregroundColor
                        // pour garantir la visibilité
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte récemment utilisé ────────────────────────────
  // Affiche un prestataire utilisé récemment avec :
  // → Avatar (initiales colorées)
  // → Nom + sous-titre (type · date)
  // → Note étoile
  // → Badge statut (Clôturé, En cours, En litige...)
  Widget _buildRecentCard({
    required String avatar,      // Ex: "PM" pour Pressing Médina
    required String name,        // Nom du prestataire
    required String subtitle,    // Type + date
    required Color color,        // Couleur de l'avatar
    required String note,        // Note sur 5 (Ex: "4.8")
    required String statut,      // Ex: "Clôturé", "En cours"
    required Color statutColor,  // Couleur du texte statut
    required Color statutBg,     // Couleur du fond statut
    required VoidCallback onTap, // Action au tap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Avatar avec initiales
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(avatar,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nom + sous-titre
            // Expanded = prend tout l'espace restant
            // avant le bloc note/statut
            Expanded(
              child: Column(
                crossAxisAlignment:
                  CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecond,
                    ),
                  ),
                ],
              ),
            ),

            // Note + badge statut (alignés à droite)
            Column(
              // CrossAxisAlignment.end = aligner à droite
              crossAxisAlignment:
                CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 14),
                    Text(note,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Badge statut coloré
                // Couleur change selon le statut :
                // Clôturé → vert, En cours → amber
                // En litige → rouge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statutBg,
                    borderRadius:
                      BorderRadius.circular(10),
                  ),
                  child: Text(statut,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: statutColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // Flèche → indique que c'est cliquable
            const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// PAGES TEMPORAIRES
//
// Ces pages sont des placeholders en attendant
// leur implémentation complète
// Elles sont définies EN DEHORS de toute classe State
// (erreur courante = les définir dedans)
// ══════════════════════════════════════════════════════════

// Page Commandes — à implémenter
class _CommandesPage extends StatelessWidget {
  const _CommandesPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Mes commandes")),
    body: const Center(
      child: Text("Commandes — En cours...")),
  );
}

// Page Notifications — à implémenter
class _NotifsPage extends StatelessWidget {
  const _NotifsPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Notifications")),
    body: const Center(
      child: Text("Notifications — En cours...")),
  );
}

// Page Profil — à implémenter
class _ProfilPage extends StatelessWidget {
  const _ProfilPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Mon profil")),
    body: const Center(
      child: Text("Profil — En cours...")),
  );
}