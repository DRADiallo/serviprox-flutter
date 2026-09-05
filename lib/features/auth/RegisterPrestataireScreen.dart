import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// http = package pour faire des appels API REST
import 'package:http/http.dart' as http;
// dart:convert = pour encoder/décoder le JSON
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import '../home/home_screen.dart';


// ═══════════════════════════════════════════════════════════
// RegisterPrestataireScreen.dart
//
// ── CONCEPTS FLUTTER À MAÎTRISER DANS CE FICHIER ──────────
//
// 1. StatefulWidget vs StatelessWidget
//    StatelessWidget = widget SANS état (ex: texte fixe)
//    StatefulWidget  = widget AVEC état qui peut changer
//    → On utilise StatefulWidget ici car :
//      - la liste des services change (chargement API)
//      - le service sélectionné change (tap utilisateur)
//      - la force du mot de passe change (frappe)
//      - le spinner de chargement change (true/false)
//
// 2. State<T>
//    L'état est séparé du widget en deux classes :
//    RegisterPrestataireScreen     → le widget (immuable)
//    _RegisterPrestataireScreenState → l'état (mutable)
//
// 3. setState()
//    Méthode magique qui dit à Flutter :
//    "Mes données ont changé → reconstruis l'UI !"
//    Sans setState() → l'écran ne se met pas à jour !
//
// 4. initState()
//    Méthode du cycle de vie appelée UNE SEULE FOIS
//    quand le widget est créé → idéal pour charger des données
//
// 5. dispose()
//    Méthode appelée quand le widget est détruit
//    → libérer les ressources (controllers, animations...)
//    → éviter les fuites mémoire (memory leaks)
//
// 6. async/await
//    Pour les opérations longues (appel API, lecture fichier)
//    async = "cette fonction peut être longue"
//    await = "attends le résultat avant de continuer"
//    → L'interface reste fluide pendant l'attente !
//
// 7. Future<void>
//    Type de retour d'une fonction asynchrone
//    Future = "promesse d'un résultat futur"
//    void   = "ne retourne rien"
//
// 8. mounted
//    Propriété qui vérifie si le widget est encore affiché
//    → Toujours vérifier avant d'appeler setState()
//       après un await pour éviter les erreurs
//
// 9. GlobalKey<FormState>
//    Clé unique qui donne accès à l'état du formulaire
//    → _formKey.currentState!.validate() = valide tout
//
// 10. TextEditingController
//     Contrôle un champ de saisie :
//     → lire : _nomCtrl.text
//     → effacer : _nomCtrl.clear()
//     → modifier : _nomCtrl.text = "valeur"
// ═══════════════════════════════════════════════════════════



// ── StatefulWidget ─────────────────────────────────────────
// StatefulWidget = widget dont l'apparence peut changer
// Il est composé de DEUX classes obligatoires :
// 1. La classe widget (RegisterPrestataireScreen)
//    → immuable, reçoit les paramètres externes
// 2. La classe state (_RegisterPrestataireScreenState)
//    → mutable, contient les données qui changent
//
// La méthode createState() crée et lie les deux classes
class RegisterPrestataireScreen extends StatefulWidget {
  // super.key = identifiant unique du widget dans l'arbre
  // Flutter l'utilise pour optimiser les reconstructions
  const RegisterPrestataireScreen({super.key});

  // createState() est appelée automatiquement par Flutter
  // Elle crée l'objet State associé à ce widget
  @override
  State<RegisterPrestataireScreen> createState() =>
      _RegisterPrestataireScreenState();
}

// ── State<T> ───────────────────────────────────────────────
// T = type du widget associé (RegisterPrestataireScreen)
// Le préfixe _ = classe privée (non accessible hors fichier)
// C'est ici que vivent toutes les données qui changent
class _RegisterPrestataireScreenState
    extends State<RegisterPrestataireScreen> {

  // ── GlobalKey<FormState> ───────────────────────────────
  // GlobalKey = clé unique dans tout l'arbre de widgets
  // FormState = état du widget Form
  // Utilisation : _formKey.currentState!.validate()
  // → parcourt tous les TextFormField et appelle validator()
  final _formKey = GlobalKey<FormState>();

  // ── TextEditingController ──────────────────────────────
  // Un controller par champ de saisie
  // Créés ici → liés au TextFormField via controller: ...
  // Doivent être libérés dans dispose()
  final _nomCommercialCtrl = TextEditingController();
  final _prenomCtrl        = TextEditingController();
  final _nomCtrl           = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  final _zoneCtrl          = TextEditingController();
  final _passwordCtrl      = TextEditingController();
  final _confirmCtrl       = TextEditingController();

  // ── Variables d'état (State variables) ────────────────
  // Ces variables sont des "sources de vérité" de l'UI
  // Quand elles changent via setState() → Flutter reconstruit
  //
  // bool = vrai ou faux
  bool _obscurePassword  = true;  // mot de passe masqué ?
  bool _obscureConfirm   = true;  // confirmation masquée ?
  bool _isLoading        = false; // formulaire en cours d'envoi ?
  bool _isLoadingServices = true; // services en cours de chargement ?

  // String = chaîne de caractères
  String _selectedService  = ''; // service actuellement sélectionné
  String _passwordStrength = ''; // texte "Faible/Moyen/Fort..."

  // Color = couleur Flutter
  Color _strengthColor = Colors.transparent;

  // double = nombre décimal (entre 0.0 et 1.0)
  double _strengthValue = 0;

  // ── List<Map<String, String>> ──────────────────────────
  // List = tableau dynamique (peut grandir/rétrécir)
  // Map<String, String> = dictionnaire clé:valeur
  // Ex: {'type': 'pressing', 'label': 'Pressing'}
  // Chargé depuis l'API → vide au départ
  List<Map<String, String>> _services = [];

  // ══════════════════════════════════════════════════════
  // CYCLE DE VIE DU WIDGET (Lifecycle)
  // ══════════════════════════════════════════════════════
  //
  // Ordre d'appel des méthodes du cycle de vie :
  // 1. createState()   → crée l'objet State
  // 2. initState()     → initialisation (UNE FOIS)
  // 3. build()         → construit l'UI (peut être appelé N fois)
  // 4. setState()      → déclenche un rebuild de build()
  // 5. dispose()       → nettoyage (widget détruit)

  // ── initState() ───────────────────────────────────────
  // Appelée UNE SEULE FOIS quand le widget est inséré
  // dans l'arbre de widgets
  // → Idéal pour : charger données, initialiser animations
  // IMPORTANT : toujours appeler super.initState() en premier
  @override
  void initState() {
    super.initState(); // ← OBLIGATOIRE en premier !
    // Charger la liste des services depuis l'API
    // dès que la page s'ouvre
    _loadServices();
  }

  // ── dispose() ─────────────────────────────────────────
  // Appelée quand le widget est retiré de l'arbre
  // (navigation vers une autre page, fermeture app...)
  // → TOUJOURS libérer les TextEditingController ici
  // → Sans dispose() = fuite mémoire (memory leak) !
  @override
  void dispose() {
    // Libérer chaque controller dans l'ordre
    _nomCommercialCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _zoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose(); // ← OBLIGATOIRE en dernier !
  }

  // ══════════════════════════════════════════════════════
  // MÉTHODES MÉTIER
  // ══════════════════════════════════════════════════════

  // ── _loadServices() ───────────────────────────────────
  // Future<void> = fonction asynchrone qui ne retourne rien
  // async = permet d'utiliser await à l'intérieur
  //
  // PRINCIPE openEHR :
  // Les services ne sont PAS codés en dur dans Flutter !
  // Ils viennent du backend → si admin ajoute "Jardinage"
  // → Flutter le voit automatiquement sans modification
  Future<void> _loadServices() async {
    try {
      // http.get() = requête HTTP GET vers l'API
      // await = attend la réponse avant de continuer
      // Uri.parse() = convertit le String en objet URI
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/service-config/actifs'),
        headers: {'Content-Type': 'application/json'},
      );

      // response.statusCode == 200 = succès HTTP
      if (response.statusCode == 200) {
        // jsonDecode() = convertit le JSON String en Dart
        // response.body = le contenu de la réponse
        // List<dynamic> = liste de type inconnu (JSON array)
        final List<dynamic> data =
            jsonDecode(response.body);

        // setState() → dit à Flutter de reconstruire l'UI
        // avec les nouvelles valeurs de _services
        setState(() {
          // .map() = transforme chaque élément de la liste
          // service = un objet JSON (Map<String, dynamic>)
          // .toString() = convertit en String
          _services = data.map((service) => {
            'type': service['typeService'].toString(),
            'label': service['labelAffiche'].toString(),
          }).toList(); // .toList() = convertit en List

          // Sélectionner le premier service par défaut
          // _services.isNotEmpty = vérifie que la liste
          // n'est pas vide avant d'accéder à [0]
          if (_services.isNotEmpty) {
            _selectedService = _services[0]['type']!;
            // ! = opérateur null-check : je garantis
            // que la valeur n'est pas null
          }

          // Désactiver le spinner de chargement
          _isLoadingServices = false;
        });
      } else {
        // Réponse non-200 → utiliser valeurs par défaut
        _setDefaultServices();
      }
    } catch (e) {
      // catch(e) = intercepte toute erreur (réseau, timeout...)
      // e = l'erreur capturée
      // debugPrint = affiche dans la console de débogage
      debugPrint("Erreur chargement services: $e");
      // Fallback = plan B si l'API est indisponible
      _setDefaultServices();
    }
  }

  // ── _setDefaultServices() ─────────────────────────────
  // Méthode de secours (fallback) si l'API est indisponible
  // Permet à l'inscription de fonctionner même hors ligne
  void _setDefaultServices() {
    // setState() pour mettre à jour l'UI même en cas d'erreur
    setState(() {
      // Liste codée en dur UNIQUEMENT comme plan B
      _services = [
        {'type': 'pressing',   'label': 'Pressing'},
        {'type': 'reparation', 'label': 'Réparation'},
        {'type': 'soins',      'label': 'Soins domicile'},
      ];
      _selectedService = 'pressing';
      _isLoadingServices = false;
    });
  }

  // ── _checkPasswordStrength() ───────────────────────────
  // Appelée à chaque frappe dans le champ mot de passe
  // via onChanged: _checkPasswordStrength
  //
  // Paramètre : String value = la valeur actuelle du champ
  // Utilise RegExp (expressions régulières) pour détecter :
  // [A-Z] = au moins une majuscule
  // [0-9] = au moins un chiffre
  // [!@#...] = au moins un caractère spécial
  void _checkPasswordStrength(String value) {
    setState(() {
      if (value.isEmpty) {
        // Champ vide → reset
        _passwordStrength = "";
        _strengthValue    = 0;
        _strengthColor    = Colors.transparent;
      } else if (value.length < 6) {
        // Moins de 6 caractères → faible
        _passwordStrength = "Faible";
        _strengthValue    = 0.25; // 25% de la barre
        _strengthColor    = Colors.red;
      } else if (value.length < 8 ||
          !RegExp(r'[A-Z]').hasMatch(value) ||
          !RegExp(r'[0-9]').hasMatch(value)) {
        // Entre 6 et 8 chars OU sans majuscule/chiffre
        _passwordStrength = "Moyen";
        _strengthValue    = 0.6; // 60% de la barre
        _strengthColor    = Colors.orange;
      } else if (RegExp(r'[!@#\$%^&*]').hasMatch(value)) {
        // 8+ chars + majuscule + chiffre + spécial → très fort
        _passwordStrength = "Très fort";
        _strengthValue    = 1.0; // 100% de la barre
        _strengthColor    = Colors.green;
      } else {
        // 8+ chars + majuscule + chiffre → fort
        _passwordStrength = "Fort";
        _strengthValue    = 0.85; // 85% de la barre
        _strengthColor    = AppColors.green;
      }
    });
  }

  // ══════════════════════════════════════════════════════
  // VALIDATEURS DE FORMULAIRE
  // ══════════════════════════════════════════════════════
  //
  // Chaque validateur suit le même pattern :
  // → Paramètre : String? value (peut être null)
  // → Retourne : null si valide 
  //              String (message) si invalide 
  //
  // Appelés automatiquement par validate()

  String? _validateRequired(String? value, String field) {
    if (value == null || value.isEmpty) return "$field requis";
    if (value.length < 2) return "Minimum 2 caractères";
    return null; // null = champ valide !
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email requis";
    // RegExp = expression régulière pour valider le format
    // ^ = début, $ = fin, \w = lettre/chiffre/underscore
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(value)) {
      return "Email invalide";
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Téléphone requis";
    }
    // replaceAll() = supprime espaces et tirets
    // pour valider le format pur
    final clean = value
        .replaceAll(' ', '')
        .replaceAll('-', '');
    // Accepte : +221771234567 ou 771234567
    if (!RegExp(r'^\+?221[0-9]{9}$').hasMatch(clean) &&
        !RegExp(r'^[0-9]{9}$').hasMatch(clean)) {
      return "Format invalide (ex: +221 77 000 00 00)";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Mot de passe requis";
    }
    if (value.length < 8) return "Minimum 8 caractères";
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "1 majuscule requise";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "1 chiffre requis";
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return "Confirmation requise";
    }
    // Comparer avec le controller du mot de passe
    // .text = valeur actuelle du champ
    if (value != _passwordCtrl.text) {
      return "Les mots de passe ne correspondent pas";
    }
    return null;
  }

  // ── _submit() ─────────────────────────────────────────
  // async = fonction asynchrone (appel API futur)
  // void _submit() async {
  //   // validate() = appelle tous les validators
  //   // retourne true si tous passent, false sinon
  //   if (_formKey.currentState!.validate()) {

  //     // Activer le spinner → setState() reconstruit l'UI
  //     setState(() => _isLoading = true);

  //     // TODO : remplacer par vrai appel API Spring Boot
  //     // POST /api/auth/register/prestataire
  //     // Corps : {nom, prenom, nomCommercial, email,
  //     //          telephone, zoneCouverture, typeService,
  //     //          motDePasse}
  //     await Future.delayed(const Duration(seconds: 2));

  //     // Désactiver le spinner
  //     setState(() => _isLoading = false);

  //     // mounted = widget encore affiché ?
  //     // TOUJOURS vérifier après un await
  //     // L'utilisateur aurait pu quitter la page pendant l'attente
  //     if (mounted) {
  //       _showConfirmationDialog();
  //     }
  //   }
  // }
  void _submit() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      // ← Appel API réel
      final response = await http.post(
        Uri.parse(ApiConstants.registerPrestataire),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nom':           _nomCtrl.text.trim(),
          'prenom':        _prenomCtrl.text.trim(),
          'nomCommercial': _nomCommercialCtrl.text.trim(),
          'email':         _emailCtrl.text.trim(),
          'telephone':     _phoneCtrl.text.trim(),
          'zoneCouverture':_zoneCtrl.text.trim(),
          'typeService':   _selectedService,
          'motDePasse':    _passwordCtrl.text,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ← Sauvegarder dans SharedPreferences
        await AuthStorage.saveUserData(
          token:  data['token'],
          userId: data['userId'],
          nom:    data['nom'],
          prenom: data['prenom'],
          email:  data['email'],
          role:   data['role'],
        );

        if (mounted) {
          // ← Dialog avant redirect
          _showConfirmationDialog();
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



  // ── _showConfirmationDialog() ──────────────────────────
  // showDialog() = affiche une popup (AlertDialog)
  // context = position du widget dans l'arbre
  // barrierDismissible: false = tap extérieur ne ferme pas
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      // builder = fonction qui construit le contenu
      // _ = BuildContext ignoré (non utilisé)
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        content: Column(
          // mainAxisSize.min = prend le minimum d'espace
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.hourglass_empty,
                color: AppColors.green, size: 32),
            ),
            const SizedBox(height: 16),
            Text("Demande soumise !",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Votre dossier sera vérifié dans les 24 à 48h. "
              "Vous serez notifié par email et SMS.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecond,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Prochaines étapes :",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ... (spread operator) = insère les éléments
                  // .map() = transforme chaque String en widget
                  ...[
                    "Vérification de vos informations",
                    "Validation par l'administrateur",
                    "Activation de votre compte",
                    "Notification par email + SMS",
                  ].map((step) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.green, size: 14),
                        const SizedBox(width: 6),
                        Text(step,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
              ),
              onPressed: () {
                // Navigator.pop() = ferme l'écran actuel
                // et retourne au précédent
                // On appelle 3 fois car :
                Navigator.pop(context); // 1. ferme AlertDialog
                Navigator.pop(context); // 2. ferme RegisterPrestataire
                Navigator.pop(context); // 3. ferme RegisterScreen
              },
              child: Text("Retour à l'accueil",
                style: GoogleFonts.poppins(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD() — Construction de l'interface
  // ══════════════════════════════════════════════════════
  //
  // build() est appelée par Flutter chaque fois que :
  // → setState() est appelé
  // → Le widget parent se reconstruit
  // → Les MediaQuery changent (rotation, taille...)
  //
  // Elle doit être PURE : pas de logique métier ici !
  // Seulement la description de l'UI à afficher.
  @override
  Widget build(BuildContext context) {
    // Scaffold = structure de base d'un écran Flutter
    // → backgroundColor, body, appBar, floatingActionButton...
    return Scaffold(
      backgroundColor: Colors.white,

      // SafeArea = évite que le contenu soit caché par :
      // → la barre de statut (heure, batterie...)
      // → les encoches (notch) du téléphone
      // → la barre de navigation en bas
      body: SafeArea(
        child: Column(
          // Column = disposition verticale des enfants
          // crossAxisAlignment = alignement horizontal
          // CrossAxisAlignment.start = aligné à gauche
          children: [

            // ══ HEADER VERT ════════════════════════════
            // Container = boîte personnalisable
            // → color, padding, margin, decoration, child...
            Container(
              // double.infinity = prend toute la largeur
              width: double.infinity,
              // EdgeInsets.fromLTRB = left, top, right, bottom
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              color: AppColors.green, // ← couleur prestataire
              child: Row(
                // Row = disposition horizontale
                children: [
                  // GestureDetector = détecte les gestes
                  // (tap, double tap, swipe, long press...)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        // withValues(alpha:) = couleur avec opacité
                        // 0.0 = transparent, 1.0 = opaque
                        color: Colors.white
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white, size: 18),
                    ),
                  ),
                  // SizedBox = espace fixe entre widgets
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Inscription Prestataire",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text("Validation requise — 24 à 48h",
                        style: GoogleFonts.poppins(
                          color: Colors.white
                              .withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ══ FORMULAIRE ═════════════════════════════
            // Expanded = prend tout l'espace vertical restant
            // Sans Expanded → erreur "unbounded height"
            Expanded(
              // SingleChildScrollView = rend scrollable
              // Nécessaire quand le contenu dépasse l'écran
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                // Form = widget qui gère la validation
                // key: _formKey → pour accéder à l'état
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Boîte d'avertissement ─────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.amber
                                .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_outlined,
                              color: AppColors.amber, size: 18),
                            const SizedBox(width: 8),
                            // Expanded dans Row = prend l'espace
                            // restant après les autres widgets
                            Expanded(
                              child: Text(
                                "Votre compte sera activé après "
                                "vérification par notre équipe.",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Nom commercial ────────────────
                      _buildFloatField(
                        label: "Nom commercial",
                        hint: "Ex : Pressing Médina Express",
                        icon: Icons.store_outlined,
                        controller: _nomCommercialCtrl,
                        validator: (v) =>
                          _validateRequired(v, "Nom commercial"),
                      ),

                      // ── Prénom + Nom côte à côte ──────
                      // Row avec deux Expanded → chacun 50%
                      Row(
                        children: [
                          Expanded(
                            child: _buildFloatField(
                              label: "Prénom",
                              hint: "Ex : Moussa",
                              icon: Icons.person_outline,
                              controller: _prenomCtrl,
                              validator: (v) =>
                                _validateRequired(v, "Prénom"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFloatField(
                              label: "Nom",
                              hint: "Ex : Diallo",
                              icon: Icons.person_outline,
                              controller: _nomCtrl,
                              validator: (v) =>
                                _validateRequired(v, "Nom"),
                            ),
                          ),
                        ],
                      ),

                      // ── Email ─────────────────────────
                      _buildFloatField(
                        label: "Email professionnel",
                        hint: "pressing@email.com",
                        icon: Icons.email_outlined,
                        controller: _emailCtrl,
                        validator: _validateEmail,
                        // TextInputType = type de clavier
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // ── Téléphone ─────────────────────
                      _buildFloatField(
                        label: "Téléphone",
                        hint: "+221 77 000 00 00",
                        icon: Icons.phone_outlined,
                        controller: _phoneCtrl,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                      ),

                      // ── Type de service DYNAMIQUE ─────
                      // INNOVATION openEHR :
                      // Les services viennent de l'API !
                      // Admin ajoute "Jardinage" → apparaît ici
                      Text("Type de service",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Opérateur ternaire imbriqué :
                      // si chargement → spinner
                      // sinon si vide → message
                      // sinon → boutons dynamiques
                      _isLoadingServices
                        // CircularProgressIndicator = spinner
                        ? const Center(
                            child: SizedBox(
                              height: 36,
                              child: CircularProgressIndicator(
                                color: AppColors.green,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _services.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.amberLight,
                                borderRadius:
                                  BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Aucun service disponible",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.amber,
                                ),
                              ),
                            )
                          // Wrap = comme Row mais va à la ligne
                          // si pas assez de place
                          // Parfait pour un nombre variable
                          // de boutons (2, 3, 4, 5...)
                          : Wrap(
                              spacing: 8,   // espace horizontal
                              runSpacing: 8, // espace vertical
                              // .map() transforme chaque service
                              // en widget bouton
                              children: _services.map((service) {
                                // Vérifie si ce service est
                                // celui actuellement sélectionné
                                final bool isSelected =
                                  _selectedService ==
                                  service['type'];

                                return GestureDetector(
                                  onTap: () => setState(() {
                                    // Mettre à jour le service
                                    // sélectionné → setState
                                    // reconstruit → bouton change
                                    // de couleur
                                    _selectedService =
                                      service['type']!;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets
                                      .symmetric(
                                        horizontal: 16,
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      // Opérateur ternaire :
                                      // condition ? si_vrai : si_faux
                                      color: isSelected
                                        ? AppColors.green
                                        : AppColors.greenLight,
                                      borderRadius:
                                        BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                          ? AppColors.green
                                          : AppColors.border),
                                    ),
                                    child: Text(
                                      // ! = null check
                                      service['label']!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                          ? Colors.white
                                          : AppColors.green,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              // .toList() = convertit Iterable
                              // en List<Widget> requis par Wrap
                            ),

                      const SizedBox(height: 14),

                      // ── Zone de couverture ────────────
                      _buildFloatField(
                        label: "Zone de couverture",
                        hint: "Ex : Médina, Plateau, Yoff",
                        icon: Icons.location_on_outlined,
                        controller: _zoneCtrl,
                        validator: (v) =>
                          _validateRequired(v, "Zone"),
                      ),

                      // ── Mot de passe ──────────────────
                      _buildPasswordFloat(
                        label: "Mot de passe",
                        hint: "Min. 8 car., 1 majuscule, 1 chiffre",
                        controller: _passwordCtrl,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                          () => _obscurePassword =
                              !_obscurePassword),
                        validator: _validatePassword,
                        // onChanged → appelé à chaque frappe
                        onChanged: _checkPasswordStrength,
                      ),

                      // ── Indicateur force ──────────────
                      // if condition ...[widgets]
                      // → affiche la liste uniquement si
                      //   _passwordStrength n'est pas vide
                      if (_passwordStrength.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        // ClipRRect = arrondit les bords
                        // du LinearProgressIndicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          // LinearProgressIndicator = barre
                          // value: entre 0.0 et 1.0
                          child: LinearProgressIndicator(
                            value: _strengthValue,
                            backgroundColor: AppColors.border,
                            // AlwaysStoppedAnimation = couleur fixe
                            valueColor:
                              AlwaysStoppedAnimation<Color>(
                                _strengthColor),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // $ = interpolation de variable dans String
                          "Force : $_passwordStrength",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _strengthColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ── Confirmation mot de passe ─────
                      _buildPasswordFloat(
                        label: "Confirmer le mot de passe",
                        hint: "Répétez votre mot de passe",
                        controller: _confirmCtrl,
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                          () => _obscureConfirm =
                              !_obscureConfirm),
                        validator: _validateConfirm,
                        // onChanged non fourni → null par défaut
                        // pas d'indicateur de force ici
                      ),

                      const SizedBox(height: 8),

                      // ── Bouton soumettre ──────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                          ),
                          // Désactiver si chargement en cours
                          // null = bouton désactivé
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                            // Spinner pendant l'envoi
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5),
                              )
                            // Texte normal sinon
                            : Text("Soumettre ma demande",
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

  // ══════════════════════════════════════════════════════
  // WIDGETS RÉUTILISABLES (Helper Widgets)
  // ══════════════════════════════════════════════════════
  //
  // PRINCIPE DRY (Don't Repeat Yourself) :
  // Au lieu de répéter le même code pour chaque champ
  // on crée des fonctions qui retournent des widgets
  //
  // Widget = tout ce qui s'affiche à l'écran dans Flutter
  // Chaque composant (Text, Icon, Container...) est un Widget

  // ── Champ texte avec label flottant ───────────────────
  // required = paramètre obligatoire
  // TextInputType = type de clavier affiché
  // = TextInputType.text → valeur par défaut si non fourni
  Widget _buildFloatField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // Padding = espace autour du widget
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      // TextFormField = champ de saisie avec validation
      // Différence avec TextField :
      // → TextFormField s'intègre avec Form et validator
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(

          // ── Label flottant ─────────────────────────
          // labelText = affiché DANS le champ au repos
          // Comportement automatique :
          // → Champ vide + non focalisé → dans le champ
          // → Champ focalisé ou rempli → monte sur la bordure
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecond,
          ),
          // floatingLabelStyle = style quand label est en haut
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.green,
            fontWeight: FontWeight.w500,
          ),

          // hintText = texte gris quand le champ est vide
          // Disparaît dès que l'utilisateur commence à taper
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),

          // prefixIcon = icône à gauche DANS le champ
          prefixIcon: Icon(
            icon,
            color: AppColors.green,
            size: 20,
          ),
        ),
        // validator = fonction appelée par validate()
        // String? Function(String?) = fonction qui prend
        // un String? et retourne un String?
        validator: validator,
      ),
    );
  }

  // ── Champ mot de passe avec label flottant ────────────
  // Différences avec _buildFloatField :
  // → obscureText : cache les caractères (●●●●)
  // → suffixIcon : bouton œil pour afficher/cacher
  // → onToggle : callback pour basculer l'affichage
  // → onChanged : callback appelé à chaque frappe
  Widget _buildPasswordFloat({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    // VoidCallback = typedef pour Function() sans retour
    // C'est le type d'une fonction qui ne prend rien
    // et ne retourne rien : () → void
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
    // ValueChanged<String> = typedef pour Function(String)
    // ? = paramètre optionnel (peut être null)
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        // obscureText: true → affiche ●●●●
        // obscureText: false → affiche le texte réel
        obscureText: obscure,
        // onChanged → appelé à CHAQUE caractère tapé
        // Valeur null si non fourni (champ confirmation)
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecond,
          ),
          floatingLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.green,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),

          // ── Clé horizontale ────────────────────────
          // Transform.scale(scaleX: -1) = miroir horizontal
          // Transform.rotate(angle: 3.1416) = 180 degrés
          // Résultat : clé couchée pointant à droite
          prefixIcon: Transform.scale(
            scaleX: -1,
            child: Transform.rotate(
              angle: 3.1416, // π radians = 180°
              child: const Icon(
                Icons.key_outlined,
                color: AppColors.green,
                size: 20,
              ),
            ),
          ),

          // ── Bouton œil ─────────────────────────────
          // suffixIcon = icône à droite dans le champ
          // IconButton = icône cliquable
          suffixIcon: IconButton(
            icon: Icon(
              // Ternaire :
              // obscure true → œil barré (mot de passe caché)
              // obscure false → œil ouvert (mot de passe visible)
              obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
              color: AppColors.textSecond,
              size: 20,
            ),
            // onPressed = action au clic
            // onToggle vient du parent :
            // () => setState(() => _obscurePassword = !_obscurePassword)
            onPressed: onToggle,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

