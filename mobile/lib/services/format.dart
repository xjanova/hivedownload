import 'dart:math' as math;

/// Human-readable formatting helpers.
class Format {
  static String bytes(int b) {
    if (b <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return i == 0 ? '${v.toStringAsFixed(0)} ${units[i]}' : '${v.toStringAsFixed(1)} ${units[i]}';
  }

  static String speed(double bytesPerSec) =>
      bytesPerSec <= 1 ? '' : '${bytes(bytesPerSec.toInt())}/s';

  static String percent(double fraction) => '${(fraction.clamp(0, 1) * 100).toStringAsFixed(0)}%';

  /// A day-count as the nicest Thai/English unit — mirrors the web's
  /// Campaigns::human() so promo texts always match (365→"1 ปี"/"1 yr").
  static String humanDays(int days, {bool thai = true}) {
    if (days >= 365 && days % 365 == 0) {
      final n = days ~/ 365;
      return thai ? '$n ปี' : '$n yr';
    }
    if (days >= 30 && days % 30 == 0) {
      final n = days ~/ 30;
      return thai ? '$n เดือน' : '$n mo';
    }
    if (days >= 7 && days % 7 == 0) {
      final n = days ~/ 7;
      return thai ? '$n สัปดาห์' : '$n wk';
    }
    return thai ? '$days วัน' : '$days days';
  }

  /// mm:ss or h:mm:ss for a duration in seconds.
  static String duration(int totalSeconds) {
    final s = math.max(0, totalSeconds);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
