import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';

/// Cash confirmation shown when the courier taps "Доставил".
///
/// Cash is the main payment scenario here (slide 10), and the end-of-shift
/// reconciliation is only as good as this step — so the amount to collect and
/// the change to hand back are stated plainly and confirmed explicitly rather
/// than assumed.
class CashSheet extends StatelessWidget {
  const CashSheet._({required this.order, required this.strings});

  final DeliveryOrder order;
  final AppStrings strings;

  /// Resolves to `true` when the courier confirmed the hand-over.
  static Future<bool> show(
    BuildContext context, {
    required DeliveryOrder order,
    required AppStrings strings,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (_) => CashSheet._(order: order, strings: strings),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final changeDue = order.changeDue;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('${strings.cashTitle} · №${order.number}', style: AppText.h2),
            const SizedBox(height: 18),
            _Row(
              label: strings.cashReceived,
              value: order.changeFrom == null
                  ? Fmt.money(order.total)
                  : Fmt.money(order.changeFrom!),
              emphasised: true,
            ),
            const SizedBox(height: 12),
            _Row(label: strings.sum, value: Fmt.money(order.total)),
            if (changeDue != null && changeDue > 0) ...[
              const SizedBox(height: 12),
              _Row(
                label: strings.changeGiven,
                value: Fmt.money(changeDue),
                color: AppColors.orange,
                emphasised: true,
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: strings.confirmDelivery,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            AppButton.outline(
              label: strings.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.color, this.emphasised = false});

  final String label;
  final String value;
  final Color? color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: emphasised ? AppColors.cream : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: emphasised ? null : Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodyMuted)),
          Text(
            value,
            style: AppText.figure.copyWith(color: color, fontSize: emphasised ? 19 : 17),
          ),
        ],
      ),
    );
  }
}
