import 'package:flutter/material.dart';

import '../../../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../../../data_layer/model/repositories/attraction/cultural_map_repository.dart';
import '../../../data_layer/model/repositories/system_config/system_config_repository.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../shared/app_theme.dart';

String _envT({
  required String en,
  required String zh,
  required String ms,
}) {
  return AppSettingsController.instance.text(
    en: en,
    zh: zh,
    ms: ms,
  );
}

String _envCategory(String value) {
  switch (value.trim()) {
    case 'Islamic Culture':
      return _envT(en: 'Islamic Culture', zh: '伊斯兰文化', ms: 'Budaya Islam');
    case 'Chinese Culture':
      return _envT(en: 'Chinese Culture', zh: '华人文化', ms: 'Budaya Cina');
    case 'Indian Culture':
      return _envT(en: 'Indian Culture', zh: '印度文化', ms: 'Budaya India');
    case 'Places of Worship':
      return _envT(en: 'Places of Worship', zh: '宗教场所', ms: 'Tempat Ibadat');
    case 'Historical Landmarks':
      return _envT(en: 'Historical Landmarks', zh: '历史地标', ms: 'Mercu Tanda Bersejarah');
    default:
      return value;
  }
}

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

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    AppSettingsController.instance.addListener(_onSettingsChanged);
    _loadAll();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    AppSettingsController.instance.removeListener(_onSettingsChanged);
    for (final controller in _radiusControllers.values) {
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
      _showMessage(_envT(
        en: 'Unable to load environment parameters: $e',
        zh: '无法加载环境参数：$e',
        ms: 'Tidak dapat memuatkan parameter persekitaran: $e',
      ));
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
      _showMessage(_envT(
        en: 'Please enter a valid radius in metres.',
        zh: '请输入有效的半径（米）。',
        ms: 'Sila masukkan jejari yang sah dalam meter.',
      ));
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
      );

      _showMessage(_envT(
        en: 'Geofence configuration saved successfully.',
        zh: '地理围栏配置已成功保存。',
        ms: 'Konfigurasi geofence berjaya disimpan.',
      ));

      setState(() {
        _activeGeofenceCount = _activeByAttraction.values
            .where((value) => value)
            .length;
      });
    } catch (e) {
      _showMessage(_envT(
        en: 'Unable to save geofence: $e',
        zh: '无法保存地理围栏：$e',
        ms: 'Tidak dapat menyimpan geofence: $e',
      ));
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
        _envT(
          en: 'Invalid cooldown duration. Please enter a value within the allowable range.',
          zh: '冷却时间无效。请输入允许范围内的数值。',
          ms: 'Tempoh bertenang tidak sah. Sila masukkan nilai dalam julat yang dibenarkan.',
        ),
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

      _showMessage(_envT(
        en: 'Default cooldown duration updated successfully.',
        zh: '默认冷却时间已成功更新。',
        ms: 'Tempoh bertenang lalai berjaya dikemas kini.',
      ));
    } catch (e) {
      _showMessage(_envT(
        en: 'Unable to save cooldown duration: $e',
        zh: '无法保存冷却时间：$e',
        ms: 'Tidak dapat menyimpan tempoh bertenang: $e',
      ));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 175,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        10,
        14,
        18,
        18,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF102D45),
                  Color(0xFF0D5F5A),
                ]
              : const [
                  Color(0xFFDDF4FF),
                  Color(0xFFE7FBF5),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -20,
            child: Icon(
              Icons.radar_rounded,
              size: 125,
              color:
                  const Color(
                0xFF00A77E,
              ).withValues(
                alpha:
                    isDark ? 0.17 : 0.10,
              ),
            ),
          ),
          Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(
                          context,
                        ).pop(),
                    icon: const Icon(
                      Icons
                          .arrow_back_rounded,
                    ),
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF123B61,
                          ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFF00A77E,
                      ).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: Text(
                      _envT(
                        en:
                            'Admin Settings',
                        zh:
                            '管理员设置',
                        ms:
                            'Tetapan Pentadbir',
                      ),
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF00A77E,
                        ),
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Padding(
                padding:
                    const EdgeInsets.only(
                  left: 10,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _envT(
                        en:
                            'Environment Parameters',
                        zh:
                            '环境参数',
                        ms:
                            'Parameter Persekitaran',
                      ),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : const Color(
                                0xFF123B61,
                              ),
                        fontSize: 21,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    SizedBox(
                      width: 260,
                      child: Text(
                        _envT(
                          en:
                              'Control geofence radius and etiquette alert cooldown.',
                          zh:
                              '管理地理围栏半径和礼仪提醒冷却时间。',
                          ms:
                              'Urus jejari geofence dan tempoh bertenang amaran etika.',
                        ),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                                  .withValues(
                                  alpha:
                                      0.74,
                                )
                              : const Color(
                                  0xFF4A6872,
                                ),
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownCard() {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  isDark ? 0.14 : 0.05,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFB744,
                  ).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color:
                      Color(
                    0xFFFF9C12,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _envT(
                        en:
                            'Alert Cooldown',
                        zh:
                            '提醒冷却时间',
                        ms:
                            'Tempoh Bertenang Amaran',
                      ),
                      style: TextStyle(
                        color: colorScheme
                            .onSurface,
                        fontWeight:
                            FontWeight
                                .w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _envT(
                        en:
                            '$_activeGeofenceCount active geofence${_activeGeofenceCount == 1 ? '' : 's'}',
                        zh:
                            '$_activeGeofenceCount 个启用中的地理围栏',
                        ms:
                            '$_activeGeofenceCount geofence aktif',
                      ),
                      style: TextStyle(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            _envT(
              en:
                  'Minutes before the same attraction can alert the same tourist again.',
              zh:
                  '同一景点再次提醒同一游客前需要等待的分钟数。',
              ms:
                  'Minit sebelum tarikan yang sama boleh memberi amaran kepada pelancong yang sama sekali lagi.',
            ),
            style: TextStyle(
              color: colorScheme
                  .onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _cooldownController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? colorScheme
                            .surfaceContainer
                        : const Color(
                            0xFFF4FBFF,
                          ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .hourglass_bottom_rounded,
                      color:
                          Color(
                        0xFF00A77E,
                      ),
                    ),
                    suffixText:
                        _envT(
                      en: 'minutes',
                      zh: '分钟',
                      ms: 'minit',
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            colorScheme
                                .outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              _SaveButton(
                isSaving:
                    _isSavingCooldown,
                onPressed:
                    _saveCooldown,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceSectionHeader() {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 18,
          color: const Color(0xFF00A77E),
        ),
        const SizedBox(width: 6),
        Text(
          _envT(
            en: 'Configure Geofence',
            zh: '配置地理围栏',
            ms: 'Konfigurasi Geofence',
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          hintText: _envT(
            en: 'Search attractions…',
            zh: '搜索景点…',
            ms: 'Cari tarikan…',
          ),
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              label: _envT(
                en: 'All',
                zh: '全部',
                ms: 'Semua',
              ),
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
            label: _envCategory(category),
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
                ? _envT(
                    en: 'No supported attractions found.',
                    zh: '找不到受支持的景点。',
                    ms: 'Tiada tarikan yang disokong ditemui.',
                  )
                : _envT(
                    en: 'No attractions match your search or filter.',
                    zh: '没有符合搜索或筛选条件的景点。',
                    ms: 'Tiada tarikan sepadan dengan carian atau penapis anda.',
                  ),
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceCard(Map<String, dynamic> attraction) {
    final id = attraction['id']?.toString() ?? '';
    final name = attraction['name']?.toString() ??
        _envT(en: 'Attraction', zh: '景点', ms: 'Tarikan');
    final category = attraction['category']?.toString();
    final isActive = _activeByAttraction[id] ?? false;
    final isSaving = _savingAttractionIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _envCategory(category),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeThumbColor: const Color(0xFF00A77E),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: TextField(
                    controller: _radiusControllers[id],
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.radar_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      suffixText: 'm',
                      suffixStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: filled ? Theme.of(context).colorScheme.primary : Colors.white,
      ),
    )
        : Icon(
      Icons.check_rounded,
      color: filled ? Theme.of(context).colorScheme.primary : Colors.white,
    );

    return Material(
      color: filled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primary,
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
      color: selected ? const Color(0xFF00A77E) : Theme.of(context).colorScheme.surfaceContainerHighest,
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
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
