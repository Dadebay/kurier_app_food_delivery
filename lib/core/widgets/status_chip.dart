import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/order_status.dart';
import '../theme/app_text_styles.dart';

/// The pill on the order card — "В очереди", "Забран", "Еду".
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.strings});

  final OrderStatus status;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: status.softColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label(status, strings),
        style: AppText.chip.copyWith(color: status.color),
      ),
    );
  }

  static String label(OrderStatus status, AppStrings s) => switch (status) {
    OrderStatus.assigned => s.statusAssigned,
    OrderStatus.pickedUp => s.statusPickedUp,
    OrderStatus.onTheWay => s.statusOnTheWay,
    OrderStatus.delivered => s.statusDelivered,
    OrderStatus.cashReturned => s.statusCashReturned,
    OrderStatus.cancelled => s.statusCancelled,
  };
}
