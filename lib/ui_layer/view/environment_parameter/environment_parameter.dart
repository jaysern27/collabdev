import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/attraction/cultural_map_repository.dart';
import '../../../data_layer/model/repositories/system_config/system_config_repository.dart';
import '../shared/app_theme.dart';

// UC03 – Setup Environment Parameter (minimal scope: Configure
// Geofence + Configure Cooldown Settings). Attraction records
// themselves are already managed through the Cultural Map data.
class EnvironmentParameterPage extends StatefulWidget {
  const EnvironmentParameterPage({super.key});

  @override
  State<EnvironmentParameterPage> createState() =>
      _EnvironmentParameterPageState();
}

class _EnvironmentParameterPageState
    extends State<EnvironmentParameterPage> {
  final AttractionRepository _attractionRepository =
  AttractionRepository();
  final SystemConfigRepository _systemConfigRepository =
  SystemConfigRepository();

  bool _isLoading = true;
  List<Map<String, dynamic>> _attractions = [];

  final Map<String, TextEditingController> _radiusControllers = {};
  final Map<String, TextEditingController> _latControllers = {};
  final Map<String, TextEditingController> _lngControllers = {};
  final Map<String, bool> _activeByAttraction = {};

  final TextEditingController _cooldownController =
  TextEditingController();
  final TextEditingController _searchController =
  TextEditingController();

  bool _isSavingCooldown = false;
  final Set<String> _savingAttractionIds = {};
  int _activeGeofenceCount = 0;
  String _searchQuery = '';
  final Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    for (final controller in _radiusControllers.values) {
      controller.dispose();
    }
    for (final controller in _latControllers.values) {
      controller.dispose();
    }
    for (final controller in _lngControllers.values) {
      controller.dispose();
    }
    _cooldownController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleAttractions {
    return _attractions.where((attraction) {
      final name =
          attraction['name']?.toString().toLowerCase() ?? '';
      final matchesSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery);

      final category = attraction['category']?.toString();
      final matchesCategory = _selectedCategories.isEmpty ||
          (category != null &&
              _selectedCategories.contains(category));

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final attractions =
      await _attractionRepository.getAllAttractions();
      final cooldownMinutes =
      await _systemConfigRepository.getDefaultCooldownMinutes();

      var activeCount = 0;

      for (final attraction in attractions) {
        final id = attraction['id']?.toString();

        if (id == null) {
          continue;
        }

        final radius = attraction['geofenceRadiusMeters'];

        _radiusControllers[id] = TextEditingController(
          text: radius is num ? radius.toString() : '300',
        );

        final center = AttractionRepository.geofenceCenter(attraction);

        _latControllers[id] = TextEditingController(
          text: center != null
              ? center['latitude'].toString()
              : '',
        );
        _lngControllers[id] = TextEditingController(
          text: center != null
              ? center['longitude'].toString()
              : '',
        );

        final isActive = attraction['geofenceActive'] == true;
        _activeByAttraction[id] = isActive;

        if (isActive) {
          activeCount++;
        }
      }

      _cooldownController.text = cooldownMinutes.toString();

      setState(() {
        _attractions = attractions;
        _activeGeofenceCount = activeCount;
      });
    } catch (e) {
      _showMessage('Unable to load environment parameters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGeofence(String attractionId) async {
    final radiusText =
    _radiusControllers[attractionId]?.text.trim() ?? '';
    final radius = double.tryParse(radiusText);

    if (radius == null || radius <= 0) {
      _showMessage('Please enter a valid radius in metres.');
      return;
    }

    final latText = _latControllers[attractionId]?.text.trim() ?? '';
    final lngText = _lngControllers[attractionId]?.text.trim() ?? '';
    final latitude = double.tryParse(latText);
    final longitude = double.tryParse(lngText);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      _showMessage(
        'Please enter a valid geofence location '
            '(latitude -90 to 90, longitude -180 to 180).',
      );
      return;
    }

    setState(() {
      _savingAttractionIds.add(attractionId);
    });

    try {
      final active = _activeByAttraction[attractionId] ?? false;

      await _attractionRepository.updateGeofenceConfig(
        attractionId: attractionId,
        radiusMeters: radius,
        active: active,
        latitude: latitude,
        longitude: longitude,
      );

      _showMessage('Geofence configuration saved successfully.');

      setState(() {
        _activeGeofenceCount = _activeByAttraction.values
            .where((value) => value)
            .length;
      });
    } catch (e) {
      _showMessage('Unable to save geofence: $e');
    } finally {
      if (mounted) {
        setState(() {
          _savingAttractionIds.remove(attractionId);
        });
      }
    }
  }

  Future<void> _saveCooldown() async {
    final minutes = int.tryParse(_cooldownController.text.trim());

    if (minutes == null || minutes <= 0) {
      _showMessage(
        'Invalid cooldown duration. Please enter a value '
            'within the allowable range.',
      );
      return;
    }

    setState(() {
      _isSavingCooldown = true;
    });

    try {
      await _systemConfigRepository.setDefaultCooldownMinutes(
        minutes,
      );

      _showMessage('Default cooldown duration updated successfully.');
    } catch (e) {
      _showMessage('Unable to save cooldown duration: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCooldown = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        )
            : RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildCooldownCard(),
              const SizedBox(height: 24),
              _buildGeofenceSectionHeader(),
              const SizedBox(height: 12),
              _buildSearchField(),
              const SizedBox(height: 10),
              _buildCategoryFilter(),
              const SizedBox(height: 12),
              if (_visibleAttractions.isEmpty)
                _buildNoAttractionsState()
              else
                for (final attraction in _visibleAttractions)
                  _buildGeofenceCard(attraction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.heading,
        ),
        const SizedBox(width: 2),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment Parameters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Geofence radius and etiquette alert cooldown',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCooldownCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Alert Cooldown',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Minutes before the same attraction can alert the '
                'same tourist again. $_activeGeofenceCount '
                'attraction${_activeGeofenceCount == 1 ? '' : 's'} '
                'currently have an active geofence.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _cooldownController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                      suffixText: 'minutes',
                      suffixStyle: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SaveButton(
                isSaving: _isSavingCooldown,
                onPressed: _saveCooldown,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceSectionHeader() {
    return const Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: 18, color: AppColors.primary),
        SizedBox(width: 6),
        Text(
          'Configure Geofence',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tintFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          hintText: 'Search attractions…',
          hintStyle: TextStyle(color: AppColors.muted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = CulturalMapRepository.supportedCategories;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategories.isEmpty;

            return _CategoryChip(
              label: 'All',
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedCategories.clear();
                });
              },
            );
          }

          final category = categories[index - 1];
          final isSelected = _selectedCategories.contains(category);

          return _CategoryChip(
            label: category,
            selected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedCategories.remove(category);
                } else {
                  _selectedCategories.add(category);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildNoAttractionsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.tintLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _attractions.isEmpty
                ? 'No supported attractions found.'
                : 'No attractions match your search or filter.',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  void _resetLocationToPin(Map<String, dynamic> attraction) {
    final id = attraction['id']?.toString();

    if (id == null) {
      return;
    }

    final latitude = attraction['latitude'];
    final longitude = attraction['longitude'];

    if (latitude is! num || longitude is! num) {
      _showMessage('This attraction has no map location to copy.');
      return;
    }

    setState(() {
      _latControllers[id]?.text = latitude.toString();
      _lngControllers[id]?.text = longitude.toString();
    });
  }

  Widget _buildGeofenceCard(Map<String, dynamic> attraction) {
    final id = attraction['id']?.toString() ?? '';
    final name = attraction['name']?.toString() ?? 'Attraction';
    final category = attraction['category']?.toString();
    final isActive = _activeByAttraction[id] ?? false;
    final isSaving = _savingAttractionIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successSoft
                      : AppColors.tintLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.place_rounded,
                  color: isActive
                      ? AppColors.success
                      : AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeThumbColor: AppColors.primary,
                onChanged: (value) {
                  setState(() {
                    _activeByAttraction[id] = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CoordinateField(
                  controller: _latControllers[id],
                  label: 'Latitude',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CoordinateField(
                  controller: _lngControllers[id],
                  label: 'Longitude',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _resetLocationToPin(attraction),
                tooltip: "Use attraction's map location",
                icon: const Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.tintFaint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _radiusControllers[id],
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.radar_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      suffixText: 'm',
                      suffixStyle: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SaveButton(
                isSaving: isSaving,
                onPressed: () => _saveGeofence(id),
                filled: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;
  final bool filled;

  const _SaveButton({
    required this.isSaving,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final child = isSaving
        ? SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: filled ? AppColors.primary : Colors.white,
      ),
    )
        : Icon(
      Icons.check_rounded,
      color: filled ? AppColors.primary : Colors.white,
    );

    return Material(
      color: filled ? Colors.white : AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSaving ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _CoordinateField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;

  const _CoordinateField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tintFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        style: const TextStyle(
          color: AppColors.heading,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.tintFaint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 7,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
