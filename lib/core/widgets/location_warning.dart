import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../localization/locale_provider.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shown when GPS is off or refused.
///
/// This is the one failure the courier cannot be left to discover on their own:
/// without a fix they simply vanish from the operator's and the customer's map
/// while believing everything is fine.
class LocationWarning extends StatelessWidget {
  const LocationWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    if (location.error == null) return const SizedBox.shrink();

    final s = context.s;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.locationDenied,
            style: AppText.button.copyWith(color: AppColors.red, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(s.locationDeniedHint, style: AppText.bodyMuted),
          const SizedBox(height: 12),
          Row(
            children: [
              _Action(
                label: s.retry,
                onTap: () => context.read<LocationService>().start(),
              ),
              const SizedBox(width: 10),
              _Action(label: s.openSettings, onTap: openAppSettings),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: AppText.chip.copyWith(color: AppColors.green),
          ),
        ),
      ),
    );
  }
}
