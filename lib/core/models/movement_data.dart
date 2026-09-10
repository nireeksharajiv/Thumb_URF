/// A time-bounded movement summary. Detection is intentionally not defined here.
class MovementData {
  MovementData({
    required DateTime startTime,
    required DateTime endTime,
    required this.movementCount,
  }) : startTime = startTime.toUtc(),
       endTime = endTime.toUtc() {
    if (this.endTime.isBefore(this.startTime)) {
      throw ArgumentError.value(
        endTime,
        'endTime',
        'Cannot be before startTime.',
      );
    }
    if (movementCount < 0) {
      throw ArgumentError.value(
        movementCount,
        'movementCount',
        'Cannot be negative.',
      );
    }
  }

  final DateTime startTime;
  final DateTime endTime;
  final int movementCount;

  Duration get duration => endTime.difference(startTime);

  double get movementsPerMinute {
    final minutes = duration.inMilliseconds / Duration.millisecondsPerMinute;
    return minutes == 0 ? 0 : movementCount / minutes;
  }
}
