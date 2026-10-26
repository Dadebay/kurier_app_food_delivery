/// Central place for every server address and tuning constant.
///
/// Everything here is deliberately in one file: when the system is installed
/// on the customer's own server (Phase 1 · MVP) only this file changes.
class AppConfig {
  const AppConfig._();

  // ─── Backend ─────────────────────────────────────────────────
  /// Use --dart-define=API_BASE_URL=http://192.168.x.x:4000/api/v1/ to test
  /// against a local backend instead of the live API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://a7-tagam.com.tm/api/v1/',
  );

  /// While no backend is reachable the app runs on the built-in demo data set
  /// (`core/data/mock/mock_data.dart`) so the whole flow can be shown and
  /// tested. Set to `false` once the server is up.
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  // ─── Map ─────────────────────────────────────────────────────
  /// Our own tile server — same infrastructure as the Ayterek map service.
  /// No usage fee and no dependency on a foreign map provider.
  static const String mapTileUrl =
      'https://a7-tagam.com.tm/tile/{z}/{x}/{y}.png';

  /// Test tile server, kept for staging builds.
  static const String mapTileUrlTest =
      'https://a7-tagam.com.tm/tile/{z}/{x}/{y}.png';

  static const String mapUserAgent = 'tm.com.naharym.kurier';

  /// Ashgabat — map opens here before the first GPS fix arrives.
  static const double defaultLat = 37.9601;
  static const double defaultLng = 58.3261;
  static const double defaultZoom = 13.0;
  static const double followZoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;

  /// Tiles stay on the phone for a month — a courier driving the same
  /// districts every day almost never re-downloads them.
  static const Duration tileCacheMaxStale = Duration(days: 30);

  /// How long a cached GET response (assigned orders, branch, ...) stays
  /// eligible to answer a request once the network call itself fails — see
  /// `ApiClient`. A courier losing signal mid-shift still needs to see the
  /// route they already loaded, so this is generous rather than tuned tight.
  static const Duration apiCacheMaxStale = Duration(days: 7);

  // ─── Live tracking ───────────────────────────────────────────
  /// Fresh stationary measurements also keep the server marker online.
  static const Duration trackingInterval = Duration(seconds: 15);

  static const Duration queueFlushInterval = Duration(seconds: 30);

  // ─── Misc ────────────────────────────────────────────────────
  static const String currency = 'TMT';
  static const String supportPhone = '+99312000000';
}
