import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The gradient Do's/Don'ts card, shared between the live active alert
/// (EtiquetteAlertView) and a tapped notification's full detail
/// (NotificationDetailView) so both show etiquette guidance the same way.
class EtiquetteGuidanceCard extends StatelessWidget {
  const EtiquetteGuidanceCard({
    super.key,
    required this.attractionName,
    required this.dos,
    required this.donts,
    this.actions,
  });

  final String attractionName;
  final List<Map<String, dynamic>> dos;
  final List<Map<String, dynamic>> donts;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final hasPriority = dos.any((rule) => rule['priorityScore'] != null) ||
        donts.any((rule) => rule['priorityScore'] != null);

    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  attractionName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hasPriority)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Ordered by community-reported priority',
                style: TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ),
          const SizedBox(height: 14),

          _RuleGroup(title: "Do's", icon: Icons.check_circle_outline, rules: dos),
          const SizedBox(height: 10),
          _RuleGroup(title: "Don'ts", icon: Icons.cancel_outlined, rules: donts),

          if (actions != null) ...[
            const SizedBox(height: 16),
            actions!,
          ],
        ],
      ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({
    required this.title,
    required this.icon,
    required this.rules,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (rules.isEmpty)
            const Text(
              'No specific rules listed.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            ...rules.map(
                  (rule) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '•  ${rule['title'] ?? rule['description'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (rule['priorityScore'] != null) ...[
                      const SizedBox(width: 6),
                      PriorityBadge(
                        score: (rule['priorityScore'] as num).toDouble(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the Priority Score Module 4 (Etiquette Guidance & Violation
/// Ranking) computed for a rule at a given attraction (UC02 FR-GEA8).
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final label = score >= 80
        ? 'High'
        : score >= 50
        ? 'Med'
        : 'Low';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white70, width: 0.5),
      ),
      child: Text(
        '$label • ${score.round()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
