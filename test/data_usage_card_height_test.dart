import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:a7_tagam_kurier/core/localization/app_strings.dart';
import 'package:a7_tagam_kurier/core/localization/locale_provider.dart';
import 'package:a7_tagam_kurier/core/services/data_usage_service.dart';
import 'package:a7_tagam_kurier/modules/profile/data_usage_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Iki olcum karti bir `ListView` icindeki `Row`da yan yana duruyor: dikey
/// alani sinirlayan bir sey olmadigi icin her kart kendi metni kadar
/// yukseliyor. Mobil veri etiketi her iki dilde de iki satira kayarken
/// "Wi-Fi" hic kaymiyor — satir `IntrinsicHeight` ile sarilana kadar bir kart
/// gozle gorulur bicimde digerinden uzundu.
void main() {
  const strings = StringsRu();

  Size cardSize(WidgetTester tester, String label) {
    final card = find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first;
    return tester.getSize(card);
  }

  testWidgets('mobil ve Wi-Fi kartlari ayni yukseklikte', (tester) async {
    // Varsayilan test penceresi 800 piksel genis; orada mobil veri etiketi
    // tek satira sigiyor ve hata hic ortaya cikmiyor. Gercek bir telefon
    // genisligi sarmayi zorluyor.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ChangeNotifierProvider(create: (_) => DataUsageService(prefs)),
        ],
        child: const MaterialApp(home: DataUsageScreen()),
      ),
    );
    await tester.pump();

    final mobile = cardSize(tester, strings.mobileData);
    final wifi = cardSize(tester, strings.wifiData);

    expect(
      mobile.height,
      wifi.height,
      reason:
          'kartlar hizali olmali: mobil=${mobile.height} wifi=${wifi.height}',
    );
  });
}
