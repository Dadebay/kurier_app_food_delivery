# A7-TAGAM Kurier release readiness

Checked on 8 November 2026 against the Flutter project cloned from `Dadebay/kurier_app_food_delivery`. Starting `main` was clean at `7a4daea`; work was done on `codex/release-readiness`.

## 1. Starting state and baseline

- **Done:** Android-only Flutter project, package ID `com.gurbanov.kurier`, version `1.0.0+1`. Flutter 3.47.8, Dart 3.13.7, Android Gradle Plugin 8.11.1, Gradle 8.14.0.
- **Done:** Baseline tests passed. Baseline analysis failed because `pubspec.yaml` named a nonexistent `assets/images/` directory. The first release build attempt could not download Gradle (GitHub HTTP 504), and local Flutter selected Java 25, which is incompatible with this wrapper.
- **Done:** Removed the nonexistent asset reference. Analysis and tests pass; Android release builds with cached Gradle 8.14 and JDK 17. CI selects JDK 17 explicitly and builds unsigned because it has no signing key.
- **N/A:** iOS, TestFlight, and App Store Connect. This repository has no iOS project.

## 2. Critical behavior and data safety

- **Done:** A temporary HTTP 401, 408, 426, or 429 no longer deletes a queued delivery write. A refresh rate limit no longer discards a saved session. Sign-out clears the local session even when the logout request fails offline. Unknown backend order statuses and missing order IDs are rejected rather than shown as an assigned order or sent to a fabricated URL. Regression tests cover these cases.
- **Pending:** Real OTP, session restoration, order transitions, cash hand-over, push, background tracking, and offline resync need a courier test account, backend contract, and Android device tests. Do not infer server success from the app's optimistic UI update.
- **Pending:** `CourierRepository.setShift` is empty. The shift toggle currently changes local tracking but is not persisted to the dispatch backend. Define and test the server endpoint before a store release.
- **Pending:** Queued writes are stored globally on the device. A future change should bind them to the courier session and define what happens to unsent writes during account switching. Verify this before shared-device use.
- **N/A:** In-app payments and marketing opt-out. No such flow exists in this courier app.

## 3. Code and dependency cleanup

- **Done:** Removed an unused `cupertino_icons` dependency, a nonexistent asset directory, unused configuration fields, and obsolete Naharym references. `flutter_map_cache` remains because `TileCacheService` uses it.
- **Pending:** `dio_cache_interceptor_hive_store` is discontinued but still used for offline cache storage. Its replacement is a separate migration requiring cache compatibility tests.
- **Pending:** Flutter reports that support for the current Gradle, Android Gradle Plugin, and Kotlin plugin versions will soon be dropped. Plan their coordinated upgrade with an Android build and device regression pass.
- **Pending:** Route, location, localization, profile, and login files exceed 300 lines. Responsibility-based extraction is deferred until behavior is covered by device/backend tests; no arbitrary line-count rewrite was made.

## 4. Quality, accessibility, and performance

- **Done:** System text scaling is no longer forcibly disabled. Formatting, static analysis, unit tests, and the Android release build pass locally.
- **Pending:** Check large text, small screens, dark mode, TalkBack, keyboard, permission prompts, and offline/error states on supported devices. No startup, memory, rebuild, image, or bundle-size improvement is claimed without measurements. The signed release APK is about 59 MiB.

## 5. Security and platform configuration

- **Done:** Android releases no longer use the debug signing key. `android/key.properties`, keystores, and local environment files are ignored. A new project-specific release key is held outside Git in `/Users/dadebay/Developer/apps/Project Keys/A7-TAGAM Kurier/`. The local `android/key.properties` points to that secure copy. The signed APK verifies with the v2 signature scheme; certificate SHA-256 is `57d583c2772566438446c423915132ed691644fa00ea50d182e33d7114fed98b`. Back up this key securely: future direct APK upgrades must use the same key. OTP codes, push tokens, order identifiers, and precise coordinates were removed from application diagnostics.
- **Pending:** Access and refresh tokens remain in SharedPreferences. Move them to platform-protected storage with a tested migration before public release. Review Android background-location and Wi-Fi scan use against actual product need and Play declarations. Confirm Firebase, backend, and tile-server configuration with the service owner.
- **N/A:** App Links / Universal Links. Neither is configured in this repository.

## 6. GitHub and CI gate

- **Done:** The branch contains small Conventional Commits and a GitHub Actions workflow for locked dependencies, formatting, analysis, tests, and an unsigned Android release build.
- **Done:** GitHub About contains an English description, the verified project website, and relevant topics. The repository has been renamed to `Dadebay/a7-tagam-kurier`.
- **Pending:** Verify the remote PR checks and review comments. The first two CI attempts passed format, analysis, and tests but could not download Gradle/Kotlin artifacts because GitHub returned HTTP 504; retry after the upstream download recovers.

## 7. Release and rollback

- **Done:** No earlier tag or GitHub Release exists. A first signed `1.0.0+1` APK was built locally and verified for package `com.gurbanov.kurier`, version code 1, version name 1.0.0, and its signing certificate. No Google Play listing for this package was verified.
- **Pending:** Build again from the exact merged/tagged commit, calculate SHA-256, attach the APK and checksum to a GitHub pre-release, and verify the public download. No Android device is currently connected, so physical-device installation, real OTP/backend flows, and upgrades from older installs remain untested. Confirm backend compatibility and prepare staged rollout and rollback notes before production use. Keep signing credentials outside Git.

## 8. Backend and operations handover

- **Known service map:** The Android app uses `https://a7-tagam.com.tm/api/v1/` by default for OTP, orders, route, tracking, and notification-device registration. It requests map tiles from `https://a7-tagam.com.tm/tile/{z}/{x}/{y}.png`. Firebase configuration is in `android/app/google-services.json`; it is client configuration, not a server credential.
- **Pending with the backend owner:** Verify endpoint schemas, shift persistence, health checks, deployment and rollback, backups/restores, service ownership, push key ownership, monitoring, and credential rotation. Do not put secret values in this repository.

## 9. Final gate

Merge the reviewed PR after CI passes. A direct APK pre-release can then be published from the exact merged commit with its checksum and clear testing limitations. Production use remains blocked by backend, privacy, and physical-device verification. Update this document with the release commit, tag, asset link, and device evidence when those exist.
