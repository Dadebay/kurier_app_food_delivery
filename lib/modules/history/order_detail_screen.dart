import 'package:flutter/material.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/status_chip.dart';

/// Full breakdown of one finished order — everything the compact history card
/// leaves out: items, cash, customer contact, timestamps.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final itemsTotal = order.items.fold<double>(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );

    return Scaffold(
      appBar: AppBar(title: Text('${s.orderNo} №${order.number}')),
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              StatusChip(status: order.status, strings: s),
              const Spacer(),
              if (order.completedAt != null)
                Text(
                  '${s.statusDelivered} · ${Fmt.time(order.completedAt!)}',
                  style: AppText.bodyMuted,
                ),
            ],
          ),
          const SizedBox(height: 20),

          _Section(
            title: order.address.fullLine(
              houseLabel: s.houseLabel,
              entranceLabel: s.entranceLabel,
              floorLabel: s.floorLabel,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName, style: AppText.body),
                const SizedBox(height: 2),
                Text(Fmt.phone(order.customerPhone), style: AppText.bodyMuted),
                if (order.address.note != null) ...[
                  const SizedBox(height: 10),
                  Text(order.address.note!, style: AppText.bodyMuted),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          _Section(
            title: s.orderItemsLabel,
            child: Column(
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity} × ${item.name}',
                            style: AppText.body,
                          ),
                        ),
                        Text(
                          Fmt.money(item.price * item.quantity),
                          style: AppText.body,
                        ),
                      ],
                    ),
                  ),
                if (itemsTotal > 0) const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(s.sum, style: AppText.label)),
                    Text(Fmt.money(order.total), style: AppText.figure),
                  ],
                ),
                if (order.changeFrom != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(s.change, style: AppText.label)),
                      Text(
                        s.changeFrom(Fmt.amount(order.changeFrom!)),
                        style: AppText.figure.copyWith(color: AppColors.orange),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          _Section(
            title: s.branch,
            child: Text(order.branchName, style: AppText.body),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
