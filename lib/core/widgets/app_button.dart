import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';

/// Full-width action button. Big hit area on purpose — couriers tap these one
/// handed, standing next to a car.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.orange,
    this.textColor = AppColors.white,
    this.outlined = false,
    this.busy = false,
    this.icon,
    this.height = 56,
  });

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.height = 56,
  }) : color = AppColors.divider,
       textColor = AppColors.green,
       outlined = true;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool outlined;
  final bool busy;
  final HugeIconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    return SizedBox(
      height: height,
      child: Material(
        color: outlined ? AppColors.white : color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: outlined
                  ? Border.all(color: AppColors.divider, width: 1.5)
                  : null,
              color: enabled
                  ? null
                  // Dim rather than grey out — the label must stay readable
                  // in direct sunlight.
                  : (outlined ? null : color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(textColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          HugeIcon(icon: icon!, size: 20, color: textColor),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: AppText.button.copyWith(color: textColor),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
