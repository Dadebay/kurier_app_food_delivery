import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';

import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// Confetti burst + confirmation card shown right after a delivery is
/// completed — the one moment in a courier's shift that's worth celebrating
/// instead of silently moving on to the next stop.
class DeliverySuccessDialog extends StatelessWidget {
  const DeliverySuccessDialog._({required this.strings});

  final AppStrings strings;

  static Future<void> show(
    BuildContext context, {
    required AppStrings strings,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.deliverySuccessTitle,
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => DeliverySuccessDialog._(strings: strings),
      transitionBuilder: (_, animation, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Plays once, wide enough to spill past the card's edges.
        Positioned.fill(
          child: IgnorePointer(
            child: Lottie.asset(
              'assets/animations/Confetti.json',
              repeat: false,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                    decoration: const BoxDecoration(
                      color: AppColors.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: AppIcons.checkSuccess,
                      color: AppColors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.deliverySuccessTitle,
                    style: AppText.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.deliverySuccessMessage,
                    style: AppText.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  AppButton(
                    label: strings.deliverySuccessButton,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
