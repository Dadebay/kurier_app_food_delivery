import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/branch.dart';
import '../models/courier.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/pending_action.dart';
import '../network/api_client.dart';
import '../services/offline_queue_service.dart';
import '../utils/formatters.dart';
import 'mock/mock_data.dart';

/// The one place the rest of the app talks to for courier data.
///
/// Reads go straight to the server (or the demo data set). Writes never do —
/// they are handed to [OfflineQueueService], which is what makes the app
/// usable in a lift, a basement or a dead cell.
class CourierRepository {
  CourierRepository({
    required ApiClient api,
    required OfflineQueueService queue,
    String? Function()? signedInPhone,
    SharedPreferences? prefs,
  }) : _api = api,
       _queue = queue,
       _signedInPhone = signedInPhone,
       _prefs = prefs;

  final SharedPreferences? _prefs;
  final ApiClient _api;
  final OfflineQueueService _queue;

  /// Fires whenever a queued status transition is rejected by the server
  /// (stale `version`, wrong courier, forbidden transition) — the local order
  /// list is now provably out of date and must be reconciled with the server.
  Stream<void> get conflicts => _queue.conflicts;

  /// Reads the phone verified at sign-in from [AuthRepository], without this
  /// repository depending on it directly. Only used in demo mode, to derive a
  /// mock courier tied to whatever number was typed — see
  /// [MockData.courierFor].
  final String? Function()? _signedInPhone;

  // ─── Reads ───────────────────────────────────────────────────

  Future<Courier> me() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      final owner = _signedInPhone?.call();
      final courier = MockData.courierFor(owner);
      return courier.copyWith(
        onShift: _prefs?.getBool('courier.onShift.$owner') ?? courier.onShift,
      );
    }
    // The backend deliberately reserves /users/me for CUSTOMER. A courier's
    // identity is already authenticated by the JWT used for all courier API
    // calls, so avoid a role-invalid profile request during shift startup.
    final phone = _signedInPhone?.call() ?? '';
    return Courier(
      id: phone.isEmpty ? 'current-courier' : phone,
      name: 'Kurýer',
      phone: phone,
      branchName: '',
      onShift: _prefs?.getBool('courier.onShift.$phone') ?? true,
    );
  }

  /// A delivered order is not finished for the courier: its cash is still in
  /// their pocket until the hand-over, so it has to keep coming back from the
  /// server. CASH_RETURNED is fetched too, otherwise an order would vanish
  /// from the history list the moment it was handed over.
  static const _openStatuses =
      'ASSIGNED_TO_COURIER,OUT_FOR_DELIVERY,DELIVERED,CASH_RETURNED';

  Future<List<DeliveryOrder>> orders() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.orders();
    }

    final results = <DeliveryOrder>[];
    var page = 1;
    while (true) {
      final response = await _api.get(
        ApiPaths.orders,
        query: {'statuses': _openStatuses, 'page': page, 'limit': 100},
      );
      final data = response.data;
      if (response.statusCode == null ||
          response.statusCode! >= 400 ||
          data is! Map<String, dynamic>) {
        throw Exception(
          'Sunucu hatası (${response.statusCode}): ${data is Map ? data['message'] ?? data : data}',
        );
      }
      results.addAll(
        (data['items'] as List<dynamic>? ?? []).map(
          (e) => DeliveryOrder.fromJson(e as Map<String, dynamic>),
        ),
      );

      // Almost always a single page — a courier rarely carries 100+ active
      // orders — but keep paging rather than silently dropping the rest.
      final pages = data['pages'] as int? ?? 1;
      if (page >= pages) break;
      page++;
    }
    return results;
  }

  Future<ShiftSummary> summary() async {
    if (AppConfig.useMockData) {
      await _demoDelay();
      return MockData.summary;
    }
    final orders = await this.orders();
    // Cancelled orders are finished too, but nobody delivered them and no
    // money changed hands — counting them here inflated both figures.
    final delivered = orders
        .where(
          (order) =>
              order.status == OrderStatus.delivered ||
              order.status == OrderStatus.cashReturned,
        )
        .toList();
    return ShiftSummary(
      deliveredCount: delivered.length,
      // Only what has not reached the till yet is still "on hand".
      cashOnHand: delivered
          .where((order) => order.status.awaitsHandOver)
          .fold(0, (sum, order) => sum + order.total),
      handedOver: delivered
          .where((order) => order.status == OrderStatus.cashReturned)
          .fold(0, (sum, order) => sum + order.total),
    );
  }

  /// The branch the courier collects from — the first leg of every route.
  Future<Branch> branch() async {
    if (AppConfig.useMockData) return MockData.branch;
    final response = await _api.get(ApiPaths.branches);
    final data = response.data;
    final list = data is List<dynamic>
        ? data.cast<Map<String, dynamic>>().map(Branch.fromJson).toList()
        : <Branch>[];
    return list.firstWhere(
      (b) => b.isPrimary,
      orElse: () => list.isNotEmpty ? list.first : MockData.branch,
    );
  }

  // ─── Writes (always queued) ──────────────────────────────────

  /// The backend value for each step the courier can drive. Written out
  /// rather than derived, because the two vocabularies genuinely differ:
  /// tapping "Ýola düşdüm" moves the order to OUT_FOR_DELIVERY, and the
  /// hand-over is a transition of its own that used to be impossible to send.
  static String _wire(OrderStatus status) => switch (status) {
    OrderStatus.onTheWay => 'OUT_FOR_DELIVERY',
    OrderStatus.delivered => 'DELIVERED',
    OrderStatus.cashReturned => 'CASH_RETURNED',
    OrderStatus.assigned || OrderStatus.pickedUp || OrderStatus.cancelled =>
      throw ArgumentError('Kurýer bu ýagdaýy ugradyp bilmeýär: $status'),
  };

  /// "Забрал / Выехал / Доставил / Тапшырдым".
  Future<void> setStatus(
    DeliveryOrder order,
    OrderStatus status, {
    String? note,
  }) async {
    final version = order.version;
    await _queue.enqueue(
      PendingAction(
        id: 'status-${order.id}-${status.wire}-${_stamp()}',
        kind: PendingActionKind.status,
        path: ApiPaths.orderStatus(order.id),
        method: 'PATCH',
        body: {
          'status': _wire(status),
          'version': version,
          if (note != null && note.isNotEmpty) 'note': note,
        },
        createdAt: DateTime.now(),
      ),
    );
    // The next queued transition must use the optimistic-lock version the
    // server will have after this transition is accepted.
    order.version = version + 1;
  }

  /// Delivery is recorded through the standard backend transition endpoint.
  ///
  /// The transition DTO has no money fields, so the two amounts the courier
  /// confirmed at the door ride along in `note` — otherwise they were only
  /// ever shown on screen and then thrown away.
  Future<void> confirmCash({
    required DeliveryOrder order,
    required double received,
    required double changeGiven,
  }) => setStatus(
    order,
    OrderStatus.delivered,
    note: 'Alnan: ${Fmt.money(received)}, gaýtargy: ${Fmt.money(changeGiven)}',
  );

  Future<void> setShift({
    required String courierId,
    required bool onShift,
  }) async {
    final owner = _signedInPhone?.call();
    if (owner != null) await _prefs?.setBool('courier.onShift.$owner', onShift);
  }

  static int _stamp() => DateTime.now().microsecondsSinceEpoch;

  /// Makes the demo feel like a real request instead of an instant redraw.
  static Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 350));
}
