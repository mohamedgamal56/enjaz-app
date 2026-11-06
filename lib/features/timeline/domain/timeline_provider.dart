import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import 'timeline_aggregator.dart';

final timelineAggregatorProvider = Provider<TimelineAggregator>((ref) {
  final db = ref.watch(databaseProvider);
  return TimelineAggregator(db);
});
