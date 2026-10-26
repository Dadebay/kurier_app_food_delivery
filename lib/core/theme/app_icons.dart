import 'package:hugeicons/hugeicons.dart';

/// HugeIcons ships its glyphs as raw path data rather than an icon font, so
/// this is the type every icon parameter in the app is declared with.
typedef HugeIconData = List<List<dynamic>>;

/// One name per icon, so a change of icon set is a change to this file.
class AppIcons {
  const AppIcons._();

  static const HugeIconData back = HugeIcons.strokeRoundedArrowLeft01;
  static const HugeIconData user = HugeIcons.strokeRoundedUser;
  static const HugeIconData route = HugeIcons.strokeRoundedRoute01;
  static const HugeIconData package = HugeIcons.strokeRoundedPackage;
  static const HugeIconData myLocation = HugeIcons.strokeRoundedLocationUser03;
  static const HugeIconData call = HugeIcons.strokeRoundedCall;
  static const HugeIconData courier = HugeIcons.strokeRoundedDeliveryTruck01;
  static const HugeIconData upload = HugeIcons.strokeRoundedCloudUpload;
  static const HugeIconData dataUsage = HugeIcons.strokeRoundedDatabase01;
  static const HugeIconData internet = HugeIcons.strokeRoundedInternet;
  static const HugeIconData map = HugeIcons.strokeRoundedMapsGlobal01;
  static const HugeIconData signOut = HugeIcons.strokeRoundedLogout01;
  static const HugeIconData offShift = HugeIcons.strokeRoundedMoon02;
  static const HugeIconData history = HugeIcons.strokeRoundedClock01;
  static const HugeIconData checkSuccess = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const HugeIconData home = HugeIcons.strokeRoundedHome01;
  static const HugeIconData battery = HugeIcons.strokeRoundedBatteryCharging01;
}
