import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Holds the selected language and hands out the matching [AppStrings].
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs)
    : _strings = _prefs.getString(_key) == 'tk'
          ? const StringsTm()
          : const StringsRu();

  static const String _key = 'app_language';

  final SharedPreferences _prefs;
  AppStrings _strings;

  AppStrings get strings => _strings;
  Locale get locale => Locale(_strings.languageCode);

  static const List<AppStrings> supported = [StringsRu(), StringsTm()];

  Future<void> select(AppStrings strings) async {
    if (strings.languageCode == _strings.languageCode) return;
    _strings = strings;
    await _prefs.setString(_key, strings.languageCode);
    notifyListeners();
  }
}

/// `context.s.actionDeliver` — short enough to use inline in a widget tree.
extension LocalizedContext on BuildContext {
  AppStrings get s => watch<LocaleProvider>().strings;

  /// Non-listening variant for callbacks (snackbars, dialogs).
  AppStrings get sr => read<LocaleProvider>().strings;
}
