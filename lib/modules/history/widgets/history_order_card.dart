import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';

/// A finished order in the history list.
///
/// Everything the courier needs to recognise the order — number, address,
/// status — sits directly on the card face; nothing is hidden behind a tap.
/// Tapping opens the full breakdown (items, cash, customer) instead.
class HistoryOrderCard extends StatelessWidget {
  const HistoryOrderCard({
    super.key,
    required this.order,
    required this.strings,
    required this.onTap,
  });

  final DeliveryOrder order;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completedAt = order.completedAt;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '№${order.number}',
                          style: AppText.h2.copyWith(fontSize: 17),
                        ),
                        if (completedAt != null) ...[
                          const SizedBox(width: 8),
                          Text(Fmt.time(completedAt), style: AppText.bodyMuted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.address.shortLine(strings.houseLabel),
                      style: AppText.bodyMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(status: order.status, strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}
