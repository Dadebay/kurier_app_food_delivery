import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The app's loading animation — the delivery scooter clip, looping.
///
/// The asset is a muted MP4 played through [VideoPlayerController.asset]. It is
/// decoded locally and looped in place, so nothing is downloaded and it keeps
/// working with no connection.
class DeliveryLoader extends StatefulWidget {
  const DeliveryLoader({super.key, this.size = 200, this.message});

  /// Width of the animation. Height follows the clip's own aspect ratio.
  final double size;

  /// Optional caption underneath.
  final String? message;

  static const String asset = 'assets/animations/delivery_loader.mp4';

  @override
  State<DeliveryLoader> createState() => _DeliveryLoaderState();
}

class _DeliveryLoaderState extends State<DeliveryLoader> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(DeliveryLoader.asset)
      ..setLooping(true)
      ..setVolume(0);

    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.play();
          setState(() => _ready = true);
        })
        .catchError((Object _) {
          // A decode failure must not take the screen down with it — the caption
          // and the layout stay, the animation simply does not appear.
          if (mounted) setState(() => _ready = false);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 4:3 keeps the slot the right size before the clip reports its own ratio,
    // so the surrounding layout does not jump when it appears.
    final aspect = _ready ? _controller.value.aspectRatio : 4 / 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size / aspect,
          child: _ready
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.orange,
                    ),
                  ),
                ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
        ],
      ],
    );
  }
}
