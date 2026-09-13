import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// The courier's own marker — a car in a white pill with a soft pulse, exactly
/// as in `courier_route.png`.
///
/// The same visual is what the operator and the customer see on their screens,
/// so the courier recognises themselves on any of the three.
class CarMarker extends StatefulWidget {
  const CarMarker({super.key, this.heading = 0, this.size = 54});

  /// Degrees clockwise from north. The car body points along the direction of
  /// travel; below walking speed the GPS heading is noise, so the caller
  /// passes 0 and the car simply faces right.
  final double heading;
  final double size;

  @override
  State<CarMarker> createState() => _CarMarkerState();
}

class _CarMarkerState extends State<CarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring — makes the marker findable at a glance on a busy map.
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              return Container(
                width: widget.size * (0.55 + 0.45 * t),
                height: widget.size * (0.55 + 0.45 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange.withValues(alpha: 0.18 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: widget.size * 0.62,
            height: widget.size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(color: AppColors.orange, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                // SVG is drawn facing right (east) = 90° bearing.
                angle: (widget.heading - 90) * math.pi / 180,
                child: SvgPicture.asset(
                  'assets/icons/car_marker.svg',
                  width: widget.size * 0.36,
                  height: widget.size * 0.36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A customer delivery stop. The profile silhouette distinguishes customers
/// from the branch marker; the small number keeps multi-order routes readable.
class ClientMarker extends StatelessWidget {
  const ClientMarker({
    super.key,
    required this.index,
    this.active = false,
    this.size = 38,
  });

  final int index;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.orange : AppColors.green,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(
              icon: AppIcons.user,
              color: AppColors.white,
              size: size * 0.55,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(
                color: active ? AppColors.orange : AppColors.green,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: size * 0.25,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.orange : AppColors.green,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The branch the food was collected from — a gold pin with a house icon,
/// so it reads as "pickup point" at a glance instead of just another dot.
class BranchMarker extends StatelessWidget {
  const BranchMarker({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: HugeIcon(
          icon: AppIcons.home,
          color: AppColors.white,
          size: size * 0.68,
        ),
      ),
    );
  }
}
