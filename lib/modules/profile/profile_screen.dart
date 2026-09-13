import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/services/tile_cache_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_provider.dart';
import '../shift/shift_provider.dart';

/// Courier's own screen: the day's figures, language, map cache and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final locale = context.read<LocaleProvider>();
    final shift = context.watch<ShiftProvider>();
    final queue = context.watch<OfflineQueueService>();
    final tracking = context.watch<TrackingService>();
    final courier = shift.courier;

    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (courier != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courier.name, style: AppText.h2),
                  const SizedBox(height: 4),
                  Text(
                    '${s.branch} ${courier.branchName} · ${courier.phone}',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 18),
                  _Stat(
                    label: s.cashOnHand,
                    value: Fmt.money(shift.summary.cashOnHand),
                    color: AppColors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tells the courier, in plain words, whether the operator can
          // currently see them — the single most support-generating question.
          _Tile(
            icon: AppIcons.myLocation,
            title: tracking.running ? s.onShift : s.free,
            subtitle: tracking.lastSentAt == null
                ? '—'
                : '${s.syncing.replaceAll('…', '')} ${Fmt.time(tracking.lastSentAt!)}',
          ),
          _Tile(
            icon: AppIcons.upload,
            title: queue.hasPending ? s.syncing : s.allSynced,
            subtitle: queue.hasPending ? '${queue.pendingCount}' : null,
            onTap: queue.hasPending ? queue.flush : null,
          ),
          const SizedBox(height: 16),
          Text(s.language, style: AppText.label),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final strings in LocaleProvider.supported)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _LanguageChip(
                      strings: strings,
                      selected: strings.languageCode == s.languageCode,
                      onTap: () => locale.select(strings),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          _Tile(
            icon: AppIcons.map,
            title: s.clearMapCache,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final message = s.mapCacheCleared;
              await TileCacheService.clear();
              messenger.showSnackBar(SnackBar(content: Text(message)));
            },
          ),

          const SizedBox(height: 28),
          AppButton.outline(
            label: s.signOut,
            icon: AppIcons.signOut,
            onPressed: () async {
              final navigator = Navigator.of(context);
              final tracking = context.read<TrackingService>();
              final auth = context.read<AuthProvider>();
              await tracking.stop();
              await auth.signOut();
              navigator.popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.label)),
        Text(value, style: AppText.figure.copyWith(color: color)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                HugeIcon(icon: icon, color: AppColors.green, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: AppText.body)),
                if (subtitle != null) Text(subtitle!, style: AppText.bodyMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Center(
            child: Text(
              strings.languageName,
              style: AppText.button.copyWith(
                fontSize: 15,
                color: selected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
