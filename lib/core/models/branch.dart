import 'package:latlong2/latlong.dart';

/// The kitchen/restaurant the courier collects orders from.
class Branch {
  const Branch({
    required this.name,
    required this.address,
    required this.point,
    this.isPrimary = false,
  });

  final String name;
  final String address;
  final LatLng point;
  final bool isPrimary;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    point: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    isPrimary: json['isPrimary'] as bool? ?? false,
  );
}
