import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';
import 'pressing_detail_screen.dart';


// ══════════════════════════════════════════════════════
// MODÈLE — données venant de l'API backend
// ══════════════════════════════════════════════════════
class PressingModel{
  final int id;
  final String nomCommercial;
  final String adresse;
  final String zone;
  final double noteMoyenne;
  final bool ouvert;
  final String typeService;
  final double prixKilo;
  final int nbAvis;
  final int distance;
  final bool hasExpress;
  final bool hasCollecte;
  final List<String> services;

  final Map<String, dynamic> tarifs;

  const PressingModel( {
    required this.id,
    required this.nomCommercial,
    required this.adresse,
    required this.zone,
    required this.noteMoyenne,
    required this.ouvert,
    required this.typeService,
    this.prixKilo=500,
    this.nbAvis= 0,
    this.distance= 0,
    this.hasExpress= false,
    this.hasCollecte= false,
    this.services= const [], 
    this.tarifs= const {},
  });

  // 
 factory PressingModel.fromJson(
    Map<String, dynamic> json) {

  Map<String, dynamic> config = {};
  if (json['configData'] != null) {
    try {
      config = jsonDecode(json['configData']);
    } catch (_) {}
  }

  // ← Options
  Map<String, dynamic> options = {};
  if (config['optionsActives'] != null) {
    options = config['optionsActives']
      as Map<String, dynamic>;
  }

  // ← Parser TOUTES les prestations
  List<String> services = [];
  Map<String, dynamic> tarifs = {};

  // ← 1. Nouveau format prestationsAjoutees
  if (config['prestationsAjoutees'] != null) {
    final raw = config['prestationsAjoutees']
      as List;
    for (final item in raw) {
      if (item is Map) {
        // ← Nouveau format JSON ✅
        final nom   = item['nom']?.toString() ?? '';
        final prix  = (item['prix'] ?? 0).toDouble();
        services.add(nom);
        tarifs[nom] = prix;
      } else {
        // ← Ancien format String
        final nom = item.toString();
        services.add(nom);
        // Prix dans tarifsPersonnalises
      }
    }
  }

  // ← 2. Ancien format tarifsPersonnalises
  if (config['tarifsPersonnalises'] != null) {
    final t = config['tarifsPersonnalises']
      as Map<String, dynamic>;
    t.forEach((key, value) {
      tarifs[key] = (value ?? 0).toDouble();
    });

    // ← Si services vide → utiliser clés tarifs
    if (services.isEmpty) {
      services = t.keys.toList();
    }
  }

  return PressingModel(
    id:            json['id'] ?? 0,
    nomCommercial: json['nomCommercial'] ?? '',
    adresse:       json['adresse']
                   ?? json['zone'] ?? '',
    zone:          json['zone'] ?? '',
    noteMoyenne:   (json['noteMoyenne'] ?? 0)
                   .toDouble(),
    ouvert:        json['ouvert'] ?? true,
    typeService:   json['typeService'] ?? '',
    prixKilo:      (tarifs['Lavage Kilo']
                   ?? tarifs['prixKilo']
                   ?? 500).toDouble(),
    hasExpress:    options['express'] ?? false,
    hasCollecte:   options['collecte'] ?? false,
    services:      services.isNotEmpty
      ? services : ['Lavage kilo'],
    nbAvis:        json['nbAvis'] ?? 0,
    distance:      json['distance'] ?? 0,
    tarifs:        tarifs,
  );
}

}

// ══════════════════════════════════════════════════════
// ÉCRAN LISTE PRESSING
// ══════════════════════════════════════════════════════

class PressingScreen extends StatefulWidget {
  const PressingScreen({super.key});

  @override
  State<PressingScreen> createState() => _PressingScreenState();
}

class _PressingScreenState extends State<PressingScreen> {

  String _filter = 'Tous';
  String _searchQuery = '';
  bool _isLoading = true;
  List<PressingModel> _pressings = [];
  final _searchController = TextEditingController();

  final List<String> _filters =[
    'Tous','Express','Collecte','Boubou','Ouvert',' Habits de Ceremonies'
  ];

  @override
  void initState(){
    super.initState();
    _loadPressings();
  }

  @override
  void dispose(){
    _searchController.dispose();
    super.dispose();
  }

  // --------------Charger depuis l'API ---------------------
  Future<void> _loadPressings() async {
    try{
      setState(() => _isLoading = true);
      final token = await AuthStorage.getToken();

      final response = await http.get(
        Uri.parse(ApiConstants.prestataires),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }
        );

        if(response.statusCode ==200) {
          final List<dynamic> data = jsonDecode(response.body);
          // Filtrer uniquement les prestataires pressing

          final pressings = data
          .where((p)=> 
                (p['typeService']?? '')
                        .toString()
                        .toLowerCase()
                        .contains('pressing'))
          .map((p)=> PressingModel.fromJson(p)) 
          .toList();

          setState(() {
            _pressings=pressings;
            _isLoading = false;
          });

        }else{
          setState(() {
            _pressings = _getMockData();
              _isLoading = false;

          });
        }

    }catch(e){
      debugPrint("Erreur: $e");
      setState(() {
        _pressings = _getMockData();
        _isLoading = false;
      });

    }
  }

  // ── Données mock si API indisponible ──────────────
  List<PressingModel> _getMockData(){
    return[
      const PressingModel(
        id: 1,
        nomCommercial: 'Pressing Médina Express',
        adresse: 'Rue 12, Médina',
        zone: 'Médina',
        noteMoyenne: 4.8,
        ouvert: true,
        typeService: 'pressing',
        prixKilo: 500,
        nbAvis: 124,
        distance: 1,
        hasExpress: true,
        hasCollecte: true,
        services: ['Lavage kilo', 'Boubou/Bazin']
      ),
      const PressingModel(
        id: 2,
        nomCommercial: 'Pressing Almadies Luxe',
        adresse: 'Av. Cheikh Anta, Almadies',
        zone: 'Almadies',
        noteMoyenne: 4.9,
        ouvert: true,
        typeService: 'pressing',
        prixKilo: 800,
        nbAvis: 89,
        distance: 3,
        hasExpress: true,
        hasCollecte: true,
        services: ['Lavage kilo', 'habits Ceremonies'],
      ),
      const PressingModel(
        id: 3,
        nomCommercial: 'Tech Pressing Plateau',
        adresse: 'Bd de la République',
        zone: 'Plateau',
        noteMoyenne: 4.6,
        ouvert: true,
        typeService: 'pressing',
        prixKilo: 450,
        nbAvis: 56,
        distance: 2,
        hasExpress: false,
        hasCollecte: true,
        services: ['Lavage kilo', 'Nettoyage sec','Repassage','sechage'],
      ),
      const PressingModel(
        id: 4,
        nomCommercial: 'Pressing Yoff Qualité',
        adresse: 'Route de Yoff',
        zone: 'Yoff',
        noteMoyenne: 4.5,
        ouvert: false,
        typeService: 'pressing',
        prixKilo: 500,
        nbAvis: 43,
        distance: 5,
        hasExpress: false,
        hasCollecte: true,
        services: ['Lavage kilo', 'Boubou/Bazin'],
      ),
    ];
  }

  // ------- Liste filtrée----------------

  List<PressingModel> get _filtered {
    List<PressingModel> result;
    switch (_filter){
      case 'Express':
          result = _pressings.where((p)=>p.hasExpress).toList();
        break; 
      case 'Collecte':
          result = _pressings.where((p)=>p.hasCollecte).toList();
        break; 

      case 'Boubou':
        result = _pressings.where((p) => p.services
            .any((s) => s.contains('Boubou'))).toList();
        break; 
      case 'Ouvert':
          result = _pressings.where((p)=>p.ouvert).toList();
        break; 
      case 'Habits de Ceremonies':
          result = _pressings.where((p)=>p.services.any((s) => s.contains('Habits de Ceremonies'))).toList();
        break;   
      default: 
          result = _pressings;        
    }

     // Filtre par recherche texte
     if(_searchQuery.isNotEmpty){
      final q = _searchQuery.toLowerCase();
      result = result.where((p)=>
        p.nomCommercial.toLowerCase().contains(q)||
        p.zone.toLowerCase().contains(q)||
        p.adresse.toLowerCase().contains(q)||
        p.services.any((s)=>
            s.toLowerCase().contains(q))
        ).toList();   

      }
       return result; 
  }

  @override
  Widget build(BuildContext context){
     return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers:[

          // AppBAR------------------
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const  Icon(
                Icons.arrow_back,color: Colors.white),
               onPressed: () => Navigator.pop(context),

            ),
            actions: [
              IconButton(
                 icon: const  Icon(Icons.tune ,color: Colors.white),
                 onPressed: (){},
                 ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pressing",
                    style: GoogleFonts.poppins(
                      color: Colors.white,fontSize: 20,
                      fontWeight: FontWeight.w700,
                      ),
                      ),
                      Text(_isLoading?
                      "Chargement....."
                      :"${_pressings.length}"
                      "prestataires près de vous",
                      style: GoogleFonts.poppins(
                        color: Colors.white
                                        .withValues(alpha: 0.8),
                                      fontSize: 12,
                      ),
                      ),
                  ],
                ),
              ),
            ),

          ),
          // ══ RECHERCHE + FILTRES ════════════════════
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color:Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:AppColors.border, width: 0.5),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v)=> setState(()=>_searchQuery= v),
                    decoration: InputDecoration(
                      hintText: "Rechercher un pressing...", hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textMuted),
                         prefixIcon: const Icon(
                          Icons.search, color: AppColors.primary),
                          suffixIcon: _searchQuery.isNotEmpty?
                                          IconButton(
                                           icon: const Icon(Icons.clear , color: AppColors.textMuted,size: 18),
                                           onPressed: () => setState(() {
                                             _searchQuery = '';
                                             _searchController.clear();
                                           }),
                                            )
                                            : null,
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,vertical: 14),
                                            ),

                                             
                                           ),
                         ),
                    ),
                    // Filtres chips
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                          itemCount: _filters.length,
                          itemBuilder: (_,i){
                            final f = _filters[i];
                            final bool sel = _filter == f;
                            return GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration:  BoxDecoration( color: sel ? AppColors.primary: Colors.white,
                                                            borderRadius:BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: sel ? AppColors.primary : AppColors.border
                                                            ),
                
                                                            ),
                                                            child: Text(f,
                                                            style: GoogleFonts.poppins(fontSize:12, fontWeight: FontWeight.w500,
                                                                                        color: sel ? Colors.white : AppColors.textSecond,
                                                                                         ),
                                                                                         ),
                              ),
                                
                      
                            );
                          },

                        
                      
                        
                        ),
                    ),

                    // Nombre de résultats
                    Padding(
                      padding:const  EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(_isLoading
                          ? "Chargement..." : "${_filtered.length} résultats",
                          style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w500,color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          // Button refresh
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppColors.primary,size: 18),
                            onPressed: _loadPressings,
                          ),
                        ],
                      ),
                    ),
              ],
                  ),
                  ),

                  // ══ CONTENU ---------------
                  _isLoading
                    ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.primary),
                                const SizedBox(height: 16),
                              Text("Chargement des pressings....",style: GoogleFonts.poppins(
                                                fontSize: 13,color: AppColors.textSecond, 
                             ),
                             ),  
                            ],
                          ),
                        ),

                      ),
                    )
                    :_filtered.isEmpty
                     ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded,size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text("Aucun Pressing Trouvé", style: GoogleFonts.poppins(fontSize: 15,fontWeight: 
                                      FontWeight.w500,color:AppColors.textPrimary,
                                      ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed:() => setState(() {
                                  _filter = 'Tous'; _searchQuery = ''; _searchController.clear();
                                }),
                                child: Text("Réinitialiser les filtres", style: GoogleFonts.poppins(color: AppColors.primary),
                                ),
                              ), 
                            ],
                          ),
                        ),
                        ),
                     )
                     : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(delegate: SliverChildBuilderDelegate(
                        (_,i)=> _buildPressingCard(context,_filtered[i]),
                        childCount: _filtered.length,
                      ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 20)),
                    
        ],
      ),
     );
     
     
  }

  // Carte prestataire --------------------

    Widget _buildPressingCard(BuildContext context, PressingModel p){
      return GestureDetector( onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_)=> PressingDetailScreen(pressing: p))),
        child: Opacity(opacity: p.ouvert ? 1.0:0.7, child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow:[
            BoxShadow(color: Colors.black
                          .withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0,2),
            ),
          ],
          ),
          child: Column(
            children: [
              // // Bannière bleue

              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(14),topRight: Radius.circular(14),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -10, top: -10,
                    child: Container(
                      width: 80,height: 80, decoration: BoxDecoration(
                        color: Colors.white
                                .withValues(alpha: 0.08),
                        shape: BoxShape.circle,        
                      ),
                    ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 52,height: 52,
                            decoration: BoxDecoration(color: Colors.white
                                                                      .withValues(alpha: 0.2),
                                                       borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text("👕", style: TextStyle(fontSize: 26)),
                            ),

                           /* child: Center(
                              child: Text(
                                // Prendre les 2 premières lettres
                                // Ex: "Pressing Médina Express" → "PM"
                                p.nomCommercial
                                  .trim()
                                  .split(' ')
                                  .where((w) => w.isNotEmpty)
                                  .take(2)
                                  .map((w) => w[0].toUpperCase())
                                  .join(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),*/
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(p.nomCommercial,
                                style: GoogleFonts.poppins(color: Colors.white,fontSize: 14,fontWeight:FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                ),
                                Text(p.adresse.isNotEmpty? p.adresse :p.zone,
                                style: GoogleFonts.poppins(color: Colors.white
                                                                          .withValues(alpha: 0.8),
                                                           fontSize: 11,
                                                           ),
                                ),
                              ],
                            ),
                            ),
                            // Badge Ouvert/Fermé
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 3),
                              decoration: BoxDecoration(color: p.ouvert? Colors.green: Colors.grey,
                                                          borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(p.ouvert? "Ouvert" : "Fermé",style: GoogleFonts.poppins(
                                                                      color:Colors.white,fontSize: 10,fontWeight: FontWeight.w500,
                                                                      ),
                                          ),
                            ),
                        ],
                      ),
                      ),
                  ],
                ),
              ),
              // Infos : note + distance + prix + tags
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        //Note
                        const Icon(Icons.star_border_rounded, color: Colors.amber,size: 16),
                        Text(p.noteMoyenne >0 ? p.noteMoyenne .toStringAsFixed(1)
                              :"Nouveau",
                              style: GoogleFonts.poppins(
                                fontSize: 13,fontWeight: FontWeight.w600,color: AppColors.textPrimary,
                              ),
                            ),
                            if(p.nbAvis > 0)
                                Text("(${p.nbAvis})",style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppColors.textSecond,
                                  ),
                                ),
                            const Spacer(),
                            // Distance
                             if(p.distance > 0) ...[
                                 const Icon(Icons.location_on_outlined,color: AppColors.primary,
                                 size: 14),
                                 Text("${p.distance} km", style: GoogleFonts.poppins(fontSize: 12,
                                          color: AppColors.textSecond,
                                         ),
                                     ),
                                  const SizedBox(width: 12),
                              ],
                              //     Prix depuis configData
                              Text(
                                p.prixKilo > 0 ? "${p.prixKilo.toInt()} F/KG" : "Sur devis",
                                style: GoogleFonts.poppins(fontSize: 13,fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tags services depuis configData
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,runSpacing: 4,
                        children: [
                          if(p.hasExpress)
                             _badge("Express", AppColors.amber, AppColors.amberLight),
                          if(p.hasCollecte)
                              _badge("Collecte", AppColors.green, AppColors.greenLight),
                          ...p.services.take(2).map((s)=> _badge(s, AppColors.primary,AppColors.primaryLight)),

                        ],
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
        ),
        );
    }

    // Badge----------------

    Widget _badge(String  label, Color color, Color bg){
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 3),
        decoration: BoxDecoration( color: bg,borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
      );

    }          

  }




















































