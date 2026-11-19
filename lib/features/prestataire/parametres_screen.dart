// lib/features/prestataire/parametres_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memoireserviprox/core/controllers/SettingsProvider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
//import '../../core/controllers/settings.dart';
import '../../core/services/auth_storage.dart';

class ParametresScreen extends StatelessWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch : rebuild auto quand le provider notifie
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Paramètres",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── APPARENCE ──────────────────────────────────
            const _SectionTitle("APPARENCE"),
            const SizedBox(height: 8),
            _Card(
              children: [
                _ChoiceOption(
                  icon: Icons.light_mode_outlined,
                  label: "Mode clair",
                  iconBg: const Color(0xFFFFF3E0),
                  iconColor: const Color(0xFFE65100),
                  selected: settings.themeMode == 'light',
                  onTap: () => context.read<SettingsProvider>().setTheme('light'),
                ),
                const _Divider(),
                _ChoiceOption(
                  icon: Icons.dark_mode_outlined,
                  label: "Mode sombre",
                  iconBg: const Color(0xFF2C2C3E),
                  iconColor: Colors.white,
                  selected: settings.themeMode == 'dark',
                  onTap: () => context.read<SettingsProvider>().setTheme('dark'),
                ),
                const _Divider(),
                _ChoiceOption(
                  icon: Icons.phone_android_outlined,
                  label: "Selon le système",
                  iconBg: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  selected: settings.themeMode == 'system',
                  onTap: () => context.read<SettingsProvider>().setTheme('system'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── LANGUE ─────────────────────────────────────
            const _SectionTitle("LANGUE"),
            const SizedBox(height: 8),
            _Card(
              children: [
                _LangOption(
                  flag: "🇫🇷",
                  label: "Français",
                  code: 'fr',
                  selected: settings.locale == 'fr',
                  onTap: () => context.read<SettingsProvider>().setLocale('fr'),
                ),
                const _Divider(),
                _LangOption(
                  flag: "🇬🇧",
                  label: "English",
                  code: 'en',
                  selected: settings.locale == 'en',
                  onTap: () => context.read<SettingsProvider>().setLocale('en'),
                ),
                const _Divider(),
                _LangOption(
                  flag: "🇸🇦",
                  label: "العربية",
                  code: 'ar',
                  selected: settings.locale == 'ar',
                  onTap: () => context.read<SettingsProvider>().setLocale('ar'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── NOTIFICATIONS ───────────────────────────────
            const _SectionTitle("NOTIFICATIONS"),
            const SizedBox(height: 8),
            _Card(
              children: [
                SwitchListTile(
                  value: settings.notifEnabled,
                  onChanged: (val) =>
                      context.read<SettingsProvider>().setNotif(val),
                  activeColor: AppColors.green,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: settings.notifEnabled
                          ? AppColors.greenLight
                          : AppColors.border.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      settings.notifEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: settings.notifEnabled
                          ? AppColors.green
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    "Notifications push",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    settings.notifEnabled ? "Activées" : "Désactivées",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecond),
                  ),
                ),
                const _Divider(),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.email_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text("Notifications e-mail",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  subtitle: Text("À implémenter",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.lock_outline,
                      color: AppColors.textMuted, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── COMPTE ──────────────────────────────────────
            const _SectionTitle("COMPTE"),
            const SizedBox(height: 8),
            _Card(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_outlined,
                        color: AppColors.red, size: 20),
                  ),
                  title: Text(
                    "Se déconnecter",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.red,
                    ),
                  ),
                  subtitle: Text(
                    "Revenir à l'écran de connexion",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecond),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.red, size: 20),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── À PROPOS ────────────────────────────────────
            const _SectionTitle("À PROPOS"),
            const SizedBox(height: 8),
            _Card(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: AppColors.green, size: 20),
                  ),
                  title: Text("Version",
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  trailing: Text("1.0.0",
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecond)),
                ),
                const _Divider(),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text("ServiProx",
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  subtitle: Text("Services de proximité · Sénégal",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecond)),
                ),
                const _Divider(),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_outlined,
                        color: AppColors.amber, size: 20),
                  ),
                  title: Text("Mémoire M2 GL",
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  subtitle: Text("Application logistique · 2025–2026",
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecond)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Déconnexion",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Voulez-vous vraiment vous déconnecter ?",
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Annuler",
                style: GoogleFonts.poppins(color: AppColors.textSecond)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AuthStorage.logout();
              if (context.mounted) {
                // Remplacez '/login' par votre route GoRouter de connexion
                context.go('/login');
              }
            },
            child: Text("Déconnecter",
                style:
                    GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Widgets internes
// ═══════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecond,
          letterSpacing: 1.3,
        ),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
      );
}

class _ChoiceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg, iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textSecond,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.green, size: 22)
            : const Icon(Icons.radio_button_unchecked,
                color: AppColors.border, size: 22),
      );
}

class _LangOption extends StatelessWidget {
  final String flag, label, code;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag,
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 20))),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.textPrimary : AppColors.textSecond,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.green, size: 22)
            : const Icon(Icons.radio_button_unchecked,
                color: AppColors.border, size: 22),
      );
}



// // lib/features/prestataire/parametres_screen.dart

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../../core/constants/app_colors.dart';

// class ParametresScreen extends StatefulWidget {
//   const ParametresScreen({super.key});

//   @override
//   State<ParametresScreen> createState() =>
//       _ParametresScreenState();
// }

// class _ParametresScreenState
//     extends State<ParametresScreen> {

//   // ← Mode sombre
//   bool _isDarkMode = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         backgroundColor: AppColors.green,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text("Paramètres",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment:
//             CrossAxisAlignment.start,
//           children: [

//             const SizedBox(height: 8),

//             Text("Apparence",
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textSecond,
//                 letterSpacing: 1.2,
//               ),
//             ),

//             const SizedBox(height: 8),

//             // ← Mode clair / sombre
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius:
//                   BorderRadius.circular(14),
//                 border: Border.all(
//                   color: AppColors.border,
//                   width: 0.5),
//               ),
//               child: ListTile(
//                 leading: Container(
//                   width: 40, height: 40,
//                   decoration: BoxDecoration(
//                     color: _isDarkMode
//                       ? const Color(0xFF1A1A2E)
//                       : AppColors.primaryLight,
//                     borderRadius:
//                       BorderRadius.circular(12),
//                   ),
//                   child: Icon(
//                     _isDarkMode
//                       ? Icons.dark_mode
//                       : Icons.light_mode,
//                     color: _isDarkMode
//                       ? Colors.white
//                       : AppColors.primary,
//                     size: 20),
//                 ),
//                 title: Text(
//                   _isDarkMode
//                     ? "Mode sombre"
//                     : "Mode clair",
//                   style: GoogleFonts.poppins(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//                 subtitle: Text(
//                   "Changer l'apparence de l'app",
//                   style: GoogleFonts.poppins(
//                     fontSize: 11,
//                     color: AppColors.textSecond,
//                   ),
//                 ),
//                 trailing: Switch(
//                   value: _isDarkMode,
//                   activeColor: AppColors.green,
//                   onChanged: (val) {
//                     setState(
//                       () => _isDarkMode = val);
//                     // TODO: implémenter ThemeMode
//                     ScaffoldMessenger.of(context)
//                       .showSnackBar(
//                         SnackBar(
//                           content: Text(
//                             val
//                               ? "Mode sombre activé"
//                               : "Mode clair activé",
//                             style:
//                               GoogleFonts.poppins(
//                                 fontSize: 12)),
//                           backgroundColor:
//                             AppColors.green,
//                           behavior:
//                             SnackBarBehavior.floating,
//                           duration: const Duration(
//                             seconds: 1),
//                         ),
//                       );
//                   },
//                 ),
//               ),
//             ),

//             const SizedBox(height: 24),

//             Text("À propos",
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textSecond,
//                 letterSpacing: 1.2,
//               ),
//             ),

//             const SizedBox(height: 8),

//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius:
//                   BorderRadius.circular(14),
//                 border: Border.all(
//                   color: AppColors.border,
//                   width: 0.5),
//               ),
//               child: Column(
//                 children: [
//                   ListTile(
//                     leading: Container(
//                       width: 40, height: 40,
//                       decoration: BoxDecoration(
//                         color: AppColors.greenLight,
//                         borderRadius:
//                           BorderRadius.circular(12),
//                       ),
//                       child: const Icon(
//                         Icons.info_outline,
//                         color: AppColors.green,
//                         size: 20),
//                     ),
//                     title: Text("Version",
//                       style: GoogleFonts.poppins(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     trailing: Text("1.0.0",
//                       style: GoogleFonts.poppins(
//                         fontSize: 13,
//                         color: AppColors.textSecond,
//                       ),
//                     ),
//                   ),
//                   const Divider(height: 1),
//                   ListTile(
//                     leading: Container(
//                       width: 40, height: 40,
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryLight,
//                         borderRadius:
//                           BorderRadius.circular(12),
//                       ),
//                       child: const Icon(
//                         Icons.location_on_outlined,
//                         color: AppColors.primary,
//                         size: 20),
//                     ),
//                     title: Text("ServiProx",
//                       style: GoogleFonts.poppins(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     subtitle: Text(
//                       "Services de proximité · Sénégal",
//                       style: GoogleFonts.poppins(
//                         fontSize: 11,
//                         color: AppColors.textSecond,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }