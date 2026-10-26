import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../localization/locale_provider.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Explains missing/stale measurements separately from permission denial.
///
/// This is the one failure the courier cannot be left to discover on their own:
/// without a fix they simply vanish from the operator's and the customer's map
/// while believing everything is fine.
class LocationWarning extends StatelessWidget {
  const LocationWarning({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    if (!location.active) return const SizedBox.shrink();
    final waiting = location.current == null || location.isStale;
    if (!waiting &&
        location.error == null &&
        location.backgroundGranted &&
        location.batteryUnrestricted) {
      return const SizedBox.shrink();
    }

    final s = context.s;
    final denied = location.error == 'location_permission_denied';
    final serviceOff = location.error == 'location_service_off';
    // Battery throttling only surfaces once nothing more urgent is wrong —
    // it costs the courier the shift's tail end, not the next fix.
    final throttled =
        !waiting && !denied && !serviceOff && location.backgroundGranted;
    final title = denied
        ? s.locationDenied
        : serviceOff
        ? s.locationServiceOff
        : waiting
        ? s.locationWaiting
        : throttled
        ? s.batteryGateTitle
        : s.locationBackgroundHint;
    final hint = denied
        ? s.locationDeniedHint
        : throttled
        ? s.batteryGateBody
        : s.locationWaitingHint;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.bodyMuted.copyWith(color: AppColors.red),
            ),
            if (location.currentAge != null)
              Text(
                s.locationAge(_nonNegative(location.currentAge!)),
                style: AppText.bodyMuted,
              ),
          ],
        ),
      );
    }

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
            title,
            style: AppText.button.copyWith(color: AppColors.red, fontSize: 15),
          ),
          const SizedBox(height: 6),
          if (waiting || denied || serviceOff || throttled)
            Text(hint, style: AppText.bodyMuted),
          if (location.currentAge != null)
            Text(
              s.locationAge(_nonNegative(location.currentAge!)),
              style: AppText.bodyMuted,
            ),
          if (location.accuracy != null)
            Text(
              s.locationAccuracy(location.accuracy!.round()),
              style: AppText.bodyMuted,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (throttled)
                _Action(
                  label: s.batteryGateAllow,
                  onTap: location.requestBatteryExemption,
                )
              else
                _Action(label: s.retry, onTap: location.retry),
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

/// A clock that jumped backwards — a phone correcting its time, a fix
/// timestamped slightly in the future — would otherwise read as a negative
/// age.
Duration _nonNegative(Duration age) => age.isNegative ? Duration.zero : age;
