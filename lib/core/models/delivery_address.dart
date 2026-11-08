import 'package:latlong2/latlong.dart';

/// Ashgabat runs on microdistricts, not street names — so the address is
/// stored the way it is actually spoken: "Parahat 7 · д. 12 · подъезд 3 ·
/// этаж 5", plus the exact point the customer dropped on the map.
class DeliveryAddress {
  const DeliveryAddress({
    required this.district,
    required this.house,
    this.entrance,
    this.floor,
    this.apartment,
    this.note,
    required this.point,
  });

  /// Microdistrict — "Parahat 7", "Berkararlyk", "Mir 2/1".
  final String district;
  final String house;
  final String? entrance;
  final String? floor;
  final String? apartment;

  /// Free text from the customer — "домофон не работает".
  final String? note;

  final LatLng point;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        district: json['district'] as String? ?? '',
        house: json['house']?.toString() ?? '',
        entrance: json['entrance']?.toString(),
        floor: json['floor']?.toString(),
        apartment: json['apartment']?.toString(),
        note: json['note'] as String?,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'district': district,
    'house': house,
    'entrance': entrance,
    'floor': floor,
    'apartment': apartment,
    'note': note,
    'lat': point.latitude,
    'lng': point.longitude,
  };

  /// Older orders arrive as one pre-joined string ("Parahat 7, 12, ,") whose
  /// empty slots left stray commas on screen. Collapse the runs, drop the
  /// dangling ones, and the same line reads as it was meant to.
  static String _tidy(String value) => value
      .replaceAll(RegExp(r'\s*,\s*'), ', ')
      .replaceAll(RegExp(r'(,\s*)+'), ', ')
      .replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');

  /// The district and house are one field on the wire for orders placed
  /// before the split, so the house label is only added when there is a
  /// house to label.
  String _head(String houseLabel) {
    final area = _tidy(district);
    final number = _tidy(house);
    if (number.isEmpty) return area;
    if (area.isEmpty) return '$houseLabel $number';
    return '$area · $houseLabel $number';
  }

  /// Short form for the map header — "Parahat 7 · д. 12".
  String shortLine(String houseLabel) => _head(houseLabel);

  /// Full form for the order card, built from whatever parts exist.
  String fullLine({
    required String houseLabel,
    required String entranceLabel,
    required String floorLabel,
  }) {
    final parts = <String>[];
    final head = _head(houseLabel);
    if (head.isNotEmpty) parts.add(head);
    if (entrance != null && entrance!.trim().isNotEmpty) {
      parts.add('$entranceLabel ${entrance!.trim()}');
    }
    if (floor != null && floor!.trim().isNotEmpty) {
      parts.add('$floorLabel ${floor!.trim()}');
    }
    return parts.join(' · ');
  }
}
