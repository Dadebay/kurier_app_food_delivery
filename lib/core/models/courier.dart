/// The signed-in courier and the branch they work out of.
class Courier {
  const Courier({
    required this.id,
    required this.name,
    required this.phone,
    required this.branchName,
    required this.onShift,
  });

  final String id;
  final String name;
  final String phone;
  final String branchName;

  /// "На смене" / "Свободен" — the operator only assigns to couriers on shift.
  final bool onShift;

  Courier copyWith({bool? onShift}) => Courier(
    id: id,
    name: name,
    phone: phone,
    branchName: branchName,
    onShift: onShift ?? this.onShift,
  );

  factory Courier.fromJson(Map<String, dynamic> json) => Courier(
    id: json['id'].toString(),
    name:
        json['name'] as String? ??
        [
          json['firstName'],
          json['lastName'],
        ].whereType<String>().where((value) => value.isNotEmpty).join(' '),
    phone: json['phone'] as String? ?? '',
    branchName:
        json['branchName'] as String? ?? json['branch_name'] as String? ?? '',
    onShift: json['onShift'] as bool? ?? json['on_shift'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'branch_name': branchName,
    'on_shift': onShift,
  };
}

/// End-of-shift figures — the gold bar at the bottom of the order list and the
/// number the operator reconciles against.
class ShiftSummary {
  const ShiftSummary({
    required this.deliveredCount,
    required this.cashOnHand,
    required this.handedOver,
  });

  final int deliveredCount;

  /// What the courier should be carrying right now.
  final double cashOnHand;

  /// Already handed to the operator during the shift.
  final double handedOver;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
    deliveredCount: json['delivered_count'] as int? ?? 0,
    cashOnHand: (json['cash_on_hand'] as num?)?.toDouble() ?? 0,
    handedOver: (json['handed_over'] as num?)?.toDouble() ?? 0,
  );

  static const empty = ShiftSummary(
    deliveredCount: 0,
    cashOnHand: 0,
    handedOver: 0,
  );
}
