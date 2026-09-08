import 'package:flutter/material.dart';

import '../../view_model/settings/app_settings_controller.dart';
import '../cultural_map/cultural_map.dart';
import '../home/home.dart';
import '../home/profile.dart';
import '../outfit_recognition/outfit_recognition.dart';

class CultureGuideBottomNav extends StatelessWidget {
  final int currentIndex;

  const CultureGuideBottomNav({
    super.key,
    required this.currentIndex,
  });

  void _open(
    BuildContext context,
    int index,
  ) {
    if (index == currentIndex) {
      return;
    }

    final Widget page = switch (index) {
      0 => const HomeView(),
      1 => const CulturalMapView(),
      2 => const OutfitRecognitionView(),
      _ => const ProfileView(),
    };

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => page,
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        AppSettingsController.instance;

    final colorScheme =
        Theme.of(context).colorScheme;

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        10,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainer
            : Colors.white,
        borderRadius:
            BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.24 : 0.08,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _item(
                context,
                index: 0,
                icon: Icons.home_rounded,
                label: settings.text(
                  en: 'Home',
                  zh: '主页',
                  ms: 'Utama',
                ),
              ),
              _item(
                context,
                index: 1,
                icon: Icons.explore_outlined,
                label: settings.text(
                  en: 'Explore',
                  zh: '探索',
                  ms: 'Teroka',
                ),
              ),
              _item(
                context,
                index: 2,
                icon: Icons.checkroom_outlined,
                label: settings.text(
                  en: 'Outfit',
                  zh: '穿搭',
                  ms: 'Pakaian',
                ),
              ),
              _item(
                context,
                index: 3,
                icon: Icons.person_outline_rounded,
                label: settings.text(
                  en: 'Profile',
                  zh: '我的',
                  ms: 'Profil',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected =
        index == currentIndex;

    final colorScheme =
        Theme.of(context).colorScheme;

    final color = selected
        ? const Color(0xFF00A77E)
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => _open(
        context,
        index,
      ),
      borderRadius:
          BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: 37,
              height: 31,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(
                        0xFF00A77E,
                      ).withValues(
                        alpha: 0.12,
                      )
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
