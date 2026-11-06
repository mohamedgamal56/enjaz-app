import 'timeline_models.dart';

/// Abstract contract for modules providing timeline events
abstract class TimelineSource {
  /// Fetches chronological entries for this module within the given date/time range
  Future<List<TimelineEntry>> getEntriesForRange(DateTime start, DateTime end);

  /// Returns a map of local_date (YYYY-MM-DD) to count of events/entries for month calendar view
  Future<Map<String, int>> getCountsForRange(DateTime start, DateTime end);
}
