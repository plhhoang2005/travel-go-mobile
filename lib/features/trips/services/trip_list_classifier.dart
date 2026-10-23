import '../../trip_planner/services/trip_date_policy.dart';
import '../models/editable_remote_records.dart';

enum TripListBucket {
  upcomingOrOngoing,
  past,
  insufficient,
}

class TripListClassifier {
  static const Set<String> _validStatuses = {'planning', 'booked', 'completed'};

  static TripListBucket classify(
    OwnedTripSummary row, {
    required DateTime nowUtc,
  }) {
    if (!row.statusKnown) {
      return TripListBucket.insufficient;
    }

    final rawStatus = row.rawStatus;
    if (rawStatus != null && !_validStatuses.contains(rawStatus)) {
      return TripListBucket.insufficient;
    }

    final startDate = row.startDate;
    final endDate = row.endDate;
    if (startDate == null || endDate == null) {
      return TripListBucket.insufficient;
    }

    TripDateRange? range;
    try {
      range = TripDatePolicy.validate(startDate, endDate);
    } catch (_) {
      return TripListBucket.insufficient;
    }

    if (range == null) {
      return TripListBucket.insufficient;
    }

    final vnTime = nowUtc.toUtc().add(const Duration(hours: 7));
    final todayVn = '${vnTime.year.toString().padLeft(4, '0')}-${vnTime.month.toString().padLeft(2, '0')}-${vnTime.day.toString().padLeft(2, '0')}';

    if (rawStatus == 'completed' && endDate.compareTo(todayVn) >= 0) {
      return TripListBucket.insufficient;
    }

    if (endDate.compareTo(todayVn) < 0) {
      return TripListBucket.past;
    } else {
      return TripListBucket.upcomingOrOngoing;
    }
  }
}
