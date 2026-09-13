import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';

/// One assigned delivery, laid out close to `courier_list.png`: number +
/// status, address line, then the amount and distance. Change is shown on the
/// route screen where the courier actually needs it, not repeated here.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.strings, required this.onTap});

  final DeliveryOrder order;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('№${order.number}', style: AppText.h2),
                  const Spacer(),
                  StatusChip(status: order.status, strings: strings),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.address.fullLine(
                  houseLabel: strings.houseLabel,
                  entranceLabel: strings.entranceLabel,
                  floorLabel: strings.floorLabel,
                ),
                style: AppText.body.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Figure(label: strings.sum, value: Fmt.money(order.total)),
                  ),
                  Expanded(
                    child: _Figure(
                      label: strings.distance,
                      value: Fmt.km(order.distanceKm),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        Text(value, style: AppText.figure, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
