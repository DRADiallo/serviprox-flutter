import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_storage.dart';

class PhotoPreuveScreen extends StatefulWidget {
  final int commandeId;
  final String typePreuve;
  final String titre;

  const PhotoPreuveScreen({
    super.key,
    required this.commandeId,
    required this.typePreuve,
    required this.titre,
  });

  @override
  State<PhotoPreuveScreen> createState() =>
      _PhotoPreuveScreenState();
}

class _PhotoPreuveScreenState
    extends State<PhotoPreuveScreen> {

  // ── Variables ─────────────────────────────────────
  String? _photoBase64;
  bool _isLoading  = false;
  bool _isUploading = false;
  String _statut    = 'OK';
  final _commentaireController =
    TextEditingController();
    

  @override
  void dispose() {
    _commentaireController.dispose();
    super.dispose();
  }

  // ── Prendre photo (Web) ───────────────────────────
  final ImagePicker _picker = ImagePicker();

Future<void> _prendrePhoto() async {
  try {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final base64Str = base64Encode(bytes);

    setState(() => _photoBase64 = base64Str);

    // ← SUPPRIMER Future.delayed
    // ← Afficher preview directement
    if (mounted) _voirPhotoEnGrand();

  } catch (e) {
    debugPrint("Erreur: $e");
  }
}

  // ── Envoyer la preuve ─────────────────────────────
 Future<void> _envoyerPreuve() async {
  if (_photoBase64 == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Prenez une photo d'abord !",
          style: GoogleFonts.poppins(
            fontSize: 12)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  setState(() => _isUploading = true);

  try {
    final token  = await AuthStorage.getToken();
    final userId = await AuthStorage.getUserId();

    // ← CORRECTION : photo dans body !
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/preuve'
        '/commande/${widget.commandeId}'
        '?typePreuve=${widget.typePreuve}'
        '&acteurId=$userId'
        '&statut=$_statut'
        '&commentaire=${Uri.encodeComponent(_commentaireController.text.trim())}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      // ← Photo dans body JSON
      body: jsonEncode({
        'photoBase64': _photoBase64,
      }),
    );

    setState(() => _isUploading = false);

    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Preuve enregistrée !",
              style: GoogleFonts.poppins(
                fontSize: 12)),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Erreur : ${response.statusCode}",
              style: GoogleFonts.poppins(
                fontSize: 12)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    setState(() => _isUploading = false);
    debugPrint("Erreur preuve: $e");
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
            Icons.arrow_back,
            color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.titre,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
            CrossAxisAlignment.start,
          children: [

            // ── Info type preuve ──────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                  BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getInstructions(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Zone photo ────────────────────────
            // ← Remplacer la zone photo
            GestureDetector(
              onTap: _photoBase64 != null
                ? _voirPhotoEnGrand
                : _prendrePhoto,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _photoBase64 != null
                      ? AppColors.green
                      : AppColors.border,
                    width: _photoBase64 != null ? 2 : 1)),
                child: _photoBase64 != null
                  ? Stack(
                      children: [
                        // ← Photo
                        ClipRRect(
                          borderRadius:
                            BorderRadius.circular(13),
                          child: Image.memory(
                            base64Decode(_photoBase64!),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // ← Badge "Appuyez pour voir"
                        Positioned(
                          bottom: 8, right: 8,
                          child: Container(
                            padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black
                                .withValues(alpha: 0.6),
                              borderRadius:
                                BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  "Voir en grand",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ← Badge OK
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius:
                                BorderRadius.circular(20)),
                            child: Text(
                              "✅ Photo prise",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            shape: BoxShape.circle),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 30,
                            color: AppColors.green),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Appuyez pour prendre\nune photo",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecond,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "La photo sera compressée\nautomatiquement",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
              ),
            ),

            const SizedBox(height: 12),

            // ← Bouton reprendre photo
            if (_photoBase64 != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                      AppColors.textSecond,
                    side: const BorderSide(
                      color: AppColors.border),
                  ),
                  onPressed: _prendrePhoto,
                  icon: const Icon(
                    Icons.refresh, size: 16),
                  label: Text(
                    "Reprendre la photo",
                    style: GoogleFonts.poppins(
                      fontSize: 12)),
                ),
              ),

            const SizedBox(height: 16),

            // ── Statut ────────────────────────────
            Text("État des articles",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _statut = 'OK'),
                    child: Container(
                      padding: const EdgeInsets
                        .symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _statut == 'OK'
                          ? AppColors.greenLight
                          : Colors.white,
                        borderRadius:
                          BorderRadius.circular(10),
                        border: Border.all(
                          color: _statut == 'OK'
                            ? AppColors.green
                            : AppColors.border,
                          width: _statut == 'OK'
                            ? 1.5 : 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _statut == 'OK'
                              ? AppColors.green
                              : AppColors.textMuted,
                            size: 18),
                          const SizedBox(width: 6),
                          Text("Tout est OK",
                            style:
                              GoogleFonts.poppins(
                                fontSize: 12,
                                color:
                                  _statut == 'OK'
                                    ? AppColors.green
                                    : AppColors
                                        .textSecond,
                                fontWeight:
                                  FontWeight.w500,
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _statut = 'PROBLEME'),
                    child: Container(
                      padding: const EdgeInsets
                        .symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _statut == 'PROBLEME'
                          ? const Color(0xFFFCEBEB)
                          : Colors.white,
                        borderRadius:
                          BorderRadius.circular(10),
                        border: Border.all(
                          color:
                            _statut == 'PROBLEME'
                              ? Colors.red
                              : AppColors.border,
                          width:
                            _statut == 'PROBLEME'
                              ? 1.5 : 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color:
                              _statut == 'PROBLEME'
                                ? Colors.red
                                : AppColors.textMuted,
                            size: 18),
                          const SizedBox(width: 6),
                          Text("Problème",
                            style:
                              GoogleFonts.poppins(
                                fontSize: 12,
                                color:
                                  _statut == 'PROBLEME'
                                    ? Colors.red
                                    : AppColors
                                        .textSecond,
                                fontWeight:
                                  FontWeight.w500,
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Commentaire ───────────────────────
            Text("Commentaire",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _commentaireController,
              maxLines: 3,
              style: GoogleFonts.poppins(
                fontSize: 13),
              decoration: InputDecoration(
                hintText: _statut == 'PROBLEME'
                  ? "Décrivez le problème..."
                  : "Commentaire optionnel...",
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                    BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                    BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _statut == 'PROBLEME'
                      ? Colors.red
                      : AppColors.green,
                    width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Bouton envoyer ────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                    _statut == 'PROBLEME'
                      ? Colors.red
                      : AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                      BorderRadius.circular(12)),
                ),
                onPressed: _isUploading
                  ? null : _envoyerPreuve,
                icon: _isUploading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child:
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2))
                  : Icon(
                      _statut == 'PROBLEME'
                        ? Icons.warning_amber
                        : Icons.upload_outlined,
                      size: 18),
                label: Text(
                  _isUploading
                    ? "Envoi en cours..."
                    : _statut == 'PROBLEME'
                      ? "Signaler le problème"
                      : "Enregistrer la preuve",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }


  // ← AJOUT : Voir photo en grand avant envoi
void _voirPhotoEnGrand() {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          // ← Photo plein écran
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              base64Decode(_photoBase64!),
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),

          // ← Bouton fermer
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black
                    .withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20),
              ),
            ),
          ),

          // ← Actions bas
          Positioned(
            bottom: 16,
            left: 16, right: 16,
            child: Row(
              children: [
                // ← Reprendre photo
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Colors.white),
                      padding:
                        const EdgeInsets.symmetric(
                          vertical: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      _prendrePhoto();
                    },
                    icon: const Icon(
                      Icons.refresh, size: 16),
                    label: Text(
                      "Reprendre",
                      style: GoogleFonts.poppins(
                        fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                // ← Valider photo
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                        AppColors.green,
                      foregroundColor: Colors.white,
                      padding:
                        const EdgeInsets.symmetric(
                          vertical: 12)),
                    onPressed: () =>
                      Navigator.pop(context),
                    icon: const Icon(
                      Icons.check, size: 16),
                    label: Text(
                      "✅ Photo OK !",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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

  // ── Instructions selon type ───────────────────────
  String _getInstructions() {
    switch (widget.typePreuve) {
      case 'COLLECTE_CLIENT':
        return "📸 Photographiez tous les articles "
          "du client AVANT de les prendre. "
          "Cette photo sera la référence.";
      case 'RECEPTION_PRESTATAIRE':
        return "📸 Photographiez les articles "
          "reçus au pressing. Comparez avec "
          "la photo de collecte.";
      case 'LIVRAISON_CLIENT':
        return "📸 Photographiez les articles "
          "après traitement AVANT de livrer. "
          "Le client pourra comparer.";
      case 'AVANT_INTERVENTION':
        return "📸 Photographiez l'état initial "
          "avant votre intervention.";
      case 'APRES_INTERVENTION':
        return "📸 Photographiez le résultat "
          "final de votre intervention.";
      default:
        return "📸 Prenez une photo comme preuve.";
    }
  }
}