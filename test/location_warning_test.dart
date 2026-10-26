import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:kurier_app/core/localization/locale_provider.dart';
import 'package:kurier_app/core/services/location_service.dart';
import 'package:kurier_app/core/widgets/location_warning.dart';

class DisplayLocation extends ChangeNotifier implements LocationService {
  @override
  bool active = true;
  @override
  bool isStale = false;
  @override
  LatLng? current;
  @override
  Duration? currentAge;
  @override
  double? accuracy;
  @override
  String? error;
  @override
  bool get backgroundGranted => true;
  @override
  bool batteryUnrestricted = true;
  @override
  Future<void> retry() async {}
  void update() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final language in ['ru', 'tk']) {
    testWidgets('$language shows waiting/stale diagnostics at narrow width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'app_language': language});
      final prefs = await SharedPreferences.getInstance();
      final locale = LocaleProvider(prefs);
      final location = DisplayLocation();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocationService>.value(value: location),
            ChangeNotifierProvider.value(value: locale),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: LocationWarning()),
            ),
          ),
        ),
      );
      expect(find.text(locale.strings.locationWaiting), findsOneWidget);
      expect(find.text(locale.strings.locationDenied), findsNothing);
      location.current = const LatLng(37.96, 58.32);
      location.currentAge = Duration.zero;
      location.accuracy = 12;
      location.update();
      await tester.pump();
      expect(find.text(locale.strings.locationWaiting), findsNothing);
      location.isStale = true;
      location.currentAge = const Duration(seconds: 75);
      location.update();
      await tester.pump();
      expect(
        find.text(locale.strings.locationAge(const Duration(seconds: 75))),
        findsOneWidget,
      );
      expect(find.text(locale.strings.locationAccuracy(12)), findsOneWidget);
      expect(tester.takeException(), null);
      location.active = false;
      location.update();
      await tester.pump();
      expect(find.text(locale.strings.locationWaiting), findsNothing);
      await tester.pumpWidget(const SizedBox());
      location.dispose();
      locale.dispose();
    });
  }
}
