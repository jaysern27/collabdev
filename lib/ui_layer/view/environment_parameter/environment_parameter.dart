import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dev/seed_data.dart';
import '../../view_model/environment_parameter/environment_parameter_view_model.dart';
import '../shared/app_theme.dart';

/// UC03_Setup Environment Parameter (Admin).
class EnvironmentParameterView extends StatelessWidget {
  const EnvironmentParameterView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
      EnvironmentParameterViewModel()..loadManagementData(),
      child: const _EnvironmentParameterContent(),
    );
  }
}

class _EnvironmentParameterContent extends StatelessWidget {
  const _EnvironmentParameterContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EnvironmentParameterViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Environment Settings',
                    style: AppText.screenTitle,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Admin Panel  >  Environment Settings  •  UC03',
                style: AppText.caption,
              ),
            ),

            if (viewModel.errorMessage != null)
              _MessageBanner(
                text: viewModel.errorMessage!,
                background: AppColors.dangerBackground,
                foreground: AppColors.danger,
                icon: Icons.error_outline,
              ),
            if (viewModel.successMessage != null)
              _MessageBanner(
                text: viewModel.successMessage!,
                background: AppColors.successBackground,
                foreground: AppColors.success,
                icon: Icons.check_circle_outline,
              ),

            _CooldownSettingsCard(viewModel: viewModel),

            const SizedBox(height: 16),

            const _SeedDataCard(),

            const SizedBox(height: 24),

            const Text('Manage Attractions', style: AppText.sectionTitle),
            const SizedBox(height: 10),

            if (viewModel.attractions.isEmpty)
              const AppEmptyState(
                icon: Icons.map_outlined,
                message: 'No attractions yet. Use "Seed Sample Data" '
                    'below to get started.',
              )
            else
              ...viewModel.attractions.map(
                    (attraction) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AttractionAdminTile(
                    attraction: attraction,
                    viewModel: viewModel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.text,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: background,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _SeedDataCard extends StatefulWidget {
  const _SeedDataCard();

  @override
  State<_SeedDataCard> createState() => _SeedDataCardState();
}

class _SeedDataCardState extends State<_SeedDataCard> {
  bool _isSeeding = false;

  Future<void> _runSeed(BuildContext context) async {
    setState(() => _isSeeding = true);

    try {
      final result = await seedSampleData();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );

      await context.read<EnvironmentParameterViewModel>().loadManagementData();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeding failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.infoBackground,
      child: Row(
        children: [
          const Icon(Icons.dataset_outlined, color: AppColors.info),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Developer Tools',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                  ),
                ),
                Text(
                  'Seed sample attractions, etiquette rules, and '
                      'notifications for demoing.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSeeding ? null : () => _runSeed(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
            child: _isSeeding
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('Seed Data'),
          ),
        ],
      ),
    );
  }
}

class _CooldownSettingsCard extends StatelessWidget {
  const _CooldownSettingsCard({required this.viewModel});

  final EnvironmentParameterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final settings = viewModel.environmentSettings;

    final controller = TextEditingController(
      text: (settings['defaultCooldownMinutes'] ?? '').toString(),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.timer_outlined, color: AppColors.accentTeal),
              SizedBox(width: 8),
              Text(
                'Default Cooldown Duration',
                style: AppText.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Allowable range: '
                '${settings['minCooldownMinutes']}-'
                '${settings['maxCooldownMinutes']} minutes (UC03 C3)',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: 'minutes',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final minutes = int.tryParse(controller.text);

                  if (minutes == null) {
                    return;
                  }

                  await viewModel.saveDefaultCooldown(minutes);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttractionAdminTile extends StatelessWidget {
  const _AttractionAdminTile({
    required this.attraction,
    required this.viewModel,
  });

  final Map<String, dynamic> attraction;
  final EnvironmentParameterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final geofence = attraction['geofence'] as Map<String, dynamic>?;
    final isSupported = attraction['isSupported'] == true;
    final isGeofenceActive = geofence?['isActive'] == true;

    return AppCard(
      color: isSupported
          ? AppColors.surface
          : AppColors.border.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSupported
                  ? AppColors.successBackground
                  : AppColors.dangerBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.temple_hindu_outlined,
              color: isSupported ? AppColors.success : AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attraction['name']?.toString() ?? 'Unnamed',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  attraction['category']?.toString() ?? '-',
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!isSupported)
                      const AppPill(
                        label: 'Hidden from map',
                        background: AppColors.dangerBackground,
                        foreground: AppColors.danger,
                        icon: Icons.visibility_off_outlined,
                      ),
                    AppPill(
                      label: '${geofence?['radiusMeters'] ?? '-'}m',
                      background: AppColors.infoBackground,
                      foreground: AppColors.info,
                      icon: Icons.radar,
                    ),
                    AppPill(
                      label: isGeofenceActive ? 'Geofence On' : 'Geofence Off',
                      background: isGeofenceActive
                          ? AppColors.successBackground
                          : AppColors.dangerBackground,
                      foreground: isGeofenceActive
                          ? AppColors.success
                          : AppColors.danger,
                      icon: isGeofenceActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: isSupported,
                activeThumbColor: AppColors.success,
                onChanged: (value) {
                  viewModel.setAttractionEnabled(
                    attractionId: attraction['id'].toString(),
                    isSupported: value,
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_location_alt_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _showGeofenceDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGeofenceDialog(BuildContext context) {
    final geofence = attraction['geofence'] as Map<String, dynamic>?;

    final radiusController = TextEditingController(
      text: (geofence?['radiusMeters'] ?? '').toString(),
    );

    var isActive = geofence?['isActive'] == true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Configure Geofence\n${attraction['name'] ?? ''}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius (meters)',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final radius = double.tryParse(radiusController.text);

                    if (radius == null) {
                      return;
                    }

                    final success = await viewModel.saveGeofence(
                      attractionId: attraction['id'].toString(),
                      radiusMeters: radius,
                      isActive: isActive,
                    );

                    if (success && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
