import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/data_usage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// A transparent view of data used by this courier application.
class DataUsageScreen extends StatelessWidget {
  const DataUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final usage = context.watch<DataUsageService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.dataUsage),
        actions: [
          IconButton(
            tooltip: s.resetDataUsage,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: AppColors.green,
            ),
            onPressed: () => _reset(context, usage, s),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _TotalCard(usage: usage, title: s.appDataUsed),
          const SizedBox(height: 16),
          if (!usage.isSupported)
            _UnavailableCard(text: s.dataUsageUnavailable)
          else ...[
            // Iki kart esit yukseklikte dursun: etiketlerin biri iki satira
            // kaydiginda (orn. "Мобильный интернет") o kart uzuyor, digeri
            // kendi icerigi kadar kaliyordu. Row varsayilan olarak cocuklari
            // ortaladigi icin de aradaki fark hem ust hem alt kenarda
            // goruluyordu. IntrinsicHeight satira uzun kartin yuksekligini
            // verir, `stretch` de ikisini o yuksekige yayar.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: HugeIcons.strokeRoundedSignal,
                      label: s.mobileData,
                      value: DataUsageService.formatBytes(usage.mobileBytes),
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: HugeIcons.strokeRoundedWifi01,
                      label: s.wifiData,
                      value: DataUsageService.formatBytes(usage.wifiBytes),
                      color: AppColors.greenLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _MonthCard(usage: usage, title: s.dataUsedLast30Days),
            const SizedBox(height: 16),
            _HistorySection(usage: usage, strings: s),
            const SizedBox(height: 16),
            _NoteCard(text: s.dataUsageNote),
          ],
        ],
      ),
    );
  }

  Future<void> _reset(
    BuildContext context,
    DataUsageService usage,
    AppStrings s,
  ) async {
    await usage.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.dataUsageReset)));
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.usage, required this.title});

  final DataUsageService usage;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedDatabase01,
            color: AppColors.goldSoft,
            size: 24,
          ),
          const SizedBox(height: 16),
          Text(
            usage.isSupported
                ? DataUsageService.formatBytes(usage.totalBytes)
                : '—',
            style: AppText.h1.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 5),
          Text(title, style: AppText.body.copyWith(color: AppColors.cream)),
        ],
      ),
    );
  }
}

/// The 30-day total, with mobile and Wi-Fi split out — the mobile figure is
/// the one that costs the courier money, so it gets its own line rather than
/// being folded into a single number.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.usage, required this.title});

  final DataUsageService usage;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            color: AppColors.green,
            size: 21,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DataUsageService.formatBytes(usage.monthBytes),
                  style: AppText.figure,
                ),
                const SizedBox(height: 4),
                Text(title, style: AppText.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Day-by-day breakdown, newest first.
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.usage, required this.strings});

  final DataUsageService usage;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final days = usage.history;
    final today = days.isEmpty ? null : days.first.date;
    final yesterday = usage.yesterday?.date;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.dataUsageByDay,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          // A single entry means only today has ever been measured; a list of
          // one row would look like the history feature is broken.
          if (days.length < 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(strings.dataUsageNoHistory, style: AppText.bodyMuted),
            )
          else
            for (final day in days)
              _HistoryRow(
                label: switch (day.date) {
                  final d when d == today => strings.dataUsageToday,
                  final d when d == yesterday => strings.dataUsageYesterday,
                  _ => _formatDay(day.day),
                },
                day: day,
              ),
        ],
      ),
    );
  }

  static String _formatDay(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.'
      '${day.month.toString().padLeft(2, '0')}';
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.day});

  final String label;
  final DailyUsage day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(label, style: AppText.bodyMuted)),
          // Mobile bytes are what shows up on the bill, so they lead; Wi-Fi
          // sits behind the total as the quieter half.
          Expanded(
            child: Text(
              DataUsageService.formatBytes(day.mobileBytes),
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ),
          Text(
            DataUsageService.formatBytes(day.totalBytes),
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: color, size: 21),
          const SizedBox(height: 16),
          Text(value, style: AppText.figure),
          const SizedBox(height: 4),
          Text(label, style: AppText.bodyMuted),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.goldSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: AppColors.gold,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13))),
      ],
    ),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          color: AppColors.orange,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.body)),
      ],
    ),
  );
}
