import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push for the courier app: asks for permission, keeps the registration
/// token fresh, and surfaces the token in the console while running in debug
/// so it can be pasted straight into Firebase's test sender.
///
/// The one message that matters here is an order being assigned: the courier
/// is not watching the admin panel, so the push is how they find out.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final instance = FirebaseMessagingService._();

  /// Declared in `AndroidManifest.xml` as the default channel too, so a push
  /// that arrives while the app is in the background lands on this same
  /// high-importance channel instead of Android's silent fallback one.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kurier_orders',
    'Заказы',
    description: 'Новые заказы и изменения по доставке.',
    // A courier with the phone in their pocket has to be interrupted —
    // anything below `high` means no heads-up banner and no sound.
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android drops a notification whose id repeats, so each message gets its
  /// own. The counter is enough — nothing here needs to update a shown one.
  int _notificationId = 0;

  /// [onTokenRefresh] re-sends the token to our backend whenever FCM rotates
  /// it — a token registered once and never updated is exactly how a device
  /// silently stops receiving pushes.
  Future<void> initialize({VoidCallback? onTokenRefresh}) async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initializeLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _banner(
      'NOTIFICATION PERMISSION',
      settings.authorizationStatus.name,
      '36',
    );

    // iOS only — on Android this call does nothing at all, which is why a
    // foreground push used to vanish there. See `_showLocalNotification`.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _banner('FCM TOKEN REFRESHED', token, '32');
      onTokenRefresh?.call();
    });

    await _printToken();
  }

  Future<void> _printToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      _banner('FCM TOKEN', token ?? 'not available yet', token == null ? '33' : '32');
    } catch (error, stackTrace) {
      developer.log(
        'Unable to obtain FCM token',
        name: 'Kurier FCM',
        error: error,
        stackTrace: stackTrace,
      );
      _banner('FCM TOKEN', 'unavailable: $error', '31');
    }
  }

  /// Registers the channel the notifications are posted on.
  ///
  /// Android refuses to show anything on a channel that does not exist yet, and
  /// a channel's importance is fixed the moment it is created — changing
  /// [_channel] later only takes effect after the app is reinstalled.
  /// Failures here are swallowed on purpose: this runs from `main()` before
  /// `runApp`, and a courier who cannot start the app at all is worse off than
  /// one whose notifications are silent. The usual cause is a stale install —
  /// a hot restart after the plugin was added leaves the Dart side calling a
  /// native channel the running APK does not contain
  /// (`MissingPluginException`), which a full reinstall fixes.
  Future<void> _initializeLocalNotifications() async {
    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          // The launcher icon rather than a dedicated silhouette: on Android 5+
          // the status bar draws it as a white mask, and a wrong or missing
          // drawable here means the notification is dropped silently.
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    } catch (error, stackTrace) {
      developer.log(
        'Local notifications unavailable — foreground pushes will not be shown',
        name: 'Kurier FCM',
        error: error,
        stackTrace: stackTrace,
      );
      _banner('LOCAL NOTIFICATIONS', 'unavailable: $error', '31');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logForegroundMessage(message);
    await _showLocalNotification(message);
  }

  /// Posts the message to the system tray ourselves.
  ///
  /// Android hands a push that arrives while the app is in the foreground
  /// straight to `onMessage` and shows nothing — there is no system banner to
  /// suppress or enable, the tray entry simply never exists unless the app
  /// creates it. iOS does show its own banner (see
  /// `setForegroundNotificationPresentationOptions` above), so posting here as
  /// well would show the courier the same order twice.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notification = message.notification;
    // A data-only push carries no `notification` block; the backend puts the
    // same text in `data` so those are worth showing rather than dropping.
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    try {
      await _localNotifications.show(
        id: _notificationId++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      // This runs inside the `onMessage` stream listener, where an uncaught
      // error would surface as an unhandled async exception rather than
      // anything the courier can act on.
      developer.log(
        'Could not show notification for ${message.messageId}',
        name: 'Kurier FCM',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _logForegroundMessage(RemoteMessage message) {
    if (!kDebugMode) return;
    final notification = message.notification;
    const cyan = '\x1B[1;36m';
    const yellow = '\x1B[1;33m';
    const reset = '\x1B[0m';
    debugPrint('$cyan╔════════ FCM FOREGROUND RECEIVED ════════╗$reset');
    debugPrint('$cyan║$reset TITLE: $yellow${notification?.title}$reset');
    debugPrint('$cyan║$reset BODY: ${notification?.body}');
    debugPrint('$cyan║$reset DATA: ${message.data}');
    debugPrint('$cyan╚═════════════════════════════════════════╝$reset');
  }

  void _banner(String label, String value, String ansiColor) {
    if (!kDebugMode) return;
    developer.log('$label: $value', name: 'Kurier FCM');
    // ANSI escapes are rendered in colour by terminals used with `flutter run`.
    // ignore: avoid_print
    print('\x1B[1;${ansiColor}m╔══ KURIER $label ══╗\x1B[0m');
    // ignore: avoid_print
    print('\x1B[${ansiColor}m$value\x1B[0m');
    // ignore: avoid_print
    print('\x1B[1;${ansiColor}m╚════════════════════════════════╝\x1B[0m');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  developer.log('Background message: ${message.messageId}', name: 'Kurier FCM');
}
