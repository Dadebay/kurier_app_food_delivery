import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// Hands this device's FCM registration token to our backend, so an order
/// assigned to this courier can reach them.
///
/// The API stores the token under the signed-in user, which is why this has
/// to run *after* sign-in: sent earlier the request is simply rejected, and
/// the courier would sit there never being told about their orders. The
/// field is named `installationId` for historical reasons but holds the
/// registration token — the same convention the customer app uses.
class PushDeviceRegistrationService {
  PushDeviceRegistrationService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<void> register() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        developer.log(
          'No FCM token available yet; skipping push registration.',
          name: 'Kurier Push',
        );
        return;
      }
      final response = await _api.put(
        ApiPaths.pushDevices,
        data: {
          'installationId': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
      );
      if (response.statusCode == null || response.statusCode! >= 300) {
        throw StateError('API returned ${response.statusCode}');
      }
      developer.log('Push device registered', name: 'Kurier Push');
    } catch (error) {
      // Never fatal: a courier who cannot register for push must still be
      // able to work the shift.
      developer.log(
        'Push device registration failed; the app remains usable.',
        name: 'Kurier Push',
        error: error.runtimeType,
      );
    }
  }
}
