import 'package:flutter/material.dart';

/// Shared visual language, lifted from the Home screen's palette
/// (lib/ui_layer/view/home/home.dart) so every screen in the app reads as
/// one product instead of a set of default Material widgets.
class AppColors {
  AppColors._();

  static const background = Color(0xFFFFF9ED);
  static const surface = Color(0xFFFFFDF3);
  static const border = Color(0xFFE9E2D7);

  static const heroGradientStart = Color(0xFF08A8AD);
  static const heroGradientEnd = Color(0xFF146BD9);

  static const textPrimary = Color(0xFF14213D);
  static const textSecondary = Color(0xFF667085);
  static const accentTeal = Color(0xFF0093A3);

  static const success = Color(0xFF009F8C);
  static const successBackground = Color(0xFFDDFDF5);

  static const info = Color(0xFF315CD6);
  static const infoBackground = Color(0xFFE9ECFF);

  static const warning = Color(0xFFE69B00);
  static const warningBackground = Color(0xFFFFF2C7);

  static const danger = Color(0xFFFF4057);
  static const dangerBackground = Color(0xFFFFE3E6);
}

class AppText {
  AppText._();

  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 11.5,
    color: AppColors.textSecondary,
  );
}

/// Rounded card used across alert / inbox / admin screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The blue/teal gradient card style used by Home's hero section.
class AppGradientCard extends StatelessWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.heroGradientStart,
            AppColors.heroGradientEnd,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Small rounded pill, used for filter chips and status tags.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.selected = true,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? background : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? background : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? foreground : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? foreground : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered icon + message used for empty/error states.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
