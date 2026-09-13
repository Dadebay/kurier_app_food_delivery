import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/auth_repository.dart';
import 'core/data/courier_repository.dart';
import 'core/localization/locale_provider.dart';
import 'core/network/api_client.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/data_usage_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/location_service.dart';
import 'core/services/network_locator_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/services/push_device_registration_service.dart';
import 'core/services/tile_cache_service.dart';
import 'core/services/tracking_service.dart';
import 'modules/auth/auth_provider.dart';
import 'modules/shift/shift_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  await Hive.initFlutter();
  await TileCacheService.init();
  final prefs = await SharedPreferences.getInstance();
  final dataUsage = DataUsageService(prefs);
  await dataUsage.start();

  // Wiring is done here rather than in a service locator: the graph is small
  // and being able to read it top to bottom is worth more than the indirection.
  final api = ApiClient();
  final connectivity = ConnectivityService();
  final queue = OfflineQueueService(api: api, connectivity: connectivity);
  await queue.init();

  final location = LocationService(prefs: prefs);
  // Last link of the positioning chain: satellites, then Android's own
  // Wi-Fi/cell provider, then our server's network lookup.
  final networkLocator = NetworkLocatorService(api: api);
  location.networkFallback = networkLocator.locate;
  final tracking = TrackingService(location: location, queue: queue, api: api);
  final authRepository = AuthRepository(api: api, prefs: prefs);
  api.onUnauthorized = authRepository.refreshSession;

  // After `pushDevices` exists, so a rotated token can be re-sent to the
  // backend the moment FCM issues one — see FirebaseMessagingService.
  final pushDevices = PushDeviceRegistrationService(api: api);
  await FirebaseMessagingService.instance.initialize(
    onTokenRefresh: pushDevices.register,
  );
  final courierRepository = CourierRepository(
    api: api,
    queue: queue,
    signedInPhone: () => authRepository.signedInPhone,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: connectivity),
        ChangeNotifierProvider.value(value: dataUsage),
        ChangeNotifierProvider.value(value: queue),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider.value(value: tracking),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(authRepository, onSignedIn: pushDevices.register),
        ),
        ChangeNotifierProvider(
          create: (_) => ShiftProvider(
            repository: courierRepository,
            location: location,
            tracking: tracking,
          ),
        ),
      ],
      child: const KurierApp(),
    ),
  );
}
