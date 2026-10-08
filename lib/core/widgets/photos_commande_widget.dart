// lib/core/widgets/photos_commande_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../constants/api_constants.dart';
import '../services/auth_storage.dart';

class PhotosCommandeWidget extends StatelessWidget {
  final int commandeId;

  const PhotosCommandeWidget({
    super.key,
    required this.commandeId,
  });

  Future<List<dynamic>> _loadPreuves(
      String token) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/preuve'
        '/commande/$commandeId'),
      headers: {
        'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthStorage.getToken(),
      builder: (ctx, tokenSnap) {
        if (!tokenSnap.hasData) {
          return const SizedBox.shrink();
        }
        return FutureBuilder<List<dynamic>>(
          future: _loadPreuves(tokenSnap.data!),
          builder: (ctx, snap) {
            if (!snap.hasData ||
                snap.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final preuves = snap.data!;

            return Column(
              crossAxisAlignment:
                CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text("📸 Photos de la commande",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: preuves.length,
                    itemBuilder: (_, i) {
                      final p = preuves[i];
                      final photo = p['contenu'];
                      final type = p['type'] ?? '';
                      final statut =
                        p['statut'] ?? 'OK';

                      return GestureDetector(
                        onTap: () =>
                          _voirPhotoEnGrand(
                            context, p),
                        child: Container(
                          width: 110,
                          margin:
                            const EdgeInsets
                              .only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius:
                              BorderRadius
                                .circular(12),
                            border: Border.all(
                              color: statut == 'OK'
                                ? AppColors.green
                                : Colors.red,
                              width: 1.5)),
                          child: ClipRRect(
                            borderRadius:
                              BorderRadius
                                .circular(11),
                            child: Stack(
                              children: [
                                // ← Photo
                                photo != null &&
                                photo.toString()
                                  .isNotEmpty
                                ? Image.memory(
                                    base64Decode(
                                      photo.toString()),
                                    width: 110,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppColors
                                      .background,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: AppColors
                                        .textMuted),
                                  ),

                                // ← Label type
                                Positioned(
                                  bottom: 0,
                                  left: 0, right: 0,
                                  child: Container(
                                    padding:
                                      const EdgeInsets
                                        .symmetric(
                                          vertical: 4),
                                    color: Colors.black
                                      .withValues(
                                        alpha: 0.6),
                                    child: Text(
                                      _getLabelType(
                                        type),
                                      textAlign:
                                        TextAlign.center,
                                      style:
                                        GoogleFonts
                                          .poppins(
                                            fontSize: 9,
                                            color:
                                              Colors.white,
                                          ),
                                    ),
                                  ),
                                ),

                                // ← Zoom icon
                                const Positioned(
                                  top: 6, right: 6,
                                  child: Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ← Voir photo en grand
  void _voirPhotoEnGrand(
      BuildContext context,
      Map<String, dynamic> preuve) {
    final photo = preuve['contenu'];
    final type = preuve['type'] ?? '';
    final statut = preuve['statut'] ?? 'OK';
    final commentaire =
      preuve['commentaire'] ?? '';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // ← Photo plein écran
            photo != null &&
            photo.toString().isNotEmpty
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  base64Decode(
                    photo.toString()),
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              )
            : const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
                  size: 60)),

            // ← Header infos
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black
                        .withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding:
                        const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4),
                      decoration: BoxDecoration(
                        color: statut == 'OK'
                          ? AppColors.green
                          : Colors.red,
                        borderRadius:
                          BorderRadius.circular(20)),
                      child: Text(
                        _getLabelType(type),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // ← Fermer
                    GestureDetector(
                      onTap: () =>
                        Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black
                            .withValues(alpha: 0.6),
                          shape: BoxShape.circle),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ← Commentaire en bas
            if (commentaire.isNotEmpty)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black
                          .withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    commentaire,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getLabelType(String type) {
    switch (type) {
      case 'COLLECTE_CLIENT':
        return "🏠 Collecte";
      case 'RECEPTION_PRESTATAIRE':
        return "🏪 Réception";
      case 'LIVRAISON_CLIENT':
        return "🛵 Livraison";
      default:
        return type;
    }
  }
}