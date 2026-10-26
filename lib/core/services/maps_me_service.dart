import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a stop over to MAPS.ME for turn-by-turn navigation.
///
/// The courier app draws the route itself, but only as a line on a static
/// map: no voice, no lane guidance, no re-routing when a turn is missed.
/// MAPS.ME has all of that and works from offline maps, which matters on a
/// round where the connection comes and goes.
class MapsMeService {
  const MapsMeService._();

  static const package = 'com.mapswithme.maps.pro';

  /// Play Store page, opened when MAPS.ME is not installed.
  static const storeUrl =
      'https://play.google.com/store/apps/details?id=$package';

  static const _channel = MethodChannel('a7_tagam_kurier/navigation');

  /// Opens MAPS.ME on [destination].
  ///
  /// A plain `geo:` link, not the `mapsme://` scheme the old API documents:
  /// current MAPS.ME builds no longer register that scheme at all — verified
  /// against the installed app, which claims only `geo`, `ge0`, `http` and
  /// `https`. `geo:` is also what every other map on the phone answers, so
  /// the intent names the package explicitly rather than putting a chooser
  /// in front of a courier who already pressed a button that says MAPS.ME.
  ///
  /// The link carries the destination only. MAPS.ME has the courier's own
  /// position from its GPS and offers "Route to" on the pin it opens, which
  /// is the routing step — a `geo:` link has no way to express a start point.
  ///
  /// Returns false when MAPS.ME could not be opened, which is the caller's
  /// cue to offer the store page instead of leaving a dead button.
  static Future<bool> navigate({
    required LatLng destination,
    required String destinationName,
  }) async {
    final point =
        '${destination.latitude.toStringAsFixed(6)},'
        '${destination.longitude.toStringAsFixed(6)}';
    // The label is advisory: MAPS.ME names the pin from its own map data and
    // ignores it. It is still sent because it costs nothing and any other
    // map the link is ever pointed at does show it.
    final uri = 'geo:$point?q=$point(${Uri.encodeComponent(destinationName)})';
    try {
      final opened = await _channel.invokeMethod<bool>('openInPackage', {
        'uri': uri,
        'package': package,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the store page so the courier can install MAPS.ME.
  static Future<void> openStore() =>
      launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
}
