import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_model/cultural_map/cultural_map_view_model.dart';

class CulturalMapView extends StatelessWidget {
  const CulturalMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CulturalMapViewModel(),
      child: const _CulturalMapContent(),
    );
  }
}

class _CulturalMapContent extends StatelessWidget {
  const _CulturalMapContent();

  @override
  Widget build(BuildContext context) {
    final viewModel =
    context.watch<CulturalMapViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cultural Map'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButton<String>(
              value: viewModel.selectedCategory,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'All',
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: 'Religious',
                  child: Text('Religious'),
                ),
                DropdownMenuItem(
                  value: 'Historical',
                  child: Text('Historical'),
                ),
                DropdownMenuItem(
                  value: 'Heritage',
                  child: Text('Heritage'),
                ),
                DropdownMenuItem(
                  value: 'Museum',
                  child: Text('Museum'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                context
                    .read<CulturalMapViewModel>()
                    .filterByCategory(value);
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Selected Category: '
                  '${viewModel.selectedCategory}',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Number of attractions: '
                  '${viewModel.attractions.length}',
            ),
          ],
        ),
      ),
    );
  }
}