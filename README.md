# A7-TAGAM Kurier

Android courier app for the [A7-TAGAM delivery system](https://a7-tagam.com.tm/). Couriers can view assigned orders, follow a route, report their position, update delivery status, and review cash due. The app supports Turkmen and Russian.

Older project drafts call this app **Naharym Courier**; the current product name is **A7-TAGAM Kurier**.

**Status:** Android testing pre-release [v1.0.0](https://github.com/Dadebay/A7-TAGAM-kurier/releases/tag/v1.0.0). There is no verified Google Play listing. The repository contains an Android target; an iOS target has not been added. Physical-device installation and live backend flows have not yet been verified.

## Latest Android APK

- [Download the signed v1.0.0 APK](https://github.com/Dadebay/A7-TAGAM-kurier/releases/download/v1.0.0/A7-TAGAM-Kurier-v1.0.0.apk) for Android 7.0 or newer.
- [Download its SHA-256 checksum](https://github.com/Dadebay/A7-TAGAM-kurier/releases/download/v1.0.0/A7-TAGAM-Kurier-v1.0.0.apk.sha256).

The APK contains version `1.0.0+1` of `com.gurbanov.kurier` and was built from commit `ff9755cb16634461a9d379d6b10086e6551f5b06`. Its SHA-256 is `c80477acc4e38549344563f561372e657e127934bc375783a60fcd3064296990`. This direct-install APK uses a project-specific release certificate; it is not a Google Play package. Read the [release notes](https://github.com/Dadebay/A7-TAGAM-kurier/releases/tag/v1.0.0) before using it for live deliveries.

## What is implemented

- OTP sign-in against the configured backend, with an explicit mock mode for local demos.
- Assigned orders, route display, customer calling, cash confirmation, and shift figures.
- An offline outbox for status changes and location pings, plus cached GET responses and map tiles.
- Firebase Cloud Messaging for order notifications and Android app data-usage figures.

These are code capabilities, not evidence that the production backend, background tracking, or push delivery has passed a device test. See [release readiness](docs/release-readiness.md) for verified checks and remaining work.

## Requirements and setup

- Flutter 3.47.8 with Dart 3.13.7 (the version used for the current checks)
- Android SDK and JDK 17
- Android device or emulator for running the app

```sh
flutter pub get --enforce-lockfile
flutter run --dart-define=USE_MOCK_DATA=true
```

Mock mode accepts any phone number with code `000000`. It contains demonstration orders and does not contact the courier API. For the real backend, omit `USE_MOCK_DATA` and provide the correct environment URL when needed:

```sh
flutter run --dart-define=API_BASE_URL=https://a7-tagam.com.tm/api/v1/
```

`lib/core/constants/app_config.dart` contains the API base URL, tile URL, tracking interval, and cache settings. `lib/core/network/api_client.dart` lists backend paths. The real sign-in and delivery flows need a working courier account and a compatible backend; they have not been verified end to end in this repository.

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
```

The GitHub Actions workflow runs these checks on pull requests and pushes. A release build without `android/key.properties` is **unsigned** and is only a build check.

## Signing and distribution

The Android application ID is `com.gurbanov.kurier` and the current version is `1.0.0+1`. Keep both stable for any future Play listing. Release signing requires a project-specific keystore held outside Git and a local, ignored `android/key.properties` based on [`android/key.properties.example`](android/key.properties.example). `storeFile` may be an absolute path to secure storage. The Gradle configuration will not sign a release with the debug key.

The v1.0.0 APK's package ID, version, signing certificate, and checksum were verified. Installation and upgrade behavior still need testing on a real Android device. A Play-signed installation can be upgraded only with the appropriate Play app signing certificate.

## Known limits

- The shift toggle changes local tracking state, but `CourierRepository.setShift` has no backend implementation. Its server contract must be confirmed before relying on the toggle for dispatch.
- Auth tokens are currently stored in SharedPreferences. Move them to platform-protected storage before a public release.
- Background location, Wi-Fi scanning, notification permissions, privacy declarations, and backend integration need device and store-policy verification.
- There is no iOS project in this repository, so iOS build, TestFlight, and App Store checks are not applicable.

## Structure

- `lib/core`: API, models, offline queue, tracking, localization, and theme
- `lib/modules`: authentication, order list, route, history, shift, and profile screens
- `assets`: fonts, loader animation, and map marker
- `test`: cache, data usage, and release-safety regression tests

The official project and app name is **A7-TAGAM Kurier**. The Android package ID remains `com.gurbanov.kurier` so existing installs and Firebase configuration keep their identity.
