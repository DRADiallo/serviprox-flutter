import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

// ══════════════════════════════════════════════════════
// MODÈLE AGENT
// ══════════════════════════════════════════════════════
class AgentModel {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String motoMatricule;
  final String competences;
  final bool disponibilite;
  final String positionActuelle;
  final String statut;

  const AgentModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.motoMatricule,
    required this.competences,
    required this.disponibilite,
    required this.positionActuelle,
    required this.statut,
  });

  factory AgentModel.fromJson(
      Map<String, dynamic> json) {
    return AgentModel(
      id:              json['id'] ?? 0,
      nom:             json['nom'] ?? '',
      prenom:          json['prenom'] ?? '',
      email:           json['email'] ?? '',
      telephone:       json['telephone'] ?? '',
      motoMatricule:   json['motoMatricule'] ?? '',
      competences:     json['competences'] ?? '',
      disponibilite:   json['disponibilite'] ?? true,
      positionActuelle:json['positionActuelle'] ?? '',
      statut:          json['statut'] ?? 'ACTIF',
    );
  }

  String get nomComplet => '$prenom $nom'.trim();

  String get initiales {
    final p = prenom.isNotEmpty
      ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty
      ? nom[0].toUpperCase() : '';
    return '$p$n';
  }
}

// ══════════════════════════════════════════════════════
// ÉCRAN AGENTS
// ══════════════════════════════════════════════════════
class PrestataireAgentsScreen extends StatefulWidget {
  const PrestataireAgentsScreen({super.key});

  @override
  State<PrestataireAgentsScreen> createState() =>
      _PrestataireAgentsScreenState();
}

class _PrestataireAgentsScreenState
    extends State<PrestataireAgentsScreen> {

  bool _isLoading = true;
  List<AgentModel> _agents = [];

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  // ── Charger les agents ────────────────────────────
  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/agent'
          '/prestataire/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);
        setState(() {
          _agents = data
            .map((a) => AgentModel.fromJson(a))
            .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Erreur agents: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Changer disponibilité ─────────────────────────
  Future<void> _changerDisponibilite(
      int agentId, bool disponibilite) async {
    try {
      final token = await AuthStorage.getToken();
      await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/agent'
          '/$agentId/disponibilite'
          '?disponibilite=$disponibilite'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _loadAgents();
    } catch (e) {
      debugPrint("Erreur disponibilité: $e");
    }
  }

  // ── Désactiver agent ──────────────────────────────
  Future<void> _desactiver(int agentId) async {
    try {
      final token = await AuthStorage.getToken();
      await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/agent'
          '/$agentId/desactiver'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _loadAgents();
    } catch (e) {
      debugPrint("Erreur désactivation: $e");
    }
  }

  // ── Réactiver agent ───────────────────────────────
  Future<void> _reactiver(int agentId) async {
    try {
      final token = await AuthStorage.getToken();
      await http.put(
        Uri.parse(
          '${ApiConstants.baseUrl}/agent'
          '/$agentId/reactiver'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _loadAgents();
    } catch (e) {
      debugPrint("Erreur réactivation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mes agents",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "${_agents.length} agent(s)",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Bouton refresh
          IconButton(
            icon: const Icon(
              Icons.refresh, color: Colors.white),
            onPressed: _loadAgents,
          ),
          // Bouton ajouter
          IconButton(
            icon: const Icon(
              Icons.person_add_outlined,
              color: Colors.white),
            onPressed: () =>
              _showAjouterAgentDialog(),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.green))
        : _agents.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAgents,
              color: AppColors.green,
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: _agents.length,
                itemBuilder: (_, i) =>
                  _buildAgentCard(_agents[i]),
              ),
            ),

      // Bouton flottant ajouter
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () => _showAjouterAgentDialog(),
        child: const Icon(
          Icons.person_add, color: Colors.white),
      ),
    );
  }

  // ── État vide ──────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: AppColors.green),
          ),
          const SizedBox(height: 16),
          Text("Aucun agent",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ajoutez vos livreurs et collecteurs\n"
            "pour gérer vos commandes",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecond,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
            ),
            onPressed: () =>
              _showAjouterAgentDialog(),
            icon: const Icon(Icons.person_add),
            label: Text("Ajouter un agent",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Carte agent ────────────────────────────────────
  Widget _buildAgentCard(AgentModel agent) {
    final bool isActif = agent.statut == 'ACTIF';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActif
            ? AppColors.green.withValues(alpha: 0.3)
            : AppColors.border,
          width: isActif ? 1.5 : 0.5),
      ),
      child: Column(
        children: [

          // ── Header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [

                // Avatar initiales
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: isActif
                      ? AppColors.greenLight
                      : AppColors.background,
                    borderRadius:
                      BorderRadius.circular(14),
                    border: Border.all(
                      color: isActif
                        ? AppColors.green
                            .withValues(alpha: 0.3)
                        : AppColors.border),
                  ),
                  child: Center(
                    child: Text(agent.initiales,
                      style: GoogleFonts.poppins(
                        color: isActif
                          ? AppColors.green
                          : AppColors.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Infos agent
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                      CrossAxisAlignment.start,
                    children: [
                      Text(agent.nomComplet,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(agent.telephone,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecond,
                        ),
                      ),
                      if (agent.motoMatricule
                          .isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.two_wheeler,
                              size: 12,
                              color:
                                AppColors.textSecond),
                            const SizedBox(width: 4),
                            Text(agent.motoMatricule,
                              style:
                                GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors
                                    .textSecond,
                                ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Badge statut
                Column(
                  crossAxisAlignment:
                    CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                        const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActif
                          ? AppColors.greenLight
                          : AppColors.background,
                        borderRadius:
                          BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActif ? "Actif" : "Inactif",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActif
                            ? AppColors.green
                            : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Badge disponibilité
                    if (isActif)
                      Container(
                        padding:
                          const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3),
                        decoration: BoxDecoration(
                          color: agent.disponibilite
                            ? AppColors.primaryLight
                            : AppColors.amberLight,
                          borderRadius:
                            BorderRadius.circular(20),
                        ),
                        child: Text(
                          agent.disponibilite
                            ? "Disponible"
                            : "En mission",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: agent.disponibilite
                              ? AppColors.primary
                              : AppColors.amber,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Compétences ─────────────────────────────
          if (agent.competences.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_outline,
                    size: 14,
                    color: AppColors.textSecond),
                  const SizedBox(width: 6),
                  Text(agent.competences,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecond,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Actions ─────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
            child: Row(
              children: [

                // Toggle disponibilité
                if (isActif) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                        _changerDisponibilite(
                          agent.id,
                          !agent.disponibilite),
                      child: Container(
                        padding:
                          const EdgeInsets.symmetric(
                            vertical: 8),
                        decoration: BoxDecoration(
                          color: agent.disponibilite
                            ? AppColors.amberLight
                            : AppColors.greenLight,
                          borderRadius:
                            BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment:
                            MainAxisAlignment.center,
                          children: [
                            Icon(
                              agent.disponibilite
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                              size: 16,
                              color: agent.disponibilite
                                ? AppColors.amber
                                : AppColors.green),
                            const SizedBox(width: 6),
                            Text(
                              agent.disponibilite
                                ? "Mettre en mission"
                                : "Rendre disponible",
                              style:
                                GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight:
                                    FontWeight.w500,
                                  color: agent
                                    .disponibilite
                                    ? AppColors.amber
                                    : AppColors.green,
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Désactiver/Réactiver
                GestureDetector(
                  onTap: () => isActif
                    ? _showConfirmDialog(
                        "Désactiver ${agent.nomComplet} ?",
                        "Il ne pourra plus être assigné.",
                        () => _desactiver(agent.id))
                    : _reactiver(agent.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActif
                        ? const Color(0xFFFCEBEB)
                        : AppColors.greenLight,
                      borderRadius:
                        BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActif
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                          size: 16,
                          color: isActif
                            ? Colors.red
                            : AppColors.green),
                        const SizedBox(width: 4),
                        Text(
                          isActif
                            ? "Désactiver"
                            : "Réactiver",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isActif
                              ? Colors.red
                              : AppColors.green,
                          ),
                        ),
                      ],
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

  // ── Dialog ajouter agent ───────────────────────────
  void _showAjouterAgentDialog() {
    final _nomCtrl    = TextEditingController();
    final _prenomCtrl = TextEditingController();
    final _emailCtrl  = TextEditingController();
    final _telCtrl    = TextEditingController();
    final _motoCtrl   = TextEditingController();
    final _compCtrl   = TextEditingController();
    final _formKey    = GlobalKey<FormState>();
    bool  _isSaving   = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) =>
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx)
                .viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                    CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Titre
                    Row(
                      mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Ajouter un agent",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                            Navigator.pop(ctx)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Champs du formulaire
                    _buildField(
                      controller: _prenomCtrl,
                      label: "Prénom",
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _nomCtrl,
                      label: "Nom",
                      icon: Icons.person_outline,
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _emailCtrl,
                      label: "Email",
                      icon: Icons.email_outlined,
                      required: true,
                      keyboardType:
                        TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _telCtrl,
                      label: "Téléphone",
                      icon: Icons.phone_outlined,
                      required: true,
                      keyboardType:
                        TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _motoCtrl,
                      label: "Matricule moto (optionnel)",
                      icon: Icons.two_wheeler,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _compCtrl,
                      label: "Compétences",
                      icon: Icons.star_outline,
                      hint: "Ex: Collecte, Livraison",
                    ),

                    const SizedBox(height: 20),

                    // Bouton enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style:
                          ElevatedButton.styleFrom(
                            backgroundColor:
                              AppColors.green,
                            foregroundColor:
                              Colors.white,
                          ),
                        onPressed: _isSaving
                          ? null
                          : () async {
                              if (!_formKey
                                .currentState!
                                .validate()) return;

                              setStateModal(() =>
                                _isSaving = true);

                              try {
                                final token =
                                  await AuthStorage
                                    .getToken();
                                final userId =
                                  await AuthStorage
                                    .getUserId();

                                final response =
                                  await http.post(
                                    Uri.parse(
                                      '${ApiConstants.baseUrl}'
                                      '/agent/prestataire'
                                      '/$userId'),
                                    headers: {
                                      'Content-Type':
                                        'application/json',
                                      'Authorization':
                                        'Bearer $token',
                                    },
                                    body: jsonEncode({
                                      'nom':
                                        _nomCtrl.text,
                                      'prenom':
                                        _prenomCtrl.text,
                                      'email':
                                        _emailCtrl.text,
                                      'telephone':
                                        _telCtrl.text,
                                      'motoMatricule':
                                        _motoCtrl.text,
                                      'competences':
                                        _compCtrl.text,
                                    }),
                                  );

                                if (response
                                    .statusCode == 200) {
                                  Navigator.pop(ctx);
                                  _loadAgents();
                                  if (mounted) {
                                    ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "✅ Agent ajouté !",
                                            style:
                                              GoogleFonts
                                                .poppins(
                                                fontSize:
                                                  12)),
                                          backgroundColor:
                                            AppColors
                                              .green,
                                          behavior:
                                            SnackBarBehavior
                                              .floating,
                                        ),
                                      );
                                  }
                                }
                              } catch (e) {
                                setStateModal(() =>
                                  _isSaving = false);
                              }
                            },
                        child: _isSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child:
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : Text("Enregistrer l'agent",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight:
                                  FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
      ),
    );
  }

  // ── Champ formulaire ──────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13),
      validator: required
        ? (v) => v == null || v.isEmpty
            ? "Champ obligatoire" : null
        : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12, color: AppColors.textSecond),
        prefixIcon: Icon(icon,
          color: AppColors.green, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.green, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 12),
      ),
    );
  }

  // ── Dialog confirmation ────────────────────────────
  void _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
        title: Text(title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600)),
        content: Text(message,
          style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler",
              style: GoogleFonts.poppins(
                color: AppColors.textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text("Confirmer",
              style: GoogleFonts.poppins(
                fontSize: 13))),
        ],
      ),
    );
  }
}