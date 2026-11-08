import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/auth_provider.dart';
import 'modules/auth/login_screen.dart';
import 'modules/orders/orders_screen.dart';

class KurierApp extends StatelessWidget {
  const KurierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'A7-TAGAM Kurier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale.locale,
      supportedLocales: const [Locale('ru'), Locale('tk'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Turkmen has no Material translations upstream; fall back to Russian
      // for the framework's own strings rather than English.
      localeResolutionCallback: (deviceLocale, supported) =>
          locale.locale.languageCode == 'tk'
          ? const Locale('ru')
          : locale.locale,
      home: const _Root(),
    );
  }
}

/// Decides between the login screen and the shift, and rebuilds when the
/// courier signs in or out.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isSignedIn ? const OrdersScreen() : const LoginScreen();
  }
}
