import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../localization/locale_provider.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// The two things Android needs before a shift can survive a locked screen,
/// asked for at the one moment the courier is actually looking at the phone:
/// the tap that starts the shift.
///
/// Neither one hard-blocks the shift. A courier standing next to a car with
/// orders to deliver must never be locked out of working by a permission
/// dialog — but they must also never find out hours later that the operator
/// saw nothing. So each gate explains the cost and lets them go on anyway,
/// and [LocationWarning] keeps the reminder on screen for the whole shift.
class ShiftReadinessGate {
  const ShiftReadinessGate._();

  /// Returns whether the shift should start.
  static Future<bool> ensure(BuildContext context) async {
    final location = context.read<LocationService>();
    final strings = context.read<LocaleProvider>().strings;

    if (!await location.ensureBackgroundPermission()) {
      if (!context.mounted) return false;
      final choice = await _ask(
        context,
        icon: AppIcons.myLocation,
        accent: AppColors.red,
        title: strings.backgroundGateTitle,
        body: strings.backgroundGateBody,
        primary: strings.openSettings,
        secondary: strings.backgroundGateStartAnyway,
      );
      if (choice == null) return false;
      if (choice == _Choice.primary) {
        // Settings replaces the app; the shift starts on the next tap, by
        // which point the resume hook has re-read the grant.
        await location.openBackgroundPermissionSettings();
        return false;
      }
    }

    await location.refreshBatteryExemption();
    if (!location.batteryUnrestricted) {
      if (!context.mounted) return true;
      final choice = await _ask(
        context,
        icon: AppIcons.battery,
        accent: AppColors.gold,
        title: strings.batteryGateTitle,
        body: strings.batteryGateBody,
        primary: strings.batteryGateAllow,
        secondary: strings.batteryGateSkip,
      );
      // The system dialog resolves in place, so the shift starts either way.
      if (choice == _Choice.primary) await location.requestBatteryExemption();
    }

    return true;
  }

  static Future<_Choice?> _ask(
    BuildContext context, {
    required HugeIconData icon,
    required Color accent,
    required String title,
    required String body,
    required String primary,
    required String secondary,
  }) {
    return showDialog<_Choice>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x99000000),
      builder: (dialogContext) => _GateDialog(
        icon: icon,
        accent: accent,
        title: title,
        body: body,
        primary: primary,
        secondary: secondary,
      ),
    );
  }
}

enum _Choice { primary, secondary }

class _GateDialog extends StatelessWidget {
  const _GateDialog({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
  });

  final HugeIconData icon;
  final Color accent;
  final String title;
  final String body;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: HugeIcon(icon: icon, color: AppColors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(title, style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(body, style: AppText.bodyMuted, textAlign: TextAlign.center),
              const SizedBox(height: 26),
              AppButton(
                label: primary,
                onPressed: () =>
                    Navigator.of(context).pop(_Choice.primary),
              ),
              const SizedBox(height: 10),
              AppButton.outline(
                label: secondary,
                onPressed: () =>
                    Navigator.of(context).pop(_Choice.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}