import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ⚠️  Adaptez ces chemins selon votre structure de projet
import 'package:memoireserviprox/core/constants/app_colors.dart';
import 'package:memoireserviprox/core/constants/api_constants.dart';

// =============================================
// SERVICES À DOMICILE — avecAgent=false
// Flux : CREE → CONFIRMEE → EN_TRAITEMENT → TRAITEMENT_TERMINE → CLOTUREE
// 2 acteurs : Client ↔ Prestataire
// Couverts : ménage, coiffure, plomberie, nettoyage bureaux, etc.
// Couleurs : AppColors.purple / AppColors.purpleLight
// =============================================

class SoinsScreen extends StatefulWidget {
  const SoinsScreen({super.key});

  @override
  State<SoinsScreen> createState() => _SoinsScreenState();
}

class _SoinsScreenState extends State<SoinsScreen>
    with TickerProviderStateMixin {

  // Couleur header gradient — variante sombre non définie dans AppColors
  static const Color _headerDark = Color(0xFF4A148C);

  // ─── Contrôleurs & état ───────────────────────────────────────
  final _adresseCtrl    = TextEditingController();
  final _precisionsCtrl = TextEditingController();

  List<String>               _sousTypes    = [];
  String?                    _selectedType;
  DateTime?                  _dateRdv;
  TimeOfDay?                 _heureRdv;
  List<Map<String, dynamic>> _prestataires = [];
  bool                       _isLoading    = true;
  bool                       _isSubmitting = false;
  String?                    _token;
  String?                    _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // ─── Mois en français (sans dépendance intl) ─────────────────
  static const _mois = ['Jan','Fév','Mar','Avr','Mai','Jun',
                         'Jul','Aoû','Sep','Oct','Nov','Déc'];

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mois[d.month - 1]} ${d.year}';

  // ─── Cycle de vie ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await Future.wait([_loadConfig(), _loadPrestataires()]);
    _animCtrl.forward();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.servicesActifs),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List<dynamic> configs = json.decode(res.body);
        final matching = configs
            .where((c) => c['typeService'] == 'domicile')
            .toList();
        if (matching.isNotEmpty && matching.first['sousTypes'] != null) {
          final raw =
              json.decode(matching.first['sousTypes'] as String) as List;
          if (mounted) setState(() => _sousTypes = raw.cast<String>());
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPrestataires() async {
    try {
      // ⚠️  Vérifiez que l'endpoint /par-service existe dans votre backend
      final url =
          '${ApiConstants.prestataires}/par-service?typeService=domicile';
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _prestataires = data.cast<Map<String, dynamic>>();
          _isLoading    = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg  = 'Erreur réseau. Vérifiez votre connexion.';
      });
    }
  }

  Map<String, String> _headers() => {
    if (_token != null) 'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  // ─── Pickers date / heure ─────────────────────────────────────
  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateRdv ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.purple,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _dateRdv = picked);
  }

  Future<void> _pickHeure() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _heureRdv ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.purple,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _heureRdv = picked);
  }

  // ─── Soumission commande ──────────────────────────────────────
  Future<void> _soumettreCommande(Map<String, dynamic> prestataire) async {
    if (_selectedType == null) {
      _snack('Sélectionnez le type de service', Colors.orange);
      return;
    }
    if (_dateRdv == null) {
      _snack('Choisissez une date de rendez-vous', Colors.orange);
      return;
    }
    if (_heureRdv == null) {
      _snack('Choisissez une heure de rendez-vous', Colors.orange);
      return;
    }
    if (_adresseCtrl.text.trim().isEmpty) {
      _snack('Renseignez votre adresse', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final rdv = DateTime(
        _dateRdv!.year, _dateRdv!.month, _dateRdv!.day,
        _heureRdv!.hour, _heureRdv!.minute,
      );

      final body = <String, dynamic>{
        'prestataireId'  : prestataire['id'],
        'typeService'    : 'domicile',
        'sousType'       : _selectedType,
        'dateRdv'        : rdv.toIso8601String(),
        'adresseDomicile': _adresseCtrl.text.trim(),
        if (_precisionsCtrl.text.trim().isNotEmpty)
          'precisions': _precisionsCtrl.text.trim(),
      };

      final res = await http.post(
        Uri.parse(ApiConstants.commandes),
        headers: _headers(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('✅ Demande envoyée ! Le prestataire va confirmer.',
            Colors.green, duration: 4);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.pop();
      } else {
        _snack('❌ Erreur ${res.statusCode}. Réessayez.', Colors.red);
      }
    } catch (e) {
      _snack('❌ Erreur réseau', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, Color bg, {int duration = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: duration),
    ));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _adresseCtrl.dispose();
    _precisionsCtrl.dispose();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSousTypesCard(),
                    const SizedBox(height: 14),
                    _buildDateHeureCard(),
                    const SizedBox(height: 14),
                    _buildAdresseCard(),
                    const SizedBox(height: 14),
                    _buildPrecisionsCard(),
                    const SizedBox(height: 24),
                    _buildPrestataireSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: AppColors.purple,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.purple, _headerDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 10),
                const Text('Services à domicile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    )),
                const Text(
                    'Ménage, coiffure, plomberie, nettoyage — chez vous',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Carte : Type de service ──────────────────────────────────
  Widget _buildSousTypesCard() {
    return _card(
      icon: Icons.miscellaneous_services_rounded,
      title: 'Type de service',
      child: _sousTypes.isEmpty
          ? _infoBox(
              'Le prestataire n\'a pas encore configuré ses types de services. '
              'Précisez votre besoin dans le champ "Précisions".',
              AppColors.purple)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sousTypes
                  .map((t) => _chip(t, _selectedType == t,
                      () => setState(() => _selectedType = t)))
                  .toList(),
            ),
    );
  }

  // ─── Carte : Date & Heure ─────────────────────────────────────
  Widget _buildDateHeureCard() {
    return _card(
      icon: Icons.calendar_today_rounded,
      title: 'Date & heure du rendez-vous',
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: _rdvPicker(
              icon: Icons.date_range_rounded,
              label: _dateRdv != null ? _formatDate(_dateRdv!) : 'Sélectionner',
              active: _dateRdv != null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _pickHeure,
            child: _rdvPicker(
              icon: Icons.access_time_rounded,
              label: _heureRdv != null
                  ? _heureRdv!.format(context)
                  : 'Heure',
              active: _heureRdv != null,
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Carte : Adresse ─────────────────────────────────────────
  Widget _buildAdresseCard() {
    return _card(
      icon: Icons.home_rounded,
      title: 'Adresse d\'intervention',
      child: TextField(
        controller: _adresseCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDeco('Ex : HLM Villa 23, Ziguinchor').copyWith(
            prefixIcon:
                const Icon(Icons.place_rounded, color: AppColors.purple)),
      ),
    );
  }

  // ─── Carte : Précisions ───────────────────────────────────────
  Widget _buildPrecisionsCard() {
    return _card(
      icon: Icons.edit_note_rounded,
      title: 'Précisions (optionnel)',
      child: TextField(
        controller: _precisionsCtrl,
        maxLines: 3,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _inputDeco(
            'Ex : Appartement F3 au 2ème étage, 4 pièces à nettoyer…'),
      ),
    );
  }

  // ─── Section prestataires ─────────────────────────────────────
  Widget _buildPrestataireSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Prestataires disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.purple)),
          const SizedBox(width: 8),
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${_prestataires.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child:
                      CircularProgressIndicator(color: AppColors.purple)))
        else if (_errorMsg != null)
          _infoBox(_errorMsg!, Colors.red)
        else if (_prestataires.isEmpty)
          _emptyState(
              'Aucun prestataire disponible\npour les services à domicile')
        else
          ..._prestataires.map(_prestataireCard),
      ],
    );
  }

  Widget _prestataireCard(Map<String, dynamic> p) {
    final nom      = p['nomBoutique'] ?? p['nom'] ?? 'Prestataire';
    final initiale = nom.isNotEmpty ? nom[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.purple, _headerDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                  child: Text(initiale,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                  if (p['adresse'] != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.place_rounded,
                          size: 13, color: AppColors.textSecond),
                      const SizedBox(width: 3),
                      Flexible(
                          child: Text(p['adresse'],
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecond),
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  if (p['note'] != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 15),
                      Text(' ${p['note']}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ]),
                  ],
                ],
              ),
            ),
            // Bouton
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _soumettreCommande(p),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Prendre RDV',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets helpers ──────────────────────────────────────────

  Widget _card(
      {required IconData icon,
      required String title,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.purple, size: 18),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _rdvPicker(
      {required IconData icon,
      required String label,
      required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.purpleLight : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: active ? AppColors.purple : AppColors.border,
            width: active ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icon,
            color: active ? AppColors.purple : AppColors.textMuted,
            size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: active ? AppColors.purple : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : AppColors.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: selected ? AppColors.purple : AppColors.border,
              width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.purple.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecond,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.purple, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _infoBox(String msg, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(color: color, fontSize: 12.5))),
        ]),
      );

  Widget _emptyState(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.border),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, height: 1.5)),
          ]),
        ),
      );
}