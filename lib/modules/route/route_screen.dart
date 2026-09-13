import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/models/order.dart';
import '../../core/models/order_status.dart';
import '../../core/network/api_client.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/courier_map.dart';
import '../../core/widgets/delivery_success_dialog.dart';
import '../../core/widgets/sync_banner.dart';
import '../shift/shift_provider.dart';
import 'widgets/cash_sheet.dart';
import 'widgets/next_stop_card.dart';

/// The screen the courier lives on: the map, the next stop, and the two
/// buttons that move the order forward.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, this.focusOrderId});

  /// Opened from a specific card in the list — that order becomes the focus
  /// instead of the automatically chosen one.
  final String? focusOrderId;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final GlobalKey<CourierMapState> _mapKey = GlobalKey<CourierMapState>();
  RouteResult _route = RouteResult.empty;
  bool _routeLoading = false;
  bool _routeRebuildScheduled = false;
  bool _busy = false;
  bool _mapFocusMode = false;
  String? _selectedOrderId;
  String? _returnOrderId;
  int _routeRequestGeneration = 0;

  /// The point the last route was built from, so we only rebuild once the
  /// courier has actually driven somewhere.
  LatLng? _routedFrom;

  /// Opened from a specific card → route to that one order only. Opened from
  /// the "Маршрут" FAB with no target picked → the full multi-stop route
  /// through every open order, as before. Fixed for the life of the screen so
  /// tapping a different pin never silently switches the mode.
  late final bool _multiStop;

  @override
  void initState() {
    super.initState();
    _selectedOrderId = widget.focusOrderId;
    _multiStop = widget.focusOrderId == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeLocationAndRoute());
    });
  }

  Future<void> _initializeLocationAndRoute() async {
    final location = context.read<LocationService>();
    if (kDebugMode) {
      debugPrint(
        '\x1B[35m🗺️ [RouteScreen] opening map; '
        'current=${location.current}\x1B[0m',
      );
    }
    final started = await location.start();
    if (!mounted) return;
    if (kDebugMode) {
      final color = location.current == null ? '\x1B[33m⚠️' : '\x1B[32m✅';
      debugPrint(
        '$color [RouteScreen] location start=$started '
        'ready=${location.ready} current=${location.current} '
        'error=${location.error}\x1B[0m',
      );
    }
    await _rebuildRoute(force: true);
  }

  /// The order the buttons act on.
  DeliveryOrder? _focused(ShiftProvider shift) {
    final open = shift.openOrders;
    if (open.isEmpty) return null;

    final selected = _selectedOrderId;
    if (selected != null) {
      for (final order in open) {
        if (order.id == selected) return order;
      }
    }
    return shift.activeOrder;
  }

  DeliveryOrder? _returnOrder(ShiftProvider shift) {
    final id = _returnOrderId;
    if (id == null) return null;
    for (final order in shift.allOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<void> _rebuildRoute({bool force = false}) async {
    if (!mounted || (_routeLoading && !force)) return;

    final shift = context.read<ShiftProvider>();
    final location = context.read<LocationService>();
    final returnOrderId = _returnOrderId;

    // Multi-stop mode routes through every open order; single-target mode
    // (opened from one card) routes to that order alone — the other orders
    // still show as pins on the map, just with no line drawn to them.
    final stops = returnOrderId == null
        ? (_multiStop
              ? shift.openOrders.map((o) => o.address.point).toList()
              : [_focused(shift)?.address.point].whereType<LatLng>().toList())
        : const <LatLng>[];
    if (returnOrderId == null && stops.isEmpty) {
      setState(() => _route = RouteResult.empty);
      return;
    }

    final from = location.current ?? shift.branchPoint;
    if (from == null || (returnOrderId != null && location.current == null)) {
      return;
    }

    final requestGeneration = ++_routeRequestGeneration;
    setState(() => _routeLoading = true);
    final routing = RoutingService(context.read<ApiClient>());
    final result = returnOrderId == null
        ? await routing.route([from, ...stops])
        : await routing.returnToBranch(returnOrderId);
    if (!mounted || requestGeneration != _routeRequestGeneration) return;

    setState(() {
      _route = result;
      _routedFrom = from;
      _routeLoading = false;
    });
  }

  /// Called on every GPS update. Redrawing the whole route on each fix would
  /// hammer the routing server, so we only refresh after ~150 m of travel.
  void _maybeRebuildRoute(LatLng? current) {
    if (current == null || _routeLoading || _routeRebuildScheduled) return;
    final last = _routedFrom;
    if (last != null && LocationService.metersBetween(last, current) < 150) {
      return;
    }

    // This method is called while [build] reads the latest GPS value. Starting
    // the async route immediately would call setState before that build has
    // finished, which throws in debug builds and can leave the map stuck.
    // Schedule one rebuild after the current frame instead.
    _routeRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRebuildScheduled = false;
      if (mounted) unawaited(_rebuildRoute());
    });
  }

  /// The backend always routes through every open order at once — it has no
  /// notion of "just this one stop" — so when only one pin is on screen the
  /// line has to be trimmed by hand, otherwise it keeps pointing through
  /// stops we're deliberately not showing. We cut it at the point closest to
  /// the focused stop, which is the best a plain coordinate list lets us do
  /// without leg boundaries from the server.
  List<LatLng> _clipToFocused(List<LatLng> points, LatLng target) {
    if (points.isEmpty) return points;
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final distance = LocationService.metersBetween(points[i], target);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return points.sublist(0, bestIndex + 1);
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Advances the order. Delivery is the one step that needs confirmation,
  /// because it is also the cash hand-over.
  Future<void> _advance(DeliveryOrder order) async {
    final shift = context.read<ShiftProvider>();
    final s = context.sr;
    final next = order.status.next;
    if (next == null) return;

    setState(() => _busy = true);
    try {
      if (next == OrderStatus.delivered) {
        final confirmed = await CashSheet.show(
          context,
          order: order,
          strings: s,
        );
        if (!confirmed) return;

        await shift.completeDelivery(
          order: order,
          received: order.changeFrom ?? order.total,
          changeGiven: order.changeDue ?? 0,
        );

        // That stop is gone. Continue through any remaining deliveries, or
        // show the real road route back to this order's pickup branch.
        _selectedOrderId = null;
        _returnOrderId = shift.openOrders.isEmpty ? order.id : null;
        unawaited(_rebuildRoute(force: true));

        if (mounted) {
          await DeliverySuccessDialog.show(context, strings: s);
        }
      } else {
        await shift.setStatus(order, next);
        unawaited(_rebuildRoute(force: true));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>();
    final location = context.watch<LocationService>();
    final s = context.s;

    final open = shift.openOrders;
    final focused = _focused(shift);
    final returnOrder = _returnOrder(shift);
    final returning = focused == null && returnOrder != null;
    final contactOrder = focused ?? returnOrder;
    // Prefer the live phone fix. While a vendor GPS provider is warming up,
    // the route API's authenticated fresh courier waypoint keeps the car
    // visible without inventing a position on the client.
    final courierPoint = location.current ?? _route.courierPoint;

    // Single-target mode only plots the focused order unless the courier
    // asks to see the rest; multi-stop mode always shows every open order.
    final showAll = _multiStop;
    final mapOrders = showAll ? open : [?focused];
    final activeIndex = focused == null
        ? null
        : mapOrders.indexWhere((o) => o.id == focused.id);

    // Same reasoning as the pins: don't draw the line past a stop that isn't
    // on screen.
    final routePoints = returning || showAll || focused == null
        ? _route.points
        : _clipToFocused(_route.points, focused.address.point);

    _maybeRebuildRoute(location.current);

    // Still waiting at the branch: the courier's next physical stop is the
    // pickup, not the customer, so the card must point there instead.
    final awaitingPickup = focused?.status == OrderStatus.assigned;

    // Distance to the focused stop: the routed figure when the route actually
    // leads there — always true in single-target mode, only when it's the
    // first leg in multi-stop mode — otherwise straight-line so the number is
    // never blank.
    final routeLeadsToFocused = _multiStop ? activeIndex == 0 : true;
    final distanceKm = focused == null
        ? null
        : (awaitingPickup
              ? (courierPoint != null && shift.branchPoint != null
                    ? LocationService.kmBetween(
                        courierPoint,
                        shift.branchPoint!,
                      )
                    : null)
              : (_route.isEmpty || !routeLeadsToFocused
                    ? focused.distanceKm
                    : _route.distanceKm));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CourierMap(
              key: _mapKey,
              courierPoint: courierPoint,
              courierHeading: location.heading,
              branchPoint: shift.branchPoint,
              stops: mapOrders.map((o) => o.address.point).toList(),
              activeStopIndex: activeIndex == -1 ? null : activeIndex,
              routePoints: routePoints,
              padding: _mapFocusMode
                  ? const EdgeInsets.all(48)
                  : const EdgeInsets.fromLTRB(0, 160, 0, 260),
              onMapTap: () => setState(() => _mapFocusMode = !_mapFocusMode),
              onStopTap: (index) {
                setState(() => _selectedOrderId = mapOrders[index].id);
                // In single-target mode the route itself has to move to the
                // newly picked stop — in multi-stop mode the full route
                // already covers every stop, so only the highlighted pin and
                // bottom sheet change.
                if (!_multiStop) unawaited(_rebuildRoute());
              },
            ),
          ),

          // ── Top: back button and next-stop card share one row ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapButton(
                    icon: AppIcons.back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  if (!_mapFocusMode) const SizedBox(width: 12),
                  if (!_mapFocusMode && (focused != null || returning))
                    Expanded(
                      child: NextStopCard(
                        label: returning
                            ? s.returnToBranch
                            : (awaitingPickup ? s.pickupStop : s.nextStop),
                        addressLine: returning
                            ? (shift.branch?.name ?? returnOrder.branchName)
                            : (awaitingPickup
                                  ? (shift.branch?.name ?? focused!.branchName)
                                  : focused!.address.shortLine(s.houseLabel)),
                        km: s.km,
                        distanceKm: returning && !_route.isEmpty
                            ? _route.distanceKm
                            : distanceKm,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Route-building indicator — floats above the card ───
          if (_routeLoading && !_mapFocusMode)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(s.buildingRoute, style: AppText.bodyMuted),
                  ],
                ),
              ),
            ),

          // ── Right edge: centre on me, and fit the whole route ──
          // The map already follows the courier, but the moment they pan it
          // by hand that stops — this is the way back, and the only way to
          // see where they are when the sheet is covering half the screen.
          if (!_mapFocusMode)
            Positioned(
              right: 16,
              bottom: focused != null
                  ? 280
                  : MediaQuery.paddingOf(context).bottom + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_route.isEmpty)
                    _MapButton(
                      icon: AppIcons.route,
                      tooltip: s.showWholeRoute,
                      onTap: () => _mapKey.currentState?.fitRoute(),
                    ),
                  if (!_route.isEmpty) const SizedBox(height: 12),
                  _MapButton(
                    icon: AppIcons.myLocation,
                    tooltip: s.centerOnMe,
                    onTap: () {
                      final map = _mapKey.currentState;
                      if (map == null) return;
                      if (map.canRecenter) {
                        map.recenter();
                        return;
                      }
                      // No position yet: ask for one instead of doing nothing,
                      // and say so — a dead button reads as a broken app.
                      unawaited(location.currentOrFix());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.waitingForGps)),
                      );
                    },
                  ),
                ],
              ),
            ),

          // ── Bottom sheet: who, call, status buttons ──────────
          if (focused != null && !_mapFocusMode)
            Align(
              alignment: Alignment.bottomCenter,
              child: _OrderSheet(
                order: focused,
                busy: _busy,
                onCall: () => _call(focused.customerPhone),
                onAdvance: () => _advance(focused),
                onPickUp: focused.status == OrderStatus.assigned
                    ? () => _advance(focused)
                    : null,
              ),
            ),

          // Navigation focus mode removes every non-essential control. The
          // back button above remains available and customer calling stays a
          // single tap away in the lower-right corner.
          if (_mapFocusMode && contactOrder != null)
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: _MapButton(
                icon: AppIcons.call,
                tooltip: s.callCustomer,
                onTap: () => _call(contactOrder.customerPhone),
              ),
            ),
        ],
      ),
    );
  }
}

/// White round map control — matches the floating look of the mock-up.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap, this.tooltip});

  final HugeIconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(icon: icon, color: AppColors.green, size: 22),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}

class _OrderSheet extends StatelessWidget {
  const _OrderSheet({
    required this.order,
    required this.busy,
    required this.onCall,
    required this.onAdvance,
    required this.onPickUp,
  });

  final DeliveryOrder order;
  final bool busy;
  final VoidCallback onCall;
  final VoidCallback onAdvance;
  final VoidCallback? onPickUp;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final canDeliver =
        order.status == OrderStatus.onTheWay ||
        order.status == OrderStatus.pickedUp;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.orderNo} №${order.number}',
                          style: AppText.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.customerName} · ${Fmt.phone(order.customerPhone)}',
                          style: AppText.bodyMuted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Calling the customer is one tap from the map: the most
                  // common reason a delivery stalls is a wrong entrance.
                  Tooltip(
                    message: s.callCustomer,
                    child: Material(
                      color: AppColors.greenLight,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onCall,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(15),
                          child: HugeIcon(
                            icon: AppIcons.call,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (order.address.note != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(order.address.note!, style: AppText.bodyMuted),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: order.status == OrderStatus.assigned
                          ? s.actionPickUp
                          : s.actionDepart,
                      busy: busy && !canDeliver,
                      onPressed: order.status == OrderStatus.onTheWay
                          ? null
                          : (onPickUp ?? onAdvance),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: s.actionDeliver,
                      busy: busy && canDeliver,
                      onPressed: canDeliver ? onAdvance : null,
                    ),
                  ),
                ],
              ),
              const SyncBanner(padding: EdgeInsets.only(top: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
