import 'dart:async';

import 'package:location/location.dart' as loc;

class FakeLocation implements loc.Location {
  final updates = StreamController<loc.LocationData>.broadcast(sync: true);
  Completer<loc.LocationData> reading = Completer<loc.LocationData>();
  Future<bool>? enabledResult;
  loc.PermissionStatus permission = loc.PermissionStatus.granted;
  final settings = <loc.LocationAccuracy?>[];
  final distances = <double?>[];
  final background = <bool?>[];
  final notifications = <Map<String, String?>>[];
  int reads = 0;

  @override
  Future<bool> serviceEnabled() async => await enabledResult ?? true;
  @override
  Future<bool> requestService() async => false;
  @override
  Future<loc.PermissionStatus> hasPermission() async => permission;
  @override
  Future<loc.PermissionStatus> requestPermission() async => permission;
  @override
  Future<bool> changeSettings({
    loc.LocationAccuracy? accuracy = loc.LocationAccuracy.high,
    int? interval = 1000,
    double? distanceFilter = 0,
    bool? pausesLocationUpdatesAutomatically = true,
  }) async {
    settings.add(accuracy);
    distances.add(distanceFilter);
    return true;
  }

  @override
  Stream<loc.LocationData> get onLocationChanged => updates.stream;
  @override
  Future<loc.LocationData> getLocation() {
    reads++;
    return reading.future;
  }

  @override
  Future<bool> enableBackgroundMode({bool? enable = true}) async {
    background.add(enable);
    return true;
  }

  // `changeNotificationOptions` returns a platform-interface type the
  // `location` package does not re-export, so it is recorded here rather than
  // overridden — `Future<Null>` satisfies the declared return type without
  // this file depending on a transitive package.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #changeNotificationOptions) {
      final named = invocation.namedArguments;
      notifications.add({
        'channelName': named[#channelName] as String?,
        'title': named[#title] as String?,
        'subtitle': named[#subtitle] as String?,
      });
      return Future<Null>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

loc.LocationData measurement(
  DateTime at, {
  double lat = 37.96,
  double lng = 58.32,
  double accuracy = 12,
  double speed = 0,
  double heading = 90,
}) => loc.LocationData.fromMap({
  'latitude': lat,
  'longitude': lng,
  'time': at.millisecondsSinceEpoch.toDouble(),
  'accuracy': accuracy,
  'speed': speed,
  'heading': heading,
});
