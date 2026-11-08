import 'delivery_address.dart';
import 'order_status.dart';
import 'package:latlong2/latlong.dart';

/// One assigned delivery.
///
/// Only what the courier needs is modelled — the dish list is shown for the
/// hand-over check, the money fields drive the end-of-shift cash reconciliation.
class DeliveryOrder {
  DeliveryOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.address,
    required this.customerName,
    required this.customerPhone,
    required this.total,
    this.changeFrom,
    required this.items,
    required this.branchName,
    required this.assignedAt,
    this.distanceKm,
    this.comment,
    this.completedAt,
    this.version = 1,
  });

  final String id;

  /// Human-facing number the operator and the customer both say out loud.
  final int number;

  OrderStatus status;

  final DeliveryAddress address;
  final String customerName;
  final String customerPhone;

  /// Cash to collect, in manat.
  final double total;

  /// "Сдача с какой суммы" — the note the customer left so the courier brings
  /// the right change. `null` means no change needed.
  final double? changeFrom;

  final List<OrderItem> items;
  final String branchName;
  final DateTime assignedAt;

  /// Straight-line distance from the courier, refreshed on every GPS fix.
  double? distanceKm;

  final String? comment;

  /// Set the moment the order reaches [OrderStatus.delivered] or
  /// [OrderStatus.cancelled] — drives which day's history the order sorts
  /// into and when it moves from "today" into the archive.
  DateTime? completedAt;
  int version;

  /// How much change the courier must hand back.
  double? get changeDue => changeFrom == null
      ? null
      : (changeFrom! - total).clamp(0, double.infinity);

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (rawId == null || rawId.toString().trim().isEmpty) {
      throw const FormatException('Order id is required');
    }
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return DeliveryOrder(
      id: rawId.toString(),
      number: json['number'] as int,
      status: OrderStatus.fromWire(json['status'] as String?),
      address: json['address'] is Map<String, dynamic>
          ? DeliveryAddress.fromJson(json['address'] as Map<String, dynamic>)
          : DeliveryAddress(
              district: json['address'] as String? ?? '',
              house: '',
              entrance: json['entrance'] as String?,
              floor: json['floor'] as String?,
              point: LatLng(
                (json['latitude'] as num).toDouble(),
                (json['longitude'] as num).toDouble(),
              ),
            ),
      customerName: [
        customer['firstName'],
        customer['lastName'],
      ].whereType<String>().where((value) => value.isNotEmpty).join(' '),
      customerPhone: customer['phone'] as String? ?? '',
      total: (json['total'] as num).toDouble(),
      changeFrom: (json['change_from'] as num?)?.toDouble(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      branchName:
          json['branchName'] as String? ?? json['branch_name'] as String? ?? '',
      assignedAt:
          DateTime.tryParse(json['assignedAt'] as String? ?? '') ??
          DateTime.parse(json['createdAt'] as String),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      comment: json['customerNote'] as String? ?? json['comment'] as String?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'status': status.wire,
    'address': address.toJson(),
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'total': total,
    'change_from': changeFrom,
    'items': items.map((e) => e.toJson()).toList(),
    'branch_name': branchName,
    'assigned_at': assignedAt.toIso8601String(),
    'distance_km': distanceKm,
    'comment': comment,
    'completed_at': completedAt?.toIso8601String(),
  };
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String name;
  final int quantity;
  final double price;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    name: json['productName'] as String? ?? json['name'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    price: ((json['unitPrice'] ?? json['price']) as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'price': price,
  };
}
