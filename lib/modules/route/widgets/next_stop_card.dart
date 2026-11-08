import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dark card floating over the map: where the courier is going and how far it
/// is. Change is confirmed later, on the cash sheet at hand-over — not
/// repeated here.
class NextStopCard extends StatelessWidget {
  const NextStopCard({
    super.key,
    required this.label,
    required this.addressLine,
    required this.km,
    required this.distanceKm,
  });

  /// "INDIKI NOKAT" while driving to the customer, "ALYNJAK ÝER" while the
  /// order still has to be collected from the branch.
  final String label;
  final String addressLine;
  final String km;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.label.copyWith(
                    color: AppColors.greenMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  addressLine,
                  style: AppText.h1.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                distanceKm == null
                    ? '—'
                    : distanceKm!.toStringAsFixed(1).replaceAll('.', ','),
                style: AppText.h1.copyWith(fontSize: 30),
              ),
              Text(
                km,
                style: AppText.bodyMuted.copyWith(
                  color: AppColors.greenMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
