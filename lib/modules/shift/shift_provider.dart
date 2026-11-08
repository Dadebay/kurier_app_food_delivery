import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data/courier_repository.dart';
import '../../core/models/branch.dart';
import '../../core/models/courier.dart';
import '../../core/models/order.dart';
import '../../core/models/order_status.dart';
import '../../core/services/location_service.dart';
import '../../core/services/tracking_service.dart';

/// The courier's working day: who they are, what is assigned, how much cash
/// they are carrying.
///
/// Status changes are applied to the local list first and handed to the offline
/// queue second — the courier's screen must never wait on the network to
/// confirm a tap they just made.
class ShiftProvider extends ChangeNotifier {
  ShiftProvider({
    required CourierRepository repository,
    required LocationService location,
    required TrackingService tracking,
  }) : _repository = repository,
       _location = location,
       _tracking = tracking {
    _location.addListener(_onLocationChanged);
    // A rejected status write means the local list is stale — re-read from
    // the server instead of leaving the courier looking at an order state
    // the backend never actually accepted.
    _conflictSub = _repository.conflicts.listen((_) => refresh());
  }

  final CourierRepository _repository;
  final LocationService _location;
  final TrackingService _tracking;
  late final StreamSubscription<void> _conflictSub;

  Courier? _courier;
  List<DeliveryOrder> _orders = const [];
  ShiftSummary _summary = ShiftSummary.empty;
  Branch? _branch;

  bool _loading = true;
  Object? _error;

  Courier? get courier => _courier;
  ShiftSummary get summary => _summary;
  Branch? get branch => _branch;
  LatLng? get branchPoint => _branch?.point;
  bool get loading => _loading;
  Object? get error => _error;

  /// Everything still to deliver, nearest stop first — this is the order the
  /// route screen numbers the pins in.
  List<DeliveryOrder> get openOrders =>
      _orders.where((o) => o.status.isOpen).toList();

  List<DeliveryOrder> get allOrders => _orders;

  /// Finished orders (delivered or cancelled), most recently completed first —
  /// this is what the history page splits into "today" and "archive".
  List<DeliveryOrder> get historyOrders {
    final finished = _orders.where((o) => !o.status.isOpen).toList();
    finished.sort((a, b) {
      final aTime = a.completedAt ?? a.assignedAt;
      final bTime = b.completedAt ?? b.assignedAt;
      return bTime.compareTo(aTime);
    });
    return finished;
  }

  /// The delivery the courier is working on right now: the one already picked
  /// up or under way, otherwise the closest one still in the queue.
  DeliveryOrder? get activeOrder {
    final open = openOrders;
    if (open.isEmpty) return null;
    return open.firstWhere(
      (o) =>
          o.status == OrderStatus.onTheWay || o.status == OrderStatus.pickedUp,
      orElse: () => open.first,
    );
  }

  /// Cash the courier should be holding: the shift figure plus everything
  /// collected since the last refresh.
  double get cashOnHand => _summary.cashOnHand;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.me(),
        _repository.orders(),
        _repository.summary(),
        _repository.branch(),
      ]);

      _courier = results[0] as Courier;
      _orders = results[1] as List<DeliveryOrder>;
      _summary = results[2] as ShiftSummary;
      _branch = results[3] as Branch;

      _sortByDistance();

      if (_courier!.onShift) {
        unawaited(_tracking.start(_courier!.id));
      }
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _repository.orders(),
        _repository.summary(),
      ]);
      _orders = results[0] as List<DeliveryOrder>;
      _summary = results[1] as ShiftSummary;
      _sortByDistance();
      notifyListeners();
    } catch (error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Moves an order one step along: assigned → picked up → on the way →
  /// delivered.
  Future<void> advance(DeliveryOrder order) async {
    final next = order.status.next;
    if (next == null) return;
    await setStatus(order, next);
  }

  Future<void> setStatus(DeliveryOrder order, OrderStatus status) async {
    order.status = status;
    if (!status.isOpen) order.completedAt ??= DateTime.now();
    _sortByDistance();
    notifyListeners();

    await _repository.setStatus(order, status);
  }

  /// Called from the cash sheet when the courier confirms the hand-over.
  Future<void> completeDelivery({
    required DeliveryOrder order,
    required double received,
    required double changeGiven,
  }) async {
    order.status = OrderStatus.delivered;
    order.completedAt = DateTime.now();

    // Reflect the money immediately — the courier is standing at the door and
    // the day-total bar should already be right when they look down.
    _summary = ShiftSummary(
      deliveredCount: _summary.deliveredCount + 1,
      cashOnHand: _summary.cashOnHand + order.total,
      handedOver: _summary.handedOver,
    );
    notifyListeners();

    await _repository.confirmCash(
      order: order,
      received: received,
      changeGiven: changeGiven,
    );
  }

  Future<void> toggleShift() async {
    final courier = _courier;
    if (courier == null) return;

    final next = !courier.onShift;
    _courier = courier.copyWith(onShift: next);
    notifyListeners();

    if (next) {
      unawaited(_tracking.start(courier.id));
    } else {
      unawaited(_tracking.stop());
    }

    await _repository.setShift(courierId: courier.id, onShift: next);
  }

  /// Straight-line distance is recomputed on every GPS fix so the list stays
  /// sorted by "what is closest to me right now".
  void _onLocationChanged() {
    if (_location.current == null || _orders.isEmpty) return;
    _sortByDistance();
    notifyListeners();
  }

  void _sortByDistance() {
    final from = _location.current;
    if (from != null) {
      for (final order in _orders) {
        order.distanceKm = LocationService.kmBetween(from, order.address.point);
      }
    }

    _orders.sort((a, b) {
      // Finished orders drop to the bottom.
      if (a.status.isOpen != b.status.isOpen) return a.status.isOpen ? -1 : 1;
      // The one in hand stays on top regardless of distance.
      final aActive =
          a.status == OrderStatus.onTheWay || a.status == OrderStatus.pickedUp;
      final bActive =
          b.status == OrderStatus.onTheWay || b.status == OrderStatus.pickedUp;
      if (aActive != bActive) return aActive ? -1 : 1;

      final aKm = a.distanceKm ?? double.maxFinite;
      final bKm = b.distanceKm ?? double.maxFinite;
      return aKm.compareTo(bKm);
    });
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    unawaited(_conflictSub.cancel());
    super.dispose();
  }
}
