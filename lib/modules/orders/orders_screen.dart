import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/services/data_usage_service.dart';
import '../../core/services/tracking_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/delivery_loader.dart';
import '../../core/widgets/location_warning.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/shift_readiness_gate.dart';
import '../../core/widgets/sync_banner.dart';
import '../auth/auth_provider.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/data_usage_screen.dart';
import '../route/route_screen.dart';
import '../shift/shift_provider.dart';
import 'widgets/order_card.dart';
import 'widgets/shift_header.dart';

/// Home screen — everything assigned to this courier, nearest first.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from the system settings screen is the one moment a grant
    // can change without the app being told. Without this the courier would
    // flip "Allow all the time" on and still be warned they hadn't.
    _lifecycle = AppLifecycleListener(onResume: _refreshReadiness);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shift = context.read<ShiftProvider>();
      if (shift.courier == null) shift.load();
      // ShiftProvider owns location startup, including persisted off-shift state.
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _refreshReadiness() {
    if (!mounted) return;
    final location = context.read<LocationService>();
    unawaited(location.refreshBatteryExemption());
    // Status only — a resume must never raise a permission dialog. No-op off
    // shift, and no-op once background mode is already running.
    unawaited(location.refreshBackgroundStatus());
  }

  /// Going on shift is the promise that the operator can see this courier.
  /// Everything Android needs for that to survive a locked screen is asked
  /// for here, before the shift is reported as started.
  Future<void> _toggleShift(bool goingOnShift) async {
    if (goingOnShift && !await ShiftReadinessGate.ensure(context)) return;
    if (!mounted) return;
    await context.read<ShiftProvider>().toggleShift();
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>();
    final dataUsage = context.watch<DataUsageService>();
    final s = context.s;
    final courier = shift.courier;

    // Off shift hides everything else — orders, the route button — and shows
    // only the status in the middle of the screen.
    final offShift = courier != null && !courier.onShift;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          if (courier != null)
            ShiftHeader(
              courier: courier,
              strings: s,
              dataUsage: dataUsage.isSupported
                  ? DataUsageService.formatBytes(dataUsage.totalBytes)
                  : '—',
              onToggleShift: () => _toggleShift(!courier.onShift),
              onOpenProfile: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              // Day total + delivery history live on their own page — nothing
              // about them sits at the bottom of this screen any more, so
              // there is nothing left for the route FAB to collide with.
              onOpenHistory: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
              onOpenDataUsage: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DataUsageScreen(),
                ),
              ),
            )
          else
            Container(
              color: AppColors.green,
              height: MediaQuery.paddingOf(context).top + 140,
            ),
          const SyncBanner(padding: EdgeInsets.fromLTRB(20, 12, 20, 0)),
          const LocationWarning(),
          Expanded(
            child: shift.loading
                ? const _LoadingList()
                : shift.error != null && shift.allOrders.isEmpty
                ? _LoadFailed(error: shift.error)
                : offShift
                ? const _OffShiftEmpty()
                : RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: () => context.read<ShiftProvider>().refresh(),
                    // Finished orders live on the history page now — this
                    // list is only what's still left to deliver.
                    child: _OrderList(orders: shift.openOrders),
                  ),
          ),
        ],
      ),
      floatingActionButton: offShift || shift.openOrders.isEmpty
          ? null
          // One tap from anywhere in the list to the live route — the screen
          // couriers spend the whole shift on.
          : FloatingActionButton.extended(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.white,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RouteScreen())),
              icon: const HugeIcon(
                icon: AppIcons.route,
                color: AppColors.white,
                size: 22,
              ),
              label: Text(s.actionOpenRoute, style: AppText.button),
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});

  final List<DeliveryOrder> orders;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          const Center(
            child: HugeIcon(
              icon: AppIcons.package,
              color: AppColors.textMuted,
              size: 56,
            ),
          ),
          const SizedBox(height: 18),
          Center(child: Text(s.noOrders, style: AppText.h2)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              s.noOrdersHint,
              textAlign: TextAlign.center,
              style: AppText.bodyMuted,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          strings: s,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RouteScreen(focusOrderId: order.id),
            ),
          ),
        );
      },
    );
  }
}

/// Replaces the list entirely while off shift — nothing left to do here until
/// the courier goes back on. Deliberately just the status, centred: no list,
/// no totals, no route button underneath it.
class _OffShiftEmpty extends StatelessWidget {
  const _OffShiftEmpty();

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: AppIcons.offShift,
            color: AppColors.textMuted,
            size: 56,
          ),
          const SizedBox(height: 18),
          Text(s.offShiftBadge, style: AppText.h2),
        ],
      ),
    );
  }
}

/// Nothing loaded and no cached list to fall back on — offer the one action
/// that can help rather than an empty screen.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sunucuya bağlanılamadı',
              textAlign: TextAlign.center,
              style: AppText.h2,
            ),
            const SizedBox(height: 20),
            Text(
              'İnternet bağlantınız açık olabilir. Yerel API adresini, aynı Wi-Fi ağını ve kurier hesabını kontrol edin.',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.bodyMuted.copyWith(fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: AppButton(
                label: s.retry,
                onPressed: () => context.read<ShiftProvider>().load(),
              ),
            ),
            // A session (token expired/invalid) can fail here forever — with
            // no courier ever loaded there is no ShiftHeader, and it is the
            // only other place sign-out lives. Without this, retry is a dead
            // end.
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              child: AppButton.outline(
                label: s.signOut,
                onPressed: () async {
                  final tracking = context.read<TrackingService>();
                  final auth = context.read<AuthProvider>();
                  await tracking.stop();
                  await auth.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DeliveryLoader(size: 220, message: context.s.loadingOrders),
    );
  }
}
