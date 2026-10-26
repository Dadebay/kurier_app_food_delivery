import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

/// A single platform measurement. Its timestamp is never replaced by send time.
class LocationFix {
  const LocationFix({
    required this.point,
    required this.recordedAt,
    this.accuracy,
    this.heading,
    this.speed,
  });

  static const freshness = Duration(minutes: 1);
  final LatLng point;
  final DateTime recordedAt;
  final double? accuracy;
  final double? heading;
  final double? speed;

  bool isFresh(DateTime now) {
    final age = now.difference(recordedAt);
    return !age.isNegative && age <= freshness;
  }

  /// Builds a fix from a platform reading, or null when it cannot be trusted.
  ///
  /// A reading without a measurement timestamp is rejected on purpose. This
  /// app orders positions by `recordedAt` and uploads it with every ping, so
  /// stamping "now" on a timeless reading would substitute the send time for
  /// the measurement time — the exact substitution the location rework set
  /// out to remove — and would make such a reading always look like the
  /// newest one, overwriting a genuinely later fix.
  static LocationFix? fromData(LocationData data, DateTime now) {
    final lat = data.latitude;
    final lng = data.longitude;
    final time = data.time;
    if (lat == null ||
        lng == null ||
        time == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        !time.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        time <= 0 ||
        time > now.millisecondsSinceEpoch) {
      return null;
    }
    final accuracy = data.accuracy;
    if (accuracy != null && bounded(accuracy, 5000) == null) return null;
    return LocationFix(
      point: LatLng(lat, lng),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        time.toInt(),
        isUtc: true,
      ),
      accuracy: accuracy,
      heading: bounded(data.heading, 360),
      speed: bounded(data.speed, 100),
    );
  }

  static double? bounded(double? value, double max) =>
      value != null && value.isFinite && value >= 0 && value <= max
      ? value
      : null;

  Map<String, dynamic> toJson() => {
    'latitude': point.latitude,
    'longitude': point.longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (heading != null) 'heading': heading,
    if (speed != null) 'speed': speed,
  };
}
