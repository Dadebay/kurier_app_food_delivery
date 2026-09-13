import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/models/order_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../shift/shift_provider.dart';
import 'order_detail_screen.dart';
import 'widgets/history_order_card.dart';

/// Everything the courier has already delivered — the day total lives here now
/// instead of on the working list, and anything completed two or more days ago
/// drops into a separate archive section.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /// Completed orders older than this move from "recent" into the archive.
  static const _archiveAfter = Duration(days: 2);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final shift = context.watch<ShiftProvider>();
    final orders = shift.historyOrders;

    final now = DateTime.now();
    final recent = <DeliveryOrder>[];
    final archived = <DeliveryOrder>[];
    for (final order in orders) {
      final completedAt = order.completedAt ?? order.assignedAt;
      if (now.difference(completedAt) >= _archiveAfter) {
        archived.add(order);
      } else {
        recent.add(order);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text(s.historyTitle)),
      body: orders.isEmpty
          ? _Empty(hint: s.historyEmptyHint)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _SummaryCard(
                  deliveredCount: shift.summary.deliveredCount,
                  cashOnHand: shift.summary.cashOnHand,
                  dayTotalLabel: s.dayTotal,
                  cashOnHandLabel: s.cashOnHand,
                  deliveriesLabel: s.deliveries(shift.summary.deliveredCount),
                ),
                const SizedBox(height: 24),
                if (recent.isNotEmpty) ...[
                  _SectionLabel(s.historyRecent),
                  const SizedBox(height: 10),
                  // Only the money still in the pocket can be handed over;
                  // archived orders were settled days ago.
                  ..._dayGroups(context, recent, s),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SectionLabel(s.historyArchive),
                  const SizedBox(height: 10),
                  ..._dayGroups(context, archived, s),
                ],
              ],
            ),
    );
  }

  void _openDetail(BuildContext context, DeliveryOrder order) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
  }

  /// Splits an already date-sorted order list into calendar-day runs and
  /// renders each run's cards followed by that day's total — cancelled
  /// orders never collected cash, so they're left out of the sum.
  List<Widget> _dayGroups(
    BuildContext context,
    List<DeliveryOrder> orders,
    AppStrings s,
  ) {
    final widgets = <Widget>[];
    List<DeliveryOrder>? dayOrders;
    DateTime? day;

    void flushDay() {
      if (dayOrders == null || day == null) return;
      final total = dayOrders
          .where((o) => o.status != OrderStatus.cancelled)
          .fold<double>(0, (sum, o) => sum + o.total);
      widgets.add(_DayTotalRow(date: day, label: s.dayTotal, amount: total));
      widgets.add(const SizedBox(height: 14));
    }

    for (final order in orders) {
      final at = order.completedAt ?? order.assignedAt;
      final orderDay = DateTime(at.year, at.month, at.day);
      if (day != orderDay) {
        flushDay();
        day = orderDay;
        dayOrders = [];
      }
      dayOrders!.add(order);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HistoryOrderCard(
            order: order,
            strings: s,
            onTap: () => _openDetail(context, order),
          ),
        ),
      );
    }
    flushDay();
    if (widgets.isNotEmpty) widgets.removeLast(); // drop trailing spacer
    return widgets;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.deliveredCount,
    required this.cashOnHand,
    required this.dayTotalLabel,
    required this.cashOnHandLabel,
    required this.deliveriesLabel,
  });

  final int deliveredCount;
  final double cashOnHand;
  final String dayTotalLabel;
  final String cashOnHandLabel;
  final String deliveriesLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayTotalLabel, style: AppText.label.copyWith(color: AppColors.green)),
                const SizedBox(height: 6),
                Text(deliveriesLabel, style: AppText.figure.copyWith(fontSize: 20)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cashOnHandLabel, style: AppText.label.copyWith(color: AppColors.green)),
              const SizedBox(height: 6),
              Text(Fmt.money(cashOnHand), style: AppText.figure.copyWith(fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sits right after the last card of a calendar day — the running total for
/// that day, not the whole shift (that lives in [_SummaryCard] above).
class _DayTotalRow extends StatelessWidget {
  const _DayTotalRow({
    required this.date,
    required this.label,
    required this.amount,
  });

  final DateTime date;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${Fmt.date(date)} · $label', style: AppText.bodyMuted),
          Text(
            Fmt.money(amount),
            style: AppText.body.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppText.label),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(icon: AppIcons.package, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(hint, textAlign: TextAlign.center, style: AppText.bodyMuted),
          ],
        ),
      ),
    );
  }
}
