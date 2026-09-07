import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/cultural_map/cultural_map_view_model.dart';
import '../../view_model/settings/app_settings_controller.dart';
import '../cultural_map/cultural_map.dart';

class SavedPlacesPage extends StatefulWidget {
  const SavedPlacesPage({
    super.key,
  });

  @override
  State<SavedPlacesPage> createState() =>
      _SavedPlacesPageState();
}

class _SavedPlacesPageState
    extends State<SavedPlacesPage> {
  late final CulturalMapViewModel _viewModel;

  final AppSettingsController _settings =
      AppSettingsController.instance;

  @override
  void initState() {
    super.initState();

    _settings.addListener(
      _onSettingsChanged,
    );

    _viewModel = CulturalMapViewModel();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) async {
        await _viewModel.initialise();
      },
    );
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settings.removeListener(
      _onSettingsChanged,
    );

    _viewModel.dispose();

    super.dispose();
  }

  String _t({
    required String en,
    required String zh,
    required String ms,
  }) {
    return _settings.text(
      en: en,
      zh: zh,
      ms: ms,
    );
  }

  String _categoryText(
      String category,
      ) {
    switch (category) {
      case 'Islamic Culture':
        return _t(
          en: 'Islamic Culture',
          zh: '伊斯兰文化',
          ms: 'Budaya Islam',
        );
      case 'Chinese Culture':
        return _t(
          en: 'Chinese Culture',
          zh: '中华文化',
          ms: 'Budaya Cina',
        );
      case 'Indian Culture':
        return _t(
          en: 'Indian Culture',
          zh: '印度文化',
          ms: 'Budaya India',
        );
      case 'Places of Worship':
        return _t(
          en: 'Places of Worship',
          zh: '宗教场所',
          ms: 'Tempat Ibadat',
        );
      case 'Historical Landmarks':
        return _t(
          en: 'Historical Landmarks',
          zh: '历史地标',
          ms: 'Mercu Tanda Bersejarah',
        );
      default:
        return category;
    }
  }

  IconData _iconForCategory(
      String category,
      ) {
    final value = category.toLowerCase();

    if (value.contains('islam') ||
        value.contains('mosque')) {
      return Icons.mosque_outlined;
    }

    if (value.contains('indian') ||
        value.contains('hindu')) {
      return Icons.temple_hindu_outlined;
    }

    if (value.contains('chinese') ||
        value.contains('buddh') ||
        value.contains('temple')) {
      return Icons.temple_buddhist_outlined;
    }

    if (value.contains('histor')) {
      return Icons.account_balance_outlined;
    }

    if (value.contains('worship')) {
      return Icons.church_outlined;
    }

    return Icons.place_outlined;
  }

  Future<void> _openAttraction(
      Map<String, dynamic> attraction,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CulturalMapView(
              initialAttraction:
              attraction,
            ),
      ),
    );
  }

  Future<void> _removeFromFavourites(
      Map<String, dynamic> attraction,
      ) async {
    final success =
    await _viewModel.toggleFavourite(
      attraction,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _viewModel.clearError();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _t(
                en: 'Unable to remove from Favourites.',
                zh: '无法从收藏中移除。',
                ms: 'Tidak dapat mengalih keluar daripada Kegemaran.',
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return ChangeNotifierProvider<CulturalMapViewModel>.value(
      value: _viewModel,
      child: Consumer<CulturalMapViewModel>(
        builder: (
            context,
            viewModel,
            child,
            ) {
          final savedAttractions =
          viewModel.allAttractions
              .where(
                (attraction) {
              final id =
                  attraction['id']
                      ?.toString()
                      .trim() ??
                      '';

              return id.isNotEmpty &&
                  viewModel.isFavourite(id);
            },
          )
              .toList();

          return Scaffold(
            backgroundColor:
            colorScheme.surface,
            appBar: AppBar(
              backgroundColor:
              colorScheme.surface,
              surfaceTintColor:
              Colors.transparent,
              title: Text(
                _t(
                  en: 'Saved Places',
                  zh: '已保存的地点',
                  ms: 'Tempat Disimpan',
                ),
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
            body: viewModel.isLoading
                ? const Center(
              child:
              CircularProgressIndicator(),
            )
                : savedAttractions.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding:
              const EdgeInsets.fromLTRB(
                18,
                14,
                18,
                18,
              ),
              itemCount:
              savedAttractions.length,
              separatorBuilder: (
                  _,
                  index,
                  ) =>
              const SizedBox(
                height: 11,
              ),
              itemBuilder: (
                  context,
                  index,
                  ) {
                final attraction =
                savedAttractions[index];

                return _buildSavedCard(
                  viewModel,
                  attraction,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color:
                colorScheme.primaryContainer,
                shape:
                BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 32,
                color:
                colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _t(
                en: 'No saved places yet',
                zh: '尚未保存任何地点',
                ms: 'Belum ada tempat disimpan',
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _t(
                en: 'Tap the heart icon on any cultural attraction '
                    'to save it here for quick access later.',
                zh: '点击任意文化景点的爱心图标，即可将其保存于此以便日后快速查看。',
                ms: 'Ketik ikon hati pada mana-mana tarikan budaya '
                    'untuk menyimpannya di sini bagi capaian pantas kemudian.',
              ),
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(
      CulturalMapViewModel viewModel,
      Map<String, dynamic> attraction,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final category =
    viewModel.attractionCategory(
      attraction,
    );

    return Material(
      color:
      colorScheme.surfaceContainerLow,
      borderRadius:
      BorderRadius.circular(18),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: () =>
            _openAttraction(
              attraction,
            ),
        child: Container(
          padding:
          const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color:
              colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color:
                  colorScheme.primaryContainer,
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: Icon(
                  _iconForCategory(
                    category,
                  ),
                  color:
                  colorScheme.onPrimaryContainer,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.attractionName(
                        attraction,
                      ),
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _categoryText(
                        category,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.near_me_outlined,
                          size: 15,
                          color:
                          colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            viewModel.distanceTextFor(
                              attraction,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color:
                              colorScheme.onSurfaceVariant,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _t(
                  en: 'Remove from Favourites',
                  zh: '从收藏中移除',
                  ms: 'Alih Keluar daripada Kegemaran',
                ),
                onPressed:
                viewModel.isSavingAttraction
                    ? null
                    : () =>
                    _removeFromFavourites(
                      attraction,
                    ),
                icon: Icon(
                  Icons.favorite_rounded,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
