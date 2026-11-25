// // lib/features/prestataire/commandes_prestataire_screen.dart
// //
// // Écran "Mes commandes" côté PRESTATAIRE
// // Liste des commandes avec filtres de statut + action contextuelle
// // L'action disponible = prochain statut depuis etapesEffectives (API)
// // AppColors.green = côté prestataire
// // ─────────────────────────────────────────────────────────────
// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;

// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';
// import 'Commande_detail_screen.dart'; // CommandeDetailScreen (params optionnels)

// class CommandesPrestataire extends StatefulWidget {
//   final int prestataireId;

//   const CommandesPrestataire({super.key, required this.prestataireId});

//   @override
//   State<CommandesPrestataire> createState() =>
//       _CommandesPrestataireState();
// }

// class _CommandesPrestataireState
//     extends State<CommandesPrestataire> {

//   // ── Couleur prestataire ───────────────────────────────────
//   static const _green = AppColors.green;

//   // ── State ─────────────────────────────────────────────────
//   List<Map<String, dynamic>> _toutes  = [];
//   List<Map<String, dynamic>> _filtrees = [];
//   bool   _chargement = true;
//   String? _erreur;
//   String  _filtreStatut = 'TOUTES';
//   Timer?  _timer;

//   // ── Variables config prestataire (OpenEHR couche 2) ────────────
//   List<String> _configEtapes = [];
//   List<Map<String, dynamic>> _agents = [];
//   bool _avecAgent = false;
//   int _prestataireId = 0;

//   // Compteurs par catégorie
//   int get _nbAttente  => _toutes.where((c) =>
//       _statutBase(c) == 'CREE').length;
//   int get _nbEnCours  => _toutes.where((c) =>
//       _enCours(c)).length;
//   int get _nbTerminees => _toutes.where((c) =>
//       _statutBase(c) == 'CLOTUREE').length;

//   // ── Lifecycle ─────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     _loadConfig(); 
//     _charger();
//     _timer = Timer.periodic(
//       const Duration(seconds: 30), (_) => _charger());
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   Future<void> _loadConfig() async {
//   final id = await AuthStorage.getUserId();
//   if (id == null) return;
//   _prestataireId = id;

//   final token = await AuthStorage.getToken();
//   try {
//     final res = await http.get(
//       Uri.parse('${ApiConstants.prestataires}/config/$id'),
//       headers: {'Authorization': 'Bearer $token'},
//     );
//     if (res.statusCode != 200) return;

//     final data = jsonDecode(res.body) as Map<String, dynamic>;
//     final etapesJson = data['etapesEffectivesJson'] as String? ?? '[]';
//     final etapes = (jsonDecode(etapesJson) as List).cast<String>();
//     final avecAgent = data['avecAgent'] as bool? ?? false;

//     List<Map<String, dynamic>> agents = [];
//     if (avecAgent) {
//       final r2 = await http.get(
//         Uri.parse('${ApiConstants.baseUrl}/agents/prestataire/$id'),
//         headers: {'Authorization': 'Bearer $token'},
//       );
//       if (r2.statusCode == 200) {
//         agents = (jsonDecode(r2.body) as List).cast<Map<String, dynamic>>();
//       }
//     }

//     if (mounted) setState(() {
//       _configEtapes = etapes;
//       _avecAgent    = avecAgent;
//       _agents       = agents;
//     });
//   } catch (e) {
//     debugPrint('Config error: $e');
//   }
// }

//   // ── Data ──────────────────────────────────────────────────

//   Future<void> _charger() async {
//     if (!_chargement) setState(() => _chargement = true);
//     try {
//       final token = await AuthStorage.getToken();
//       final resp  = await http.get(
//         Uri.parse(
//           '${ApiConstants.baseUrl}/commandes/prestataire/${widget.prestataireId}',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type':  'application/json',
//         },
//       );
//       if (!mounted) return;
//       if (resp.statusCode == 200) {
//         final List raw = jsonDecode(resp.body);
//         _toutes = raw.whereType<Map<String, dynamic>>().toList()
//           ..sort((a, b) {
//             final da = DateTime.tryParse(
//                     a['dateCreation']?.toString() ?? '') ??
//                 DateTime(2000);
//             final db = DateTime.tryParse(
//                     b['dateCreation']?.toString() ?? '') ??
//                 DateTime(2000);
//             return db.compareTo(da); // plus récent en premier
//           });
//         setState(() => _chargement = false);
//         _appliquerFiltre();
//       } else {
//         setState(() {
//           _erreur    = 'Erreur ${resp.statusCode}';
//           _chargement = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() {
//         _erreur    = 'Connexion impossible';
//         _chargement = false;
//       });
//     }
//   }

  

//   void _appliquerFiltre() {
//     List<Map<String, dynamic>> res = List.from(_toutes);
//     switch (_filtreStatut) {
//       case 'EN_ATTENTE':
//         res = res.where((c) => _statutBase(c) == 'CREE').toList();
//         break;
//       case 'EN_COURS':
//         res = res.where((c) => _enCours(c)).toList();
//         break;
//       case 'TERMINEES':
//         res = res.where((c) => _statutBase(c) == 'CLOTUREE').toList();
//         break;
//     }
//     setState(() => _filtrees = res);
//   }

//   // ── Avancement commande ───────────────────────────────────

//   String _statutBase(Map<String, dynamic> c) =>
//       (c['statut'] ?? c['status'] ?? 'CREE').toString().toUpperCase();

//   bool _enCours(Map<String, dynamic> c) {
//     const pending = {'CREE', 'CLOTUREE', 'ANNULEE'};
//     return !pending.contains(_statutBase(c));
//   }

//   /// Prochain statut dans la liste des étapes
//   String? _prochainStatut(Map<String, dynamic> c) {
//     final etapes  = _parseEtapes(c);
//     final current = _statutBase(c);
//     final idx     = etapes.indexWhere(
//         (e) => e.toUpperCase() == current);
//     if (idx >= 0 && idx < etapes.length - 1) {
//       return etapes[idx + 1];
//     }
//     return null;
//   }

//   List<String> _parseEtapes(Map<String, dynamic> c) {
//     try {
//       final raw = c['etapesEffectives'];
//       if (raw is List) return raw.map((e) => e.toString()).toList();
//       if (raw is String && raw.isNotEmpty) {
//         return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
//       }
//     } catch (_) {}
//     return ['CREE', 'CONFIRMEE', 'EN_COLLECTE',
//             'EN_TRAITEMENT', 'EN_LIVRAISON', 'CLOTUREE'];
//   }

//   String _labelStatut(String s) {
//     const m = {
//       'CREE':         'CRÉÉ',
//       'CONFIRMEE':    'CONFIRMÉE',
//       'EN_COLLECTE':  'EN COLLECTE',
//       'EN_TRAITEMENT':'EN TRAITEMENT',
//       'EN_LIVRAISON': 'EN LIVRAISON',
//       'CLOTUREE':     'CLÔTURÉE',
//       'ANNULEE':      'ANNULÉE',
//     };
//     return m[s.toUpperCase()] ?? s.replaceAll('_', ' ').toUpperCase();
//   }

//   String _labelAction(String prochain) {
//     const m = {
//       'CONFIRMEE':    'Confirmer la commande',
//       'EN_COLLECTE':  'Démarrer En collecte',
//       'EN_TRAITEMENT':'Prise en charge',
//       'EN_LIVRAISON': 'Démarrer En livraison',
//       'CLOTUREE':     'Clôturer la commande',
//     };
//     return m[prochain.toUpperCase()]
//         ?? 'Passer à : ${_labelStatut(prochain)}';
//   }

//   // ── Avancer statut ────────────────────────────────────────
//   Future<void> _avancer(Map<String, dynamic> c) async {
//     final prochain = _prochainStatut(c);
//     if (prochain == null) return;
//     final id = c['id']?.toString() ?? '';
//     try {
//       final token = await AuthStorage.getToken();
//       final resp  = await http.put(
//         Uri.parse(
//           '${ApiConstants.baseUrl}/commandes/$id/statut',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type':  'application/json',
//         },
//         body: jsonEncode({'statut': prochain}),
//       );
//       if (resp.statusCode == 200 && mounted) {
//         _charger();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               '✅ Commande passée à : ${_labelStatut(prochain)}',
//               style: GoogleFonts.poppins()),
//             backgroundColor: _green,
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Erreur : $e',
//                 style: GoogleFonts.poppins()),
//             backgroundColor: AppColors.red,
//           ),
//         );
//       }
//     }
//   }

//   // ════════════════════════════════════════════════════════════
//   // BUILD
//   // ════════════════════════════════════════════════════════════

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: _green,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         title: Text('Mes commandes',
//           style: GoogleFonts.poppins(
//             fontSize: 16, fontWeight: FontWeight.w700)),
//         actions: [
//           Stack(
//             alignment: Alignment.topRight,
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.notifications_outlined),
//                 onPressed: _charger,
//               ),
//               if (_nbAttente > 0)
//                 Positioned(
//                   top: 8, right: 8,
//                   child: Container(
//                     width: 16, height: 16,
//                     decoration: const BoxDecoration(
//                       color: AppColors.red,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text('$_nbAttente',
//                         style: GoogleFonts.poppins(
//                           fontSize: 9, fontWeight: FontWeight.w700,
//                           color: Colors.white)),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//       body: Column(
//         children: [

//           // ── Stats rapides ─────────────────────────────
//           if (!_chargement)
//             Container(
//               color: Colors.white,
//               padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
//               child: Row(
//                 children: [
//                   _statTile(_nbAttente.toString(), 'En attente',
//                       const Color(0xFFFEF3C7), AppColors.amber),
//                   const SizedBox(width: 8),
//                   _statTile(_nbEnCours.toString(), 'En cours',
//                       AppColors.primaryLight, AppColors.primary),
//                   const SizedBox(width: 8),
//                   _statTile(_nbTerminees.toString(), 'Terminées',
//                       AppColors.greenLight, _green),
//                 ],
//               ),
//             ),

//           // ── Filtres ───────────────────────────────────
//           Container(
//             color: Colors.white,
//             height: 44,
//             child: ListView(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 12, vertical: 6),
//               children: [
//                 _chip('TOUTES',    'Toutes'),
//                 _chip('EN_ATTENTE', 'En attente'),
//                 _chip('EN_COURS',  'En cours'),
//                 _chip('TERMINEES', 'Terminées'),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: AppColors.border),

//           // ── Liste ────────────────────────────────────
//           Expanded(
//             child: _chargement
//                 ? const Center(child: CircularProgressIndicator(
//                     color: _green))
//                 : _erreur != null
//                     ? _buildErreur()
//                     : _filtrees.isEmpty
//                         ? _buildVide()
//                         : RefreshIndicator(
//                             color: _green,
//                             onRefresh: _charger,
//                             child: ListView.builder(
//                               padding: const EdgeInsets.fromLTRB(
//                                   12, 8, 12, 24),
//                               itemCount: _filtrees.length,
//                               itemBuilder: (_, i) =>
//                                   _buildCarteCommande(_filtrees[i]),
//                             ),
//                           ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Carte commande ────────────────────────────────────────
//   Widget _buildCarteCommande(Map<String, dynamic> c) {
//     final statut   = _statutBase(c);
//     final etapes   = _parseEtapes(c);
//     final current  = etapes.indexWhere(
//         (e) => e.toUpperCase() == statut);
//     final prochain = _prochainStatut(c);
//     final isUrgent = _enCours(c) && prochain != null &&
//         statut != 'EN_LIVRAISON';

//     final nom    = c['nomClient']?.toString()
//                 ?? c['client']?['nom']?.toString()
//                 ?? 'Client';
//     final cmdId  = '#${c['id']?.toString().padLeft(3,'0') ?? '000'}';
//     final temps  = _tempsDepuis(c['dateCreation']?.toString());
//     final resume = _resumeArticles(c);

//     return GestureDetector(
//       onTap: () => Navigator.pushNamed(       // ✅ route nommée (via main.dart)
//         context,
//         '/commande-detail',
//         arguments: {
//           'commande':         c,
//           'etapesEffectives': _configEtapes,
//           'agents':           _agents,
//           'prestataireId':    _prestataireId,
//           'avecAgent':        _avecAgent,
//         },
//   ).then((_) => _charger()),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: isUrgent ? AppColors.amber : AppColors.border,
//             width: isUrgent ? 1.5 : 0.5,
//           ),
//         ),
//         child: Column(
//           children: [
//             // ─ Bandeau urgent ─────────────────────────
//             if (isUrgent)
//               Container(
//                 decoration: const BoxDecoration(
//                   color: Color(0xFFFEF3C7),
//                   borderRadius: BorderRadius.vertical(
//                       top: Radius.circular(13)),
//                 ),
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 12, vertical: 5),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 6, height: 6,
//                       decoration: const BoxDecoration(
//                         color: AppColors.amber, shape: BoxShape.circle),
//                     ),
//                     const SizedBox(width: 6),
//                     Text('En cours · action requise',
//                       style: GoogleFonts.poppins(
//                         fontSize: 10, fontWeight: FontWeight.w600,
//                         color: AppColors.amber)),
//                   ],
//                 ),
//               ),

//             // ─ Corps ──────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Nom + badge statut
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(nom,
//                               style: GoogleFonts.poppins(
//                                 fontSize: 13, fontWeight: FontWeight.w700,
//                                 color: AppColors.textPrimary)),
//                             Text('$cmdId · $temps',
//                               style: GoogleFonts.poppins(
//                                 fontSize: 10, color: AppColors.textMuted)),
//                           ],
//                         ),
//                       ),
//                       _badgeStatut(statut),
//                     ],
//                   ),
//                   const SizedBox(height: 7),

//                   // Résumé articles
//                   Text(resume,
//                     style: GoogleFonts.poppins(
//                       fontSize: 11, color: AppColors.textSecond),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis),
//                   const SizedBox(height: 10),

//                   // Mini barre étapes
//                   _buildMiniEtapes(etapes, current),
//                   const SizedBox(height: 10),

//                   // Bouton action
//                   if (prochain != null && statut != 'CLOTUREE')
//                     GestureDetector(
//                       onTap: () => _avancer(c),
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                             vertical: 10),
//                         decoration: BoxDecoration(
//                           color: _actionColor(prochain),
//                           borderRadius: BorderRadius.circular(9),
//                         ),
//                         child: Text(
//                           '➡️ ${_labelAction(prochain)}',
//                           textAlign: TextAlign.center,
//                           style: GoogleFonts.poppins(
//                             fontSize: 12, fontWeight: FontWeight.w700,
//                             color: Colors.white),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Color _actionColor(String prochain) {
//     switch (prochain.toUpperCase()) {
//       case 'CONFIRMEE':    return _green;
//       case 'EN_COLLECTE':  return AppColors.primary;
//       case 'EN_TRAITEMENT':return AppColors.primary;
//       case 'EN_LIVRAISON': return AppColors.amber;
//       case 'CLOTUREE':     return _green;
//       default:             return _green;
//     }
//   }

//   Widget _buildMiniEtapes(List<String> etapes, int current) {
//     return Row(
//       children: [
//         for (int i = 0; i < etapes.length; i++) ...[
//           _miniCircle(i, current),
//           if (i < etapes.length - 1)
//             Expanded(
//               child: Container(
//                 height: 2,
//                 color: i < current ? _green : AppColors.border,
//               ),
//             ),
//         ],
//       ],
//     );
//   }

//   Widget _miniCircle(int i, int current) {
//     Color bg;
//     Widget child;
//     if (i < current) {
//       bg    = _green;
//       child = const Icon(Icons.check, color: Colors.white, size: 9);
//     } else if (i == current) {
//       bg    = AppColors.amber;
//       child = Text('${i + 1}',
//           style: GoogleFonts.poppins(fontSize: 8, color: Colors.white,
//               fontWeight: FontWeight.w700));
//     } else {
//       bg    = AppColors.border;
//       child = Text('${i + 1}',
//           style: GoogleFonts.poppins(fontSize: 8,
//               color: AppColors.textMuted));
//     }
//     return Container(
//       width: 20, height: 20,
//       decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
//       child: Center(child: child),
//     );
//   }

//   Widget _badgeStatut(String statut) {
//     Color bg, fg;
//     switch (statut) {
//       case 'CREE':
//         bg = AppColors.background;
//         fg = AppColors.textSecond;
//         break;
//       case 'CONFIRMEE':
//         bg = AppColors.primaryLight;
//         fg = AppColors.primary;
//         break;
//       case 'EN_COLLECTE':
//       case 'EN_TRAITEMENT':
//         bg = const Color(0xFFFEF3C7);
//         fg = AppColors.amber;
//         break;
//       case 'EN_LIVRAISON':
//         bg = AppColors.primaryLight;
//         fg = AppColors.primary;
//         break;
//       case 'CLOTUREE':
//         bg = AppColors.greenLight;
//         fg = _green;
//         break;
//       default:
//         bg = AppColors.background;
//         fg = AppColors.textMuted;
//     }
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color: bg, borderRadius: BorderRadius.circular(20)),
//       child: Text(_labelStatut(statut),
//         style: GoogleFonts.poppins(
//           fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
//     );
//   }

//   // ── Helpers ───────────────────────────────────────────────

//   String _tempsDepuis(String? iso) {
//     if (iso == null) return 'récemment';
//     final dt = DateTime.tryParse(iso);
//     if (dt == null) return 'récemment';
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
//     if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
//     return 'il y a ${diff.inDays}j';
//   }

//   String _resumeArticles(Map<String, dynamic> c) {
//     try {
//       final raw = c['lignes'] ?? c['lignesCommande'];
//       List items = [];
//       if (raw is List) items = raw;
//       else if (raw is String && raw.isNotEmpty) items = jsonDecode(raw);
//       return items.take(3).map((l) {
//         if (l is Map) {
//           final nom = l['nom']?.toString() ?? '—';
//           final qte = l['quantite'] ?? 1;
//           return '$nom × $qte';
//         }
//         return l.toString();
//       }).join(' · ');
//     } catch (_) {
//       return '—';
//     }
//   }

//   // ── Widgets UI ────────────────────────────────────────────

//   Widget _statTile(String val, String label, Color bg, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: bg, borderRadius: BorderRadius.circular(9)),
//         child: Column(
//           children: [
//             Text(val,
//               style: GoogleFonts.poppins(
//                 fontSize: 18, fontWeight: FontWeight.w800,
//                 color: color)),
//             Text(label,
//               style: GoogleFonts.poppins(
//                 fontSize: 9, fontWeight: FontWeight.w600,
//                 color: color)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _chip(String code, String label) {
//     final active = _filtreStatut == code;
//     return GestureDetector(
//       onTap: () {
//         setState(() => _filtreStatut = code);
//         _appliquerFiltre();
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         margin: const EdgeInsets.only(right: 8),
//         padding: const EdgeInsets.symmetric(
//             horizontal: 14, vertical: 4),
//         decoration: BoxDecoration(
//           color: active ? _green : AppColors.background,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//               color: active ? _green : AppColors.border),
//         ),
//         child: Text(label,
//           style: GoogleFonts.poppins(
//             fontSize: 11,
//             fontWeight: active ? FontWeight.w600 : FontWeight.w400,
//             color: active ? Colors.white : AppColors.textPrimary)),
//       ),
//     );
//   }

//   Widget _buildErreur() => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(32),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.cloud_off_outlined,
//               size: 64, color: AppColors.textMuted),
//           const SizedBox(height: 14),
//           Text(_erreur!,
//             textAlign: TextAlign.center,
//             style: GoogleFonts.poppins(
//                 fontSize: 13, color: AppColors.textMuted)),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _charger,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _green, foregroundColor: Colors.white),
//             child: Text('Réessayer',
//                 style: GoogleFonts.poppins(fontSize: 13)),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _buildVide() => Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const Icon(Icons.inbox_outlined,
//             size: 64, color: AppColors.textMuted),
//         const SizedBox(height: 14),
//         Text(
//           _filtreStatut == 'TOUTES'
//               ? 'Aucune commande'
//               : 'Aucune commande dans cette catégorie',
//           style: GoogleFonts.poppins(
//               fontSize: 13, color: AppColors.textMuted)),
//       ],
//     ),
//   );
// }












// // lib/features/prestataire/commandes_prestataire_screen.dart
// //
// // Écran "Mes commandes" côté PRESTATAIRE
// // Liste des commandes avec filtres de statut + action contextuelle
// // L'action disponible = prochain statut depuis etapesEffectives (API)
// // AppColors.green = côté prestataire
// // ─────────────────────────────────────────────────────────────
// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:memoireserviprox/features/prestataire/Commande_detail_screen.dart';

// import '../../core/constants/app_colors.dart';
// import '../../core/constants/api_constants.dart';
// import '../../core/services/auth_storage.dart';


// class CommandesPrestataire extends StatefulWidget {
//   final int prestataireId;

//   const CommandesPrestataire({super.key, required this.prestataireId});

//   @override
//   State<CommandesPrestataire> createState() =>
//       _CommandesPrestataireState();
// }

// class _CommandesPrestataireState
//     extends State<CommandesPrestataire> {

//   // ── Couleur prestataire ───────────────────────────────────
//   static const _green = AppColors.green;

//   // ── State ─────────────────────────────────────────────────
//   List<Map<String, dynamic>> _toutes  = [];
//   List<Map<String, dynamic>> _filtrees = [];
//   bool   _chargement = true;
//   String? _erreur;
//   String  _filtreStatut = 'TOUTES';
//   Timer?  _timer;

//   // Compteurs par catégorie
//   int get _nbAttente  => _toutes.where((c) =>
//       _statutBase(c) == 'CREE').length;
//   int get _nbEnCours  => _toutes.where((c) =>
//       _enCours(c)).length;
//   int get _nbTerminees => _toutes.where((c) =>
//       _statutBase(c) == 'CLOTUREE').length;

//   // ── Lifecycle ─────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     _charger();
//     _timer = Timer.periodic(
//       const Duration(seconds: 30), (_) => _charger());
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   // ── Data ──────────────────────────────────────────────────

//   Future<void> _charger() async {
//     if (!_chargement) setState(() => _chargement = true);
//     try {
//       final token = await AuthStorage.getToken();
//       final resp  = await http.get(
//         Uri.parse(
//           '${ApiConstants.baseUrl}/commandes/prestataire/${widget.prestataireId}',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type':  'application/json',
//         },
//       );
//       if (!mounted) return;
//       if (resp.statusCode == 200) {
//         final List raw = jsonDecode(resp.body);
//         _toutes = raw.whereType<Map<String, dynamic>>().toList()
//           ..sort((a, b) {
//             final da = DateTime.tryParse(
//                     a['dateCreation']?.toString() ?? '') ??
//                 DateTime(2000);
//             final db = DateTime.tryParse(
//                     b['dateCreation']?.toString() ?? '') ??
//                 DateTime(2000);
//             return db.compareTo(da); // plus récent en premier
//           });
//         setState(() => _chargement = false);
//         _appliquerFiltre();
//       } else {
//         setState(() {
//           _erreur    = 'Erreur ${resp.statusCode}';
//           _chargement = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() {
//         _erreur    = 'Connexion impossible';
//         _chargement = false;
//       });
//     }
//   }

//   void _appliquerFiltre() {
//     List<Map<String, dynamic>> res = List.from(_toutes);
//     switch (_filtreStatut) {
//       case 'EN_ATTENTE':
//         res = res.where((c) => _statutBase(c) == 'CREE').toList();
//         break;
//       case 'EN_COURS':
//         res = res.where((c) => _enCours(c)).toList();
//         break;
//       case 'TERMINEES':
//         res = res.where((c) => _statutBase(c) == 'CLOTUREE').toList();
//         break;
//     }
//     setState(() => _filtrees = res);
//   }

//   // ── Avancement commande ───────────────────────────────────

//   String _statutBase(Map<String, dynamic> c) =>
//       (c['statut'] ?? c['status'] ?? 'CREE').toString().toUpperCase();

//   bool _enCours(Map<String, dynamic> c) {
//     const pending = {'CREE', 'CLOTUREE', 'ANNULEE'};
//     return !pending.contains(_statutBase(c));
//   }

//   /// Prochain statut dans la liste des étapes
//   String? _prochainStatut(Map<String, dynamic> c) {
//     final etapes  = _parseEtapes(c);
//     final current = _statutBase(c);
//     final idx     = etapes.indexWhere(
//         (e) => e.toUpperCase() == current);
//     if (idx >= 0 && idx < etapes.length - 1) {
//       return etapes[idx + 1];
//     }
//     return null;
//   }

//   List<String> _parseEtapes(Map<String, dynamic> c) {
//     try {
//       final raw = c['etapesEffectives'];
//       if (raw is List) return raw.map((e) => e.toString()).toList();
//       if (raw is String && raw.isNotEmpty) {
//         return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
//       }
//     } catch (_) {}
//     return ['CREE', 'CONFIRMEE', 'EN_COLLECTE',
//             'EN_TRAITEMENT', 'EN_LIVRAISON', 'CLOTUREE'];
//   }

//   String _labelStatut(String s) {
//     const m = {
//       'CREE':         'CRÉÉ',
//       'CONFIRMEE':    'CONFIRMÉE',
//       'EN_COLLECTE':  'EN COLLECTE',
//       'EN_TRAITEMENT':'EN TRAITEMENT',
//       'EN_LIVRAISON': 'EN LIVRAISON',
//       'CLOTUREE':     'CLÔTURÉE',
//       'ANNULEE':      'ANNULÉE',
//     };
//     return m[s.toUpperCase()] ?? s.replaceAll('_', ' ').toUpperCase();
//   }

//   String _labelAction(String prochain) {
//     const m = {
//       'CONFIRMEE':    'Confirmer la commande',
//       'EN_COLLECTE':  'Démarrer En collecte',
//       'EN_TRAITEMENT':'Prise en charge',
//       'EN_LIVRAISON': 'Démarrer En livraison',
//       'CLOTUREE':     'Clôturer la commande',
//     };
//     return m[prochain.toUpperCase()]
//         ?? 'Passer à : ${_labelStatut(prochain)}';
//   }

//   // ── Avancer statut ────────────────────────────────────────
//   Future<void> _avancer(Map<String, dynamic> c) async {
//     final prochain = _prochainStatut(c);
//     if (prochain == null) return;
//     final id = c['id']?.toString() ?? '';
//     try {
//       final token = await AuthStorage.getToken();
//       final resp  = await http.put(
//         Uri.parse(
//           '${ApiConstants.baseUrl}/commandes/$id/statut',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type':  'application/json',
//         },
//         body: jsonEncode({'statut': prochain}),
//       );
//       if (resp.statusCode == 200 && mounted) {
//         _charger();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               '✅ Commande passée à : ${_labelStatut(prochain)}',
//               style: GoogleFonts.poppins()),
//             backgroundColor: _green,
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Erreur : $e',
//                 style: GoogleFonts.poppins()),
//             backgroundColor: AppColors.red,
//           ),
//         );
//       }
//     }
//   }

//   // ════════════════════════════════════════════════════════════
//   // BUILD
//   // ════════════════════════════════════════════════════════════

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: _green,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         title: Text('Mes commandes',
//           style: GoogleFonts.poppins(
//             fontSize: 16, fontWeight: FontWeight.w700)),
//         actions: [
//           Stack(
//             alignment: Alignment.topRight,
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.notifications_outlined),
//                 onPressed: _charger,
//               ),
//               if (_nbAttente > 0)
//                 Positioned(
//                   top: 8, right: 8,
//                   child: Container(
//                     width: 16, height: 16,
//                     decoration: const BoxDecoration(
//                       color: AppColors.red,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text('$_nbAttente',
//                         style: GoogleFonts.poppins(
//                           fontSize: 9, fontWeight: FontWeight.w700,
//                           color: Colors.white)),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//       body: Column(
//         children: [

//           // ── Stats rapides ─────────────────────────────
//           if (!_chargement)
//             Container(
//               color: Colors.white,
//               padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
//               child: Row(
//                 children: [
//                   _statTile(_nbAttente.toString(), 'En attente',
//                       const Color(0xFFFEF3C7), AppColors.amber),
//                   const SizedBox(width: 8),
//                   _statTile(_nbEnCours.toString(), 'En cours',
//                       AppColors.primaryLight, AppColors.primary),
//                   const SizedBox(width: 8),
//                   _statTile(_nbTerminees.toString(), 'Terminées',
//                       AppColors.greenLight, _green),
//                 ],
//               ),
//             ),

//           // ── Filtres ───────────────────────────────────
//           Container(
//             color: Colors.white,
//             height: 44,
//             child: ListView(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 12, vertical: 6),
//               children: [
//                 _chip('TOUTES',    'Toutes'),
//                 _chip('EN_ATTENTE', 'En attente'),
//                 _chip('EN_COURS',  'En cours'),
//                 _chip('TERMINEES', 'Terminées'),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: AppColors.border),

//           // ── Liste ────────────────────────────────────
//           Expanded(
//             child: _chargement
//                 ? const Center(child: CircularProgressIndicator(
//                     color: _green))
//                 : _erreur != null
//                     ? _buildErreur()
//                     : _filtrees.isEmpty
//                         ? _buildVide()
//                         : RefreshIndicator(
//                             color: _green,
//                             onRefresh: _charger,
//                             child: ListView.builder(
//                               padding: const EdgeInsets.fromLTRB(
//                                   12, 8, 12, 24),
//                               itemCount: _filtrees.length,
//                               itemBuilder: (_, i) =>
//                                   _buildCarteCommande(_filtrees[i]),
//                             ),
//                           ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Carte commande ────────────────────────────────────────
//   Widget _buildCarteCommande(Map<String, dynamic> c) {
//     final statut   = _statutBase(c);
//     final etapes   = _parseEtapes(c);
//     final current  = etapes.indexWhere(
//         (e) => e.toUpperCase() == statut);
//     final prochain = _prochainStatut(c);
//     final isUrgent = _enCours(c) && prochain != null &&
//         statut != 'EN_LIVRAISON';

//     final nom    = c['nomClient']?.toString()
//                 ?? c['client']?['nom']?.toString()
//                 ?? 'Client';
//     final cmdId  = '#${c['id']?.toString().padLeft(3,'0') ?? '000'}';
//     final temps  = _tempsDepuis(c['dateCreation']?.toString());
//     final resume = _resumeArticles(c);

//     return GestureDetector(
//       onTap: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => DetailCommandePrestataire(commande: c),
//         ),
//       ).then((_) => _charger()),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: isUrgent ? AppColors.amber : AppColors.border,
//             width: isUrgent ? 1.5 : 0.5,
//           ),
//         ),
//         child: Column(
//           children: [
//             // ─ Bandeau urgent ─────────────────────────
//             if (isUrgent)
//               Container(
//                 decoration: const BoxDecoration(
//                   color: Color(0xFFFEF3C7),
//                   borderRadius: BorderRadius.vertical(
//                       top: Radius.circular(13)),
//                 ),
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 12, vertical: 5),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 6, height: 6,
//                       decoration: const BoxDecoration(
//                         color: AppColors.amber, shape: BoxShape.circle),
//                     ),
//                     const SizedBox(width: 6),
//                     Text('En cours · action requise',
//                       style: GoogleFonts.poppins(
//                         fontSize: 10, fontWeight: FontWeight.w600,
//                         color: AppColors.amber)),
//                   ],
//                 ),
//               ),

//             // ─ Corps ──────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Nom + badge statut
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(nom,
//                               style: GoogleFonts.poppins(
//                                 fontSize: 13, fontWeight: FontWeight.w700,
//                                 color: AppColors.textPrimary)),
//                             Text('$cmdId · $temps',
//                               style: GoogleFonts.poppins(
//                                 fontSize: 10, color: AppColors.textMuted)),
//                           ],
//                         ),
//                       ),
//                       _badgeStatut(statut),
//                     ],
//                   ),
//                   const SizedBox(height: 7),

//                   // Résumé articles
//                   Text(resume,
//                     style: GoogleFonts.poppins(
//                       fontSize: 11, color: AppColors.textSecond),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis),
//                   const SizedBox(height: 10),

//                   // Mini barre étapes
//                   _buildMiniEtapes(etapes, current),
//                   const SizedBox(height: 10),

//                   // Bouton action
//                   if (prochain != null && statut != 'CLOTUREE')
//                     GestureDetector(
//                       onTap: () => _avancer(c),
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                             vertical: 10),
//                         decoration: BoxDecoration(
//                           color: _actionColor(prochain),
//                           borderRadius: BorderRadius.circular(9),
//                         ),
//                         child: Text(
//                           '➡️ ${_labelAction(prochain)}',
//                           textAlign: TextAlign.center,
//                           style: GoogleFonts.poppins(
//                             fontSize: 12, fontWeight: FontWeight.w700,
//                             color: Colors.white),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Color _actionColor(String prochain) {
//     switch (prochain.toUpperCase()) {
//       case 'CONFIRMEE':    return _green;
//       case 'EN_COLLECTE':  return AppColors.primary;
//       case 'EN_TRAITEMENT':return AppColors.primary;
//       case 'EN_LIVRAISON': return AppColors.amber;
//       case 'CLOTUREE':     return _green;
//       default:             return _green;
//     }
//   }

//   Widget _buildMiniEtapes(List<String> etapes, int current) {
//     return Row(
//       children: [
//         for (int i = 0; i < etapes.length; i++) ...[
//           _miniCircle(i, current),
//           if (i < etapes.length - 1)
//             Expanded(
//               child: Container(
//                 height: 2,
//                 color: i < current ? _green : AppColors.border,
//               ),
//             ),
//         ],
//       ],
//     );
//   }

//   Widget _miniCircle(int i, int current) {
//     Color bg;
//     Widget child;
//     if (i < current) {
//       bg    = _green;
//       child = const Icon(Icons.check, color: Colors.white, size: 9);
//     } else if (i == current) {
//       bg    = AppColors.amber;
//       child = Text('${i + 1}',
//           style: GoogleFonts.poppins(fontSize: 8, color: Colors.white,
//               fontWeight: FontWeight.w700));
//     } else {
//       bg    = AppColors.border;
//       child = Text('${i + 1}',
//           style: GoogleFonts.poppins(fontSize: 8,
//               color: AppColors.textMuted));
//     }
//     return Container(
//       width: 20, height: 20,
//       decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
//       child: Center(child: child),
//     );
//   }

//   Widget _badgeStatut(String statut) {
//     Color bg, fg;
//     switch (statut) {
//       case 'CREE':
//         bg = AppColors.background;
//         fg = AppColors.textSecond;
//         break;
//       case 'CONFIRMEE':
//         bg = AppColors.primaryLight;
//         fg = AppColors.primary;
//         break;
//       case 'EN_COLLECTE':
//       case 'EN_TRAITEMENT':
//         bg = const Color(0xFFFEF3C7);
//         fg = AppColors.amber;
//         break;
//       case 'EN_LIVRAISON':
//         bg = AppColors.primaryLight;
//         fg = AppColors.primary;
//         break;
//       case 'CLOTUREE':
//         bg = AppColors.greenLight;
//         fg = _green;
//         break;
//       default:
//         bg = AppColors.background;
//         fg = AppColors.textMuted;
//     }
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color: bg, borderRadius: BorderRadius.circular(20)),
//       child: Text(_labelStatut(statut),
//         style: GoogleFonts.poppins(
//           fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
//     );
//   }

//   // ── Helpers ───────────────────────────────────────────────

//   String _tempsDepuis(String? iso) {
//     if (iso == null) return 'récemment';
//     final dt = DateTime.tryParse(iso);
//     if (dt == null) return 'récemment';
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
//     if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
//     return 'il y a ${diff.inDays}j';
//   }

//   String _resumeArticles(Map<String, dynamic> c) {
//     try {
//       final raw = c['lignes'] ?? c['lignesCommande'];
//       List items = [];
//       if (raw is List) items = raw;
//       else if (raw is String && raw.isNotEmpty) items = jsonDecode(raw);
//       return items.take(3).map((l) {
//         if (l is Map) {
//           final nom = l['nom']?.toString() ?? '—';
//           final qte = l['quantite'] ?? 1;
//           return '$nom × $qte';
//         }
//         return l.toString();
//       }).join(' · ');
//     } catch (_) {
//       return '—';
//     }
//   }

//   // ── Widgets UI ────────────────────────────────────────────

//   Widget _statTile(String val, String label, Color bg, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: bg, borderRadius: BorderRadius.circular(9)),
//         child: Column(
//           children: [
//             Text(val,
//               style: GoogleFonts.poppins(
//                 fontSize: 18, fontWeight: FontWeight.w800,
//                 color: color)),
//             Text(label,
//               style: GoogleFonts.poppins(
//                 fontSize: 9, fontWeight: FontWeight.w600,
//                 color: color)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _chip(String code, String label) {
//     final active = _filtreStatut == code;
//     return GestureDetector(
//       onTap: () {
//         setState(() => _filtreStatut = code);
//         _appliquerFiltre();
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         margin: const EdgeInsets.only(right: 8),
//         padding: const EdgeInsets.symmetric(
//             horizontal: 14, vertical: 4),
//         decoration: BoxDecoration(
//           color: active ? _green : AppColors.background,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//               color: active ? _green : AppColors.border),
//         ),
//         child: Text(label,
//           style: GoogleFonts.poppins(
//             fontSize: 11,
//             fontWeight: active ? FontWeight.w600 : FontWeight.w400,
//             color: active ? Colors.white : AppColors.textPrimary)),
//       ),
//     );
//   }

//   Widget _buildErreur() => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(32),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.cloud_off_outlined,
//               size: 64, color: AppColors.textMuted),
//           const SizedBox(height: 14),
//           Text(_erreur!,
//             textAlign: TextAlign.center,
//             style: GoogleFonts.poppins(
//                 fontSize: 13, color: AppColors.textMuted)),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _charger,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _green, foregroundColor: Colors.white),
//             child: Text('Réessayer',
//                 style: GoogleFonts.poppins(fontSize: 13)),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _buildVide() => Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const Icon(Icons.inbox_outlined,
//             size: 64, color: AppColors.textMuted),
//         const SizedBox(height: 14),
//         Text(
//           _filtreStatut == 'TOUTES'
//               ? 'Aucune commande'
//               : 'Aucune commande dans cette catégorie',
//           style: GoogleFonts.poppins(
//               fontSize: 13, color: AppColors.textMuted)),
//       ],
//     ),
//   );
// }