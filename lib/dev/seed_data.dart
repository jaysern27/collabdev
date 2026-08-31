import '../data_layer/model/repositories/attraction/attraction_repository.dart';
import '../data_layer/model/repositories/environment_settings/environment_settings_repository.dart';
import '../data_layer/model/repositories/notification/notification_repository.dart';
import '../data_layer/model/repositories/ranking_report/ranking_report_repository.dart';

/// Developer-only sample data for UC02/UC03 (Yew Hong Zhuo's module):
/// the `environment_settings` document Admin configures in UC03, and a
/// handful of `notifications` so the inbox has both read and unread
/// items to demo the All / Unread / Read filters.
///
/// Attractions and etiquette_rules are NOT created here -- inspecting
/// the live project showed 5 real attractions (Batu Caves, National
/// Mosque, St. Mary's Cathedral, Sultan Abdul Samad Building, Thean Hou
/// Temple) with real geofences and 68 etiquette rules already seeded by
/// the Cultural Map module. This script builds on top of that instead of
/// creating duplicates.
///
/// Wired to the "Seed Sample Data" button on the Environment Parameter
/// (UC03 Admin) screen; also runnable directly via
/// `flutter run -t lib/dev/seed_main.dart`.
Future<String> seedSampleData({String demoUserId = 'guest'}) async {
  final attractionRepository = AttractionRepository();
  final environmentSettingsRepository = EnvironmentSettingsRepository();
  final notificationRepository = NotificationRepository();
  final rankingReportRepository = RankingReportRepository();

  final attractions = await attractionRepository.getAllAttractionsForAdmin();

  if (attractions.isEmpty) {
    return 'No attractions found. Seed the Cultural Map module\'s '
        'attractions first, then run this again.';
  }

  Map<String, dynamic>? findAttraction(String id) {
    for (final attraction in attractions) {
      if (attraction['id'] == id) {
        return attraction;
      }
    }
    return null;
  }

  final actions = <String>[];

  // UC03 FR-GEA10: persist the Admin-configured default cooldown so the
  // environment_settings/default document actually exists in Firestore
  // instead of only living as a code fallback. Safe to re-run (upsert).
  await environmentSettingsRepository.updateDefaultCooldown(60);
  actions.add('environment_settings confirmed');

  // UC03 C3: demonstrate the per-attraction cooldown override -- prayer
  // times mean the National Mosque should re-alert less often than the
  // 60-minute default. Safe to re-run (upsert).
  final nationalMosque = findAttraction('national_mosque');

  if (nationalMosque != null && nationalMosque['cooldownMinutes'] == null) {
    await attractionRepository.updateAttraction(
      attractionId: 'national_mosque',
      attractionData: {
        ...nationalMosque,
        'cooldownMinutes': 120,
      },
    );
    actions.add('National Mosque cooldown override set');
  }

  // Guarded separately: only seed sample notifications the first time.
  final existingNotifications =
  await notificationRepository.getHistoryForUser(demoUserId);

  if (existingNotifications.isEmpty) {
    var seededCount = 0;

    for (final sample in _sampleNotifications) {
      final attraction = findAttraction(sample['attractionId'] as String);

      if (attraction == null) {
        continue;
      }

      final id = await notificationRepository.recordNotification(
        userId: demoUserId,
        attractionId: attraction['id'].toString(),
        attractionName: attraction['name']?.toString() ?? '',
        message: sample['message'] as String,
        ruleIds: const [],
        status: 'sent',
      );

      if (sample['isRead'] == true) {
        await notificationRepository.markAsRead(id);
      }

      seededCount++;
    }

    actions.add('$seededCount sample notifications');
  }

  // Module 4 (Etiquette Guidance & Violation Ranking) hasn't computed
  // real Priority Scores yet -- this is placeholder data so UC02's
  // "prioritised do's and don'ts received from Module 4" is visible in
  // the alert screen before that module's real weighted-scoring logic
  // (50% frequency + 30% severity + 20% verification confidence) exists.
  // Guarded separately so it can be seeded even after notifications
  // already exist from an earlier run.
  final existingRankings =
  await rankingReportRepository.getRankingByAttraction('batu_caves');

  if (existingRankings.isEmpty) {
    var rankedCount = 0;

    for (final ranking in _sampleRankings) {
      await rankingReportRepository.addRanking(
        attractionId: ranking['attractionId'] as String,
        ruleId: ranking['ruleId'] as String,
        priorityScore: ranking['priorityScore'] as double,
      );

      rankedCount++;
    }

    actions.add('$rankedCount placeholder priority rankings for Batu Caves');
  }

  if (actions.isEmpty) {
    return 'Sample data already exists -- nothing to seed.';
  }

  return 'Seeded: ${actions.join(', ')}.';
}

// Placeholder Priority Scores for Batu Caves' real etiquette_rules docs,
// standing in for Module 4's ranking calculation until it's implemented.
final List<Map<String, dynamic>> _sampleRankings = [
  {
    // "Remove your footwear before entering areas where shoes are not
    // permitted"
    'attractionId': 'batu_caves',
    'ruleId': 'nNuZwblvGvYkRKKIpJon',
    'priorityScore': 92.0,
  },
  {
    // "Wear modest clothing that covers the shoulders and knees..."
    'attractionId': 'batu_caves',
    'ruleId': 'mC0TYxeeeXDHsdQcBZFn',
    'priorityScore': 81.0,
  },
  {
    // "Do not feed, tease, chase, or attempt to touch the monkeys..."
    'attractionId': 'batu_caves',
    'ruleId': 'MzizuWhuky8Mr037TuHQ',
    'priorityScore': 63.0,
  },
  {
    // "Do not touch deity statues, religious offerings, altars..."
    'attractionId': 'batu_caves',
    'ruleId': 'XotEiQqQZTz5FiOvI5Q5',
    'priorityScore': 47.0,
  },
];

final List<Map<String, dynamic>> _sampleNotifications = [
  {
    'attractionId': 'batu_caves',
    'message': 'Remove your footwear before entering areas where shoes '
        'are not permitted • Wear modest clothing that covers the '
        'shoulders and knees',
    'isRead': false,
  },
  {
    'attractionId': 'national_mosque',
    'message': 'Remove your shoes before entering designated prayer and '
        'indoor mosque areas • Women should wear a headscarf when '
        'entering the mosque',
    'isRead': false,
  },
  {
    'attractionId': 'thean_hou_temple',
    'message': 'Keep your voice low inside the main shrine • Do not '
        'touch deity statues, religious objects, or offerings',
    'isRead': true,
  },
  {
    'attractionId': 'st_marys_cathedral',
    'message': 'Keep your phone on silent mode before entering the '
        'cathedral • Wear clean and respectful clothing',
    'isRead': true,
  },
  {
    'attractionId': 'sultan_abdul_samad_building',
    'message': 'Stay within public walkways and visitor-accessible '
        'areas around the historic building',
    'isRead': false,
  },
];
