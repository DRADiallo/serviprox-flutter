import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class PrestataireStatistiquesScreen
    extends StatefulWidget {
  const PrestataireStatistiquesScreen({super.key});

  @override
  State<PrestataireStatistiquesScreen> createState()
      => _PrestataireStatistiquesScreenState();
}

class _PrestataireStatistiquesScreenState
    extends State<PrestataireStatistiquesScreen> {

  bool _isLoading = true;
  int _totalCommandes  = 0;
  int _totalCloturees  = 0;
  int _totalEnCours    = 0;
  int _totalAnnulees   = 0;
  double _chiffreAffaires = 0;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final token  = await AuthStorage.getToken();
      final userId = await AuthStorage.getUserId();

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.commandes}'
          '/prestataire/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);

        int cloturees = 0, enCours = 0,
            annulees = 0;
        double ca = 0;

        for (final cmd in data) {
          final statut = cmd['statut'] ?? '';
          final montant =
            (cmd['montantTotal'] ?? 0).toDouble();

          if (statut == 'CLOTUREE') {
            cloturees++;
            ca += montant;
          } else if (statut == 'EN_TRAITEMENT' ||
                     statut == 'CONFIRMEE') {
            enCours++;
          } else if (statut == 'ANNULEE') {
            annulees++;
          }
        }

        setState(() {
          _totalCommandes = data.length;
          _totalCloturees = cloturees;
          _totalEnCours   = enCours;
          _totalAnnulees  = annulees;
          _chiffreAffaires = ca;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Statistiques",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.green))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [

                // Chiffre d'affaires
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius:
                      BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment:
                      CrossAxisAlignment.start,
                    children: [
                      Text("Chiffre d'affaires",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_chiffreAffaires.toInt()} FCFA",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Commandes clôturées",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ← AJOUT : Diagramme circulaire
              Text("Répartition des commandes",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    // ← Diagramme
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _sections,
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (response == null ||
                                    response.touchedSection ==
                                      null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = response
                                  .touchedSection!
                                  .touchedSectionIndex;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Total
                    Text(
                      "$_totalCommandes commandes au total",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Légende
                    Row(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        _legende(
                          "Clôturées",
                          AppColors.green,
                          _totalCloturees),
                        const SizedBox(width: 16),
                        _legende(
                          "En cours",
                          AppColors.amber,
                          _totalEnCours),
                        const SizedBox(width: 16),
                        _legende(
                          "Annulées",
                          Colors.red,
                          _totalAnnulees),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

                // Stats commandes
                Text("Commandes",
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
                  physics:
                    const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard(
                      "$_totalCommandes",
                      "Total",
                      Icons.list_alt_outlined,
                      AppColors.primary,
                      AppColors.primaryLight,
                    ),
                    _buildStatCard(
                      "$_totalCloturees",
                      "Clôturées",
                      Icons.check_circle_outline,
                      AppColors.green,
                      AppColors.greenLight,
                    ),
                    _buildStatCard(
                      "$_totalEnCours",
                      "En cours",
                      Icons.hourglass_empty,
                      AppColors.amber,
                      AppColors.amberLight,
                    ),
                    _buildStatCard(
                      "$_totalAnnulees",
                      "Annulées",
                      Icons.cancel_outlined,
                      Colors.red,
                      const Color(0xFFFCEBEB),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Taux de succès
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                      BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment:
                      CrossAxisAlignment.start,
                    children: [
                      Text("Taux de succès",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius:
                          BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _totalCommandes > 0
                            ? _totalCloturees /
                              _totalCommandes
                            : 0,
                          backgroundColor:
                            AppColors.background,
                          color: AppColors.green,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _totalCommandes > 0
                          ? "${(_totalCloturees / _totalCommandes * 100).toInt()}% de succès"
                          : "Pas encore de données",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              


              ],
            ),
          ),
    );
  }

  Widget _legende(
    String label, Color color, int count) {
  return Row(
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        "$label ($count)",
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: AppColors.textSecond,
        ),
      ),
    ],
  );
}

  Widget _buildStatCard(
    String count,
    String label,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(count,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ← AJOUT : sections du diagramme
List<PieChartSectionData> get _sections {
  if (_totalCommandes == 0) {
    return [
      PieChartSectionData(
        value: 1,
        color: AppColors.border,
        title: 'Aucune',
        radius: 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }
  return [
    if (_totalCloturees > 0)
      PieChartSectionData(
        value: _totalCloturees.toDouble(),
        color: AppColors.green,
        title: '$_totalCloturees',
        radius: _touchedIndex == 0 ? 90 : 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    if (_totalEnCours > 0)
      PieChartSectionData(
        value: _totalEnCours.toDouble(),
        color: AppColors.amber,
        title: '$_totalEnCours',
        radius: _touchedIndex == 1 ? 90 : 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    if (_totalAnnulees > 0)
      PieChartSectionData(
        value: _totalAnnulees.toDouble(),
        color: Colors.red,
        title: '$_totalAnnulees',
        radius: _touchedIndex == 2 ? 90 : 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
  ];
}
}