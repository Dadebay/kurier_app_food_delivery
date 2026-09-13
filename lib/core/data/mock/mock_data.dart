import 'package:latlong2/latlong.dart';

import '../../models/branch.dart';
import '../../models/courier.dart';
import '../../models/delivery_address.dart';
import '../../models/order.dart';
import '../../models/order_status.dart';

/// Demo data set — the exact shift shown in the approved mock-ups
/// (`Naharym-mockups-RU/courier_list.png`).
///
/// It lets the whole courier flow be demonstrated and tested before the
/// backend is installed. Flip [AppConfig.useMockData] to `false` to switch
/// every repository call over to the real server.
class MockData {
  const MockData._();

  /// Parahat branch — the pick-up point every route starts from.
  static final Branch branch = Branch(
    name: 'Parahat',
    address: 'Parahat 7, Aşgabat',
    point: LatLng(37.9265, 58.4055),
    isPrimary: true,
  );

  static LatLng get branchPoint => branch.point;

  static const Courier courier = Courier(
    id: 'crr-1',
    name: 'Мырат Аннаев',
    phone: '+99365123456',
    branchName: 'Parahat',
    onShift: true,
  );

  /// Real deployments register the courier's name in the admin panel
  /// (proposal slide 11, "Сотрудники и роли") — the app itself never asks for
  /// a name, only the phone + SMS code. In demo mode there is no admin panel
  /// behind it, so [courier] alone would show the same fixed name no matter
  /// which phone number is typed. This derives a name from the phone instead,
  /// deterministically, purely so the demo feels tied to what was typed.
  static Courier courierFor(String? phone) {
    if (phone == null || phone.isEmpty) return courier;

    const names = [
      'Мырат Аннаев',
      'Сердар Гурбанов',
      'Ровшен Атаев',
      'Максат Оразов',
      'Батыр Сапаров',
      'Азат Мамедов',
      'Довлет Ходжаев',
      'Гуванч Нурыев',
    ];
    final digitSum = phone.codeUnits.fold<int>(0, (sum, code) => sum + code);

    return Courier(
      id: 'crr-$phone',
      name: names[digitSum % names.length],
      phone: phone,
      branchName: 'Parahat',
      onShift: true,
    );
  }

  static const ShiftSummary summary = ShiftSummary(
    deliveredCount: 12,
    cashOnHand: 1840,
    handedOver: 0,
  );

  static List<DeliveryOrder> orders() => [
    DeliveryOrder(
      id: 'ord-1042',
      number: 1042,
      status: OrderStatus.pickedUp,
      address: DeliveryAddress(
        district: 'Parahat 7',
        house: '12',
        entrance: '3',
        floor: '5',
        point: LatLng(37.9302, 58.4118),
      ),
      customerName: 'Айна С.',
      customerPhone: '+99365404040',
      total: 139,
      changeFrom: 200,
      items: const [
        OrderItem(name: 'Плов по-ашхабадски', quantity: 2, price: 45),
        OrderItem(name: 'Салат «Мерджен»', quantity: 1, price: 24),
        OrderItem(name: 'Айран', quantity: 5, price: 5),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      distanceKm: 2.4,
    ),
    DeliveryOrder(
      id: 'ord-1043',
      number: 1043,
      status: OrderStatus.assigned,
      address: DeliveryAddress(
        district: 'Berkararlyk',
        house: '44',
        entrance: '1',
        floor: '2',
        note: 'Домофон не работает, позвоните',
        point: LatLng(37.9188, 58.4215),
      ),
      customerName: 'Мерет Б.',
      customerPhone: '+99365717171',
      total: 86,
      items: const [
        OrderItem(name: 'Шашлык из баранины', quantity: 1, price: 62),
        OrderItem(name: 'Чурек', quantity: 2, price: 12),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(minutes: 9)),
      distanceKm: 3.1,
    ),
    DeliveryOrder(
      id: 'ord-1044',
      number: 1044,
      status: OrderStatus.assigned,
      address: DeliveryAddress(
        district: 'Mir 2/1',
        house: '7',
        entrance: '2',
        floor: '9',
        point: LatLng(37.9445, 58.3572),
      ),
      customerName: 'Гүлнара О.',
      customerPhone: '+99362828282',
      total: 212,
      changeFrom: 500,
      items: const [
        OrderItem(name: 'Дограма', quantity: 3, price: 38),
        OrderItem(name: 'Манты', quantity: 2, price: 40),
        OrderItem(name: 'Чай зелёный', quantity: 2, price: 9),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(minutes: 4)),
      distanceKm: 4.8,
    ),

    // Finished earlier today — shown under "Недавние" on the history page.
    DeliveryOrder(
      id: 'ord-1039',
      number: 1039,
      status: OrderStatus.delivered,
      address: DeliveryAddress(
        district: 'Parahat 3',
        house: '9',
        entrance: '2',
        floor: '4',
        point: LatLng(37.9241, 58.3987),
      ),
      customerName: 'Ораз Д.',
      customerPhone: '+99361212121',
      total: 154,
      items: const [
        OrderItem(name: 'Лагман', quantity: 2, price: 40),
        OrderItem(name: 'Самса', quantity: 3, price: 15),
        OrderItem(name: 'Компот', quantity: 3, price: 8),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      completedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
    ),
    DeliveryOrder(
      id: 'ord-1036',
      number: 1036,
      status: OrderStatus.delivered,
      address: DeliveryAddress(
        district: 'Berkararlyk',
        house: '21',
        entrance: '4',
        floor: '1',
        point: LatLng(37.9151, 58.4172),
      ),
      customerName: 'Сона К.',
      customerPhone: '+99364545454',
      total: 97,
      changeFrom: 100,
      items: const [
        OrderItem(name: 'Плов по-ашхабадски', quantity: 1, price: 45),
        OrderItem(name: 'Салат «Мерджен»', quantity: 2, price: 24),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 20)),
      completedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 45)),
    ),

    // 3–5 days old — shown under "Архив".
    DeliveryOrder(
      id: 'ord-0984',
      number: 984,
      status: OrderStatus.delivered,
      address: DeliveryAddress(
        district: 'Mir 2/1',
        house: '3',
        entrance: '1',
        floor: '6',
        point: LatLng(37.9438, 58.3541),
      ),
      customerName: 'Байрам Ч.',
      customerPhone: '+99366363636',
      total: 118,
      items: const [
        OrderItem(name: 'Манты', quantity: 3, price: 40 / 3),
        OrderItem(name: 'Чай зелёный', quantity: 2, price: 9),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
      completedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    DeliveryOrder(
      id: 'ord-0951',
      number: 951,
      status: OrderStatus.delivered,
      address: DeliveryAddress(
        district: 'Parahat 7',
        house: '30',
        entrance: '2',
        floor: '3',
        point: LatLng(37.9318, 58.4066),
      ),
      customerName: 'Джерен Н.',
      customerPhone: '+99367474747',
      total: 203,
      changeFrom: 300,
      items: const [
        OrderItem(name: 'Шашлык из баранины', quantity: 2, price: 62),
        OrderItem(name: 'Чурек', quantity: 3, price: 12),
      ],
      branchName: 'Parahat',
      assignedAt: DateTime.now().subtract(const Duration(days: 5, hours: 2)),
      completedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
}
