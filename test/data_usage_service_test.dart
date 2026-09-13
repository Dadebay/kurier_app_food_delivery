import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurier_app/core/services/data_usage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formats the traffic units couriers see in the profile', () {
    expect(DataUsageService.formatBytes(999), '999 B');
    expect(DataUsageService.formatBytes(1024), '1.0 KB');
    expect(
      DataUsageService.formatBytes(3 * DataUsageService.bytesPerMegabyte),
      '3.00 MB',
    );
  });

  test('starts a fresh application-only counter on a new local day', () async {
    SharedPreferences.setMockInitialValues({
      'data_usage_day': '2026-09-11',
      'data_usage_mobile_bytes': 5000,
      'data_usage_wifi_bytes': 7000,
      'data_usage_last_rx': 100000,
      'data_usage_last_tx': 50000,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = DataUsageService(
      prefs,
      now: () => DateTime(2026, 9, 12, 8),
    );

    await service.start();

    expect(service.totalBytes, 0);
    expect(prefs.getInt('data_usage_last_rx'), 100000);
    expect(prefs.getInt('data_usage_last_tx'), 50000);
    service.dispose();
  });

  test('keeps the finished day rather than discarding it', () async {
    SharedPreferences.setMockInitialValues({
      'data_usage_day': '2026-09-11',
      'data_usage_mobile_bytes': 5000,
      'data_usage_wifi_bytes': 7000,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = DataUsageService(
      prefs,
      now: () => DateTime(2026, 9, 12, 8),
    );

    await service.start();

    expect(service.totalBytes, 0, reason: 'today starts clean');
    final yesterday = service.yesterday;
    expect(yesterday?.date, '2026-09-11');
    expect(yesterday?.mobileBytes, 5000);
    expect(yesterday?.wifiBytes, 7000);
    expect(service.monthBytes, 12000, reason: 'the month still counts it');
    service.dispose();
  });

  test('drops days older than the retained month', () async {
    SharedPreferences.setMockInitialValues({
      'data_usage_day': '2026-09-11',
      'data_usage_mobile_bytes': 1000,
      'data_usage_wifi_bytes': 0,
      // One inside the window, one well past it.
      'data_usage_history':
          '{"2026-08-20":[400,0],"2026-07-01":[999999,0]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = DataUsageService(
      prefs,
      now: () => DateTime(2026, 9, 12, 8),
    );

    await service.start();

    final dates = service.history.map((day) => day.date).toList();
    expect(dates, contains('2026-09-11'));
    expect(dates, contains('2026-08-20'));
    expect(dates, isNot(contains('2026-07-01')));
    expect(service.monthBytes, 1400);
    service.dispose();
  });

  test('reset clears the stored month too', () async {
    SharedPreferences.setMockInitialValues({
      'data_usage_day': '2026-09-12',
      'data_usage_mobile_bytes': 800,
      'data_usage_wifi_bytes': 200,
      'data_usage_history': '{"2026-09-11":[5000,7000]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = DataUsageService(
      prefs,
      now: () => DateTime(2026, 9, 12, 9),
    );

    await service.reset();

    expect(service.totalBytes, 0);
    expect(service.monthBytes, 0);
    expect(service.yesterday, isNull);
    service.dispose();
  });
}
