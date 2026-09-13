import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The slice of the order life-cycle (proposal, slide 4) the courier owns.
///
/// The operator assigns an order → it lands here as [assigned]. Everything
/// after that is driven by the courier's own three buttons.
enum OrderStatus {
  /// Assigned, still waiting at the branch — "В очереди".
  assigned('assigned'),

  /// Courier has the food in hand — "Забран".
  pickedUp('picked_up'),

  /// Driving to the customer — "Еду".
  onTheWay('on_the_way'),

  /// Handed over and paid — "Доставлен". The money is now in the courier's
  /// pocket and still has to reach the till.
  delivered('delivered'),

  /// Cash handed to the operator — "Tabşyryldy". The backend's CASH_RETURNED,
  /// the last step the courier owns before the operator closes the order.
  cashReturned('cash_returned'),

  /// Customer refused / operator cancelled.
  cancelled('cancelled');

  const OrderStatus(this.wire);

  /// Value exchanged with the backend.
  final String wire;

  static OrderStatus fromWire(String? value) => switch (value) {
    'ASSIGNED_TO_COURIER' => OrderStatus.assigned,
    'OUT_FOR_DELIVERY' => OrderStatus.onTheWay,
    'DELIVERED' => OrderStatus.delivered,
    // Everything past the hand-over is the operator's and the accountant's
    // business; to the courier it all reads as "cash already returned".
    'CASH_RETURNED' || 'COMPLETED' || 'RECONCILED' => OrderStatus.cashReturned,
    'CANCELLED' => OrderStatus.cancelled,
    _ => OrderStatus.values.firstWhere((s) => s.wire == value, orElse: () => OrderStatus.assigned),
  };

  /// The next status the big button should move the order to, or `null` when
  /// the order is finished.
  OrderStatus? get next => switch (this) {
    OrderStatus.assigned => OrderStatus.onTheWay,
    OrderStatus.pickedUp => OrderStatus.onTheWay,
    OrderStatus.onTheWay => OrderStatus.delivered,
    OrderStatus.delivered => OrderStatus.cashReturned,
    OrderStatus.cashReturned || OrderStatus.cancelled => null,
  };

  /// Still on the working list. The hand-over is deliberately *not* part of
  /// it: a delivered order leaves the route and waits in the history list for
  /// its "Tabşyrdym" tap.
  bool get isOpen =>
      this != OrderStatus.delivered &&
      this != OrderStatus.cashReturned &&
      this != OrderStatus.cancelled;

  /// The courier is still carrying this order's cash.
  bool get awaitsHandOver => this == OrderStatus.delivered;

  Color get color => switch (this) {
    OrderStatus.assigned => AppColors.gold,
    OrderStatus.pickedUp => AppColors.red,
    OrderStatus.onTheWay => AppColors.orange,
    OrderStatus.delivered => AppColors.greenLight,
    OrderStatus.cashReturned => AppColors.greenLight,
    OrderStatus.cancelled => AppColors.textMuted,
  };

  Color get softColor => switch (this) {
    OrderStatus.assigned => AppColors.goldSoft,
    OrderStatus.pickedUp => AppColors.redSoft,
    OrderStatus.onTheWay => AppColors.orangeSoft,
    OrderStatus.delivered => const Color(0xFFE3F0E9),
    OrderStatus.cashReturned => const Color(0xFFE3F0E9),
    OrderStatus.cancelled => const Color(0xFFEDEFEE),
  };
}
