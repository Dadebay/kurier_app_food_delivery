import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/locale_provider.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The honest one-line answer to "did my tap actually go through?".
///
/// Shows nothing when everything is synced, a red line when work is waiting on
/// the phone, and a green flash while it is going out.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, this.padding = const EdgeInsets.all(16)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<OfflineQueueService>();
    final connectivity = context.watch<ConnectivityService>();
    final s = context.s;

    final pending = queue.pendingCount;
    final waitingPings = queue.pendingPingCount;
    final sentPings = queue.syncedPingCount;
    if (pending == 0 && connectivity.online) return const SizedBox.shrink();

    final (color, text) = switch ((connectivity.online, pending)) {
      (false, 0) => (AppColors.red, s.offlineNoConnection),
      (false, final n) => (AppColors.red, s.offlineQueued(n)),
      (true, _) => (AppColors.greenLight, s.syncing),
    };

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppText.bodyMuted.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // The tunnel case: the driven line is on the phone, not lost.
                // Showing both numbers is the only way the courier can tell
                // "still waiting" from "already gone".
                if (waitingPings > 0 || sentPings > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        if (sentPings > 0) ...[
                          Icon(Icons.check, size: 13, color: AppColors.greenLight),
                          const SizedBox(width: 4),
                          Text(
                            s.locationsSent(sentPings),
                            style: AppText.bodyMuted.copyWith(fontSize: 11),
                          ),
                        ],
                        if (sentPings > 0 && waitingPings > 0)
                          Text(
                            '  ·  ',
                            style: AppText.bodyMuted.copyWith(fontSize: 11),
                          ),
                        if (waitingPings > 0)
                          Flexible(
                            child: Text(
                              s.locationsWaiting(waitingPings),
                              style: AppText.bodyMuted.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
