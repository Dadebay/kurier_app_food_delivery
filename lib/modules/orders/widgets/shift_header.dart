import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/models/courier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dark green header of the order list: who is working, out of which branch,
/// and the on-shift switch.
class ShiftHeader extends StatelessWidget {
  const ShiftHeader({
    super.key,
    required this.courier,
    required this.strings,
    required this.dataUsage,
    required this.onToggleShift,
    required this.onOpenProfile,
    required this.onOpenHistory,
    required this.onOpenDataUsage,
  });

  final Courier courier;
  final AppStrings strings;
  final String dataUsage;
  final VoidCallback onToggleShift;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDataUsage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.courierRole} · ${strings.branch} '
                      '${courier.branchName.toUpperCase()}',
                      style: AppText.label.copyWith(
                        color: AppColors.greenMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(courier.name, style: AppText.h1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DataUsageBadge(
                label: strings.dataUsage,
                value: dataUsage,
                onTap: onOpenDataUsage,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(icon: AppIcons.history, onTap: onOpenHistory),
              const SizedBox(width: 8),
              _HeaderIconButton(icon: AppIcons.user, onTap: onOpenProfile),
            ],
          ),
          const SizedBox(height: 20),
          _ShiftToggle(
            onShift: courier.onShift,
            strings: strings,
            onToggle: onToggleShift,
          ),
        ],
      ),
    );
  }
}

class _DataUsageBadge extends StatelessWidget {
  const _DataUsageBadge({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HugeIcon(
                  icon: AppIcons.internet,
                  color: AppColors.white,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  value,
                  style: AppText.label.copyWith(
                    color: AppColors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final HugeIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenSurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(icon: icon, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}

/// "На смене" / "Свободен". Going off shift stops the position reporting, so
/// the operator stops seeing the courier as available.
class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({
    required this.onShift,
    required this.strings,
    required this.onToggle,
  });

  final bool onShift;
  final AppStrings strings;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Segment(
            label: strings.onShift,
            selected: onShift,
            onTap: onShift ? null : onToggle,
          ),
          _Segment(
            label: strings.free,
            selected: !onShift,
            onTap: onShift ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? AppColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.button.copyWith(
              color: selected ? AppColors.white : AppColors.greenMuted,
            ),
          ),
        ),
      ),
    );
  }
}
