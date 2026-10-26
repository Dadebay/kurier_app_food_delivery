/// Every user-facing string in the app.
///
/// Turkmen and Russian ship together from day one (slide 10). Adding a third
/// language means one more subclass — the compiler then lists every string
/// that still needs translating.
abstract class AppStrings {
  const AppStrings();

  String get languageCode;
  String get languageName;

  // ─── Shell ───────────────────────────────────────────────────
  String get courierRole;
  String get branch;
  String get onShift;
  String get free;
  String get offShiftBadge;

  // ─── Statuses ────────────────────────────────────────────────
  String get statusAssigned;
  String get statusPickedUp;
  String get statusOnTheWay;
  String get statusDelivered;
  String get statusCashReturned;
  String get statusCancelled;

  // ─── Order card ──────────────────────────────────────────────
  String get sum;
  String get change;
  String get distance;
  String get noChange;
  String changeFrom(String amount);
  String get houseLabel;
  String get entranceLabel;
  String get floorLabel;

  // ─── Day summary ─────────────────────────────────────────────
  String get dayTotal;
  String get cashOnHand;
  String deliveries(int count);
  String get handedOver;

  // ─── History ─────────────────────────────────────────────────
  String get historyTitle;
  String get historyRecent;
  String get historyArchive;
  String get historyEmptyHint;
  String get orderItemsLabel;

  // ─── Route screen ────────────────────────────────────────────
  String get nextStop;
  String get pickupStop;
  String get returnToBranch;
  String get km;
  String get orderNo;
  String get callCustomer;
  String get openInMapsMe;
  String get mapsMeMissingTitle;
  String get mapsMeMissingMessage;
  String get mapsMeInstall;
  String get buildingRoute;
  String get loadingOrders;
  String get showAllOrders;
  String get showThisOrder;

  // ─── Actions ─────────────────────────────────────────────────
  String get actionPickUp;
  String get actionDepart;
  String get actionDeliver;
  String get actionOpenRoute;

  /// Tooltip on the crosshair button that centres the map on the courier.
  String get centerOnMe;

  /// Tooltip on the button that fits the whole route on screen.
  String get showWholeRoute;

  /// Shown when the crosshair is tapped before any fix has arrived.
  String get waitingForGps;

  // ─── Delivery success ───────────────────────────────────────
  String get deliverySuccessTitle;
  String get deliverySuccessMessage;
  String get deliverySuccessButton;

  // ─── Offline ─────────────────────────────────────────────────
  String offlineQueued(int count);

  /// Positions held on the phone while there was no signal.
  String locationsWaiting(int count);

  /// Positions this shift has already reached the server.
  String locationsSent(int count);
  String get offlineNoConnection;
  String get syncing;
  String get allSynced;

  // ─── Cash sheet ──────────────────────────────────────────────
  String get cashTitle;
  String get cashReceived;
  String get changeGiven;
  String get confirmDelivery;
  String get cancel;

  // ─── Auth ────────────────────────────────────────────────────
  String get loginTitle;
  String get loginSubtitle;
  String get phoneNumber;
  String get requestCode;
  String get smsCode;
  String get smsCodeHint;
  String get verify;
  String get demoHint;
  String get codeInvalid;
  String get otpTooManyRequests;
  String get otpRequestFailed;

  // ─── Profile ─────────────────────────────────────────────────
  String get profile;
  String get language;
  String get clearMapCache;
  String get mapCacheCleared;
  String get dataUsage;
  String get appDataUsed;
  String get mobileData;
  String get wifiData;
  String get dataUsageNote;
  String get dataUsageUnavailable;
  String get resetDataUsage;
  String get dataUsageReset;
  String get dataUsedLast30Days;
  String get dataUsageByDay;
  String get dataUsageYesterday;
  String get dataUsageToday;
  String get dataUsageNoHistory;
  String get signOut;

  // ─── Empty / errors ──────────────────────────────────────────
  String get noOrders;
  String get noOrdersHint;
  String get locationDenied;
  String get locationDeniedHint;
  String get locationWaiting;
  String get locationWaitingHint;
  String get locationServiceOff;
  String get locationBackgroundHint;

  // ─── Shift readiness (screen-off tracking) ───────────────────
  /// Android foreground-service notification, shown for the whole shift.
  String get trackingNotificationChannel;
  String get trackingNotificationTitle;
  String get trackingNotificationSubtitle;

  /// Asked for before a shift can start, because without it the courier
  /// disappears from the operator's map the moment the screen locks.
  String get backgroundGateTitle;
  String get backgroundGateBody;
  String get backgroundGateStartAnyway;

  /// Aggressive OEM battery savers kill the tracking service even with the
  /// permission granted; this exemption is what keeps a long shift alive.
  String get batteryGateTitle;
  String get batteryGateBody;
  String get batteryGateAllow;
  String get batteryGateSkip;

  /// Takes the age itself rather than a second count: a fix that is an hour
  /// old should say so in hours, not in 3600 seconds.
  String locationAge(Duration age);
  String locationAccuracy(int meters);
  String get retry;
  String get openSettings;
}

class StringsRu extends AppStrings {
  const StringsRu();

  @override
  String get languageCode => 'ru';
  @override
  String get languageName => 'Русский';

  @override
  String get courierRole => 'КУРЬЕР';
  @override
  String get branch => 'ФИЛИАЛ';
  @override
  String get onShift => 'На смене';
  @override
  String get free => 'Не работаю';
  @override
  String get offShiftBadge => 'Вы не на смене';

  @override
  String get statusAssigned => 'В очереди';
  @override
  String get statusPickedUp => 'Забран';
  @override
  String get statusOnTheWay => 'Еду';
  @override
  String get statusDelivered => 'Доставлен';
  @override
  String get statusCashReturned => 'Сдан';
  @override
  String get statusCancelled => 'Отменён';

  @override
  String get sum => 'СУММА';
  @override
  String get change => 'СДАЧА';
  @override
  String get distance => 'РАССТОЯНИЕ';
  @override
  String get noChange => 'Не нужна';
  @override
  String changeFrom(String amount) => 'с $amount';
  @override
  String get houseLabel => 'д.';
  @override
  String get entranceLabel => 'подъезд';
  @override
  String get floorLabel => 'этаж';

  @override
  String get dayTotal => 'ИТОГ ЗА ДЕНЬ';
  @override
  String get cashOnHand => 'НАЛИЧНЫЕ НА РУКАХ';
  @override
  String deliveries(int count) =>
      '$count ${_plural(count, 'доставка', 'доставки', 'доставок')}';
  @override
  String get handedOver => 'Сдано оператору';

  @override
  String get historyTitle => 'Мои доставки';
  @override
  String get historyRecent => 'Недавние';
  @override
  String get historyArchive => 'Архив';
  @override
  String get historyEmptyHint => 'Здесь появятся доставленные заказы';
  @override
  String get orderItemsLabel => 'Состав заказа';

  @override
  String get nextStop => 'СЛЕДУЮЩАЯ ТОЧКА';
  @override
  String get pickupStop => 'ЗАБРАТЬ ЗАКАЗ';

  @override
  String get returnToBranch => 'ВОЗВРАТ В ФИЛИАЛ';
  @override
  String get km => 'km';
  @override
  String get orderNo => 'Заказ';
  @override
  String get callCustomer => 'Позвонить клиенту';
  @override
  String get openInMapsMe => 'Открыть в MAPS.ME';
  @override
  String get mapsMeMissingTitle => 'MAPS.ME не установлен';
  @override
  String get mapsMeMissingMessage =>
      'Для навигации по голосовым подсказкам и офлайн-картам установите MAPS.ME.';
  @override
  String get mapsMeInstall => 'Установить';
  @override
  String get buildingRoute => 'Строим маршрут…';
  @override
  String get loadingOrders => 'Загружаем заказы…';
  @override
  String get showAllOrders => 'Показать все заказы';
  @override
  String get showThisOrder => 'Показать только этот заказ';

  @override
  String get actionPickUp => 'Забрал';
  @override
  String get actionDepart => 'Выехал';
  @override
  String get actionDeliver => 'Доставил';
  @override
  String get actionOpenRoute => 'Маршрут';
  @override
  String get centerOnMe => 'Моё местоположение';
  @override
  String get showWholeRoute => 'Весь маршрут';
  @override
  String get waitingForGps => 'Определяем местоположение…';

  @override
  String get deliverySuccessTitle => 'Заказ доставлен!';
  @override
  String get deliverySuccessMessage =>
      'Молодец! Продолжай в том же духе — впереди ещё доставки.';
  @override
  String get deliverySuccessButton => 'Дальше';

  @override
  String offlineQueued(int count) =>
      'Нет интернета — '
      '$count ${_plural(count, 'статус', 'статуса', 'статусов')} в очереди, '
      'уйдут при связи';
  @override
  String locationsWaiting(int count) =>
      '$count ${_plural(count, 'точка', 'точки', 'точек')} ждёт связи';
  @override
  String locationsSent(int count) =>
      '$count ${_plural(count, 'точка', 'точки', 'точек')} отправлено';
  @override
  String get offlineNoConnection => 'Нет интернета — работаем офлайн';
  @override
  String get syncing => 'Отправляем…';
  @override
  String get allSynced => 'Всё отправлено';

  @override
  String get cashTitle => 'Наличные';
  @override
  String get cashReceived => 'Получено от клиента';
  @override
  String get changeGiven => 'Сдача выдана';
  @override
  String get confirmDelivery => 'Подтвердить доставку';
  @override
  String get cancel => 'Отмена';

  @override
  String get loginTitle => 'Вход курьера';
  @override
  String get loginSubtitle => 'Введите рабочий номер — пришлём SMS-код';
  @override
  String get phoneNumber => 'Номер телефона';
  @override
  String get requestCode => 'Получить код';
  @override
  String get smsCode => 'Код из SMS';
  @override
  String get smsCodeHint => 'Введите 4 цифры';
  @override
  String get verify => 'Войти';
  @override
  String get demoHint => 'Демо-режим: код 0000';
  @override
  String get codeInvalid => 'Неверный код, проверьте и попробуйте снова';
  @override
  String get otpTooManyRequests =>
      'Слишком много попыток, подождите немного и попробуйте снова';
  @override
  String get otpRequestFailed => 'Не удалось отправить код, попробуйте снова';

  @override
  String get profile => 'Профиль';
  @override
  String get language => 'Язык';
  @override
  String get clearMapCache => 'Очистить кэш карты';
  @override
  String get mapCacheCleared => 'Кэш карты очищен';
  @override
  String get dataUsage => 'Расход интернета';
  @override
  String get appDataUsed => 'Использовано сегодня этим приложением';
  @override
  String get mobileData => 'Мобильный интернет';
  @override
  String get wifiData => 'Wi-Fi';
  @override
  String get dataUsageNote =>
      'За сегодня: карта, заказы, геолокация и другие данные только этого приложения.';
  @override
  String get dataUsageUnavailable =>
      'На этом устройстве счётчик трафика недоступен';
  @override
  String get resetDataUsage => 'Сбросить счётчик';
  @override
  String get dataUsageReset => 'Счётчик интернет-расхода сброшен';
  @override
  String get dataUsedLast30Days => 'Использовано за 30 дней';
  @override
  String get dataUsageByDay => 'По дням';
  @override
  String get dataUsageYesterday => 'Вчера';
  @override
  String get dataUsageToday => 'Сегодня';
  @override
  String get dataUsageNoHistory =>
      'Пока нет данных за прошлые дни — они появятся завтра.';
  @override
  String get signOut => 'Выйти';

  @override
  String get noOrders => 'Заказов нет';
  @override
  String get noOrdersHint =>
      'Как только оператор назначит заказ, он появится здесь';
  @override
  String get locationDenied => 'Нет доступа к геолокации';
  @override
  String get locationDeniedHint =>
      'Оператор и клиент не видят вас на карте. Разрешите доступ в настройках.';
  @override
  String get locationWaiting => 'Ждём координаты телефона';
  @override
  String get locationWaitingHint =>
      'Свежая позиция пока не получена. Включите геолокацию и попробуйте на открытом месте.';
  @override
  String get locationServiceOff => 'Геолокация на телефоне выключена';
  @override
  String get locationBackgroundHint =>
      'Для работы с закрытым экраном разрешите геолокацию «Всегда» в настройках приложения.';

  @override
  String get trackingNotificationChannel => 'Отслеживание смены';
  @override
  String get trackingNotificationTitle => 'A7-TAGAM · Вы на смене';
  @override
  String get trackingNotificationSubtitle =>
      'Геопозиция передаётся оператору. Не закрывайте приложение.';

  @override
  String get backgroundGateTitle => 'Разрешите геолокацию «Всегда»';
  @override
  String get backgroundGateBody =>
      'Без этого разрешения вы пропадаете с карты оператора, как только гаснет экран. '
      'Откройте настройки и выберите «Разрешить всегда».';
  @override
  String get backgroundGateStartAnyway => 'Всё равно начать смену';

  @override
  String get batteryGateTitle => 'Отключите экономию батареи';
  @override
  String get batteryGateBody =>
      'Телефон может закрыть приложение во время смены ради экономии батареи. '
      'Разрешите работу в фоне, чтобы отслеживание не прерывалось.';
  @override
  String get batteryGateAllow => 'Разрешить';
  @override
  String get batteryGateSkip => 'Не сейчас';

  @override
  String locationAge(Duration age) {
    final hours = age.inHours;
    final minutes = age.inMinutes.remainder(60);
    if (hours > 0) return 'Последняя точка: $hours ч $minutes мин назад';
    if (age.inMinutes > 0) {
      return 'Последняя точка: ${age.inMinutes} мин назад';
    }
    return 'Последняя точка: меньше минуты назад';
  }
  @override
  String locationAccuracy(int meters) => 'Точность: около $meters м';
  @override
  String get retry => 'Повторить';
  @override
  String get openSettings => 'Настройки';

  /// Russian needs three plural forms; a courier reading "1 заказов" would
  /// notice immediately.
  static String _plural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    return switch (n % 10) {
      1 => one,
      2 || 3 || 4 => few,
      _ => many,
    };
  }
}

class StringsTm extends AppStrings {
  const StringsTm();

  @override
  String get languageCode => 'tk';
  @override
  String get languageName => 'Türkmençe';

  @override
  String get courierRole => 'KURÝER';
  @override
  String get branch => 'FILIAL';
  @override
  String get onShift => 'Nobatda';
  @override
  String get free => 'Işlemeýärin';
  @override
  String get offShiftBadge => 'Nobatda däl';

  @override
  String get statusAssigned => 'Nobatda';
  @override
  String get statusPickedUp => 'Alyndy';
  @override
  String get statusOnTheWay => 'Ýolda';
  @override
  String get statusDelivered => 'Gowşuryldy';
  @override
  String get statusCashReturned => 'Tabşyryldy';
  @override
  String get statusCancelled => 'Ýatyryldy';

  @override
  String get sum => 'JEMI';
  @override
  String get change => 'GAÝTARGY';
  @override
  String get distance => 'ARALYK';
  @override
  String get noChange => 'Gerek däl';
  @override
  String changeFrom(String amount) => '$amount-dan';
  @override
  String get houseLabel => 'j.';
  @override
  String get entranceLabel => 'girelge';
  @override
  String get floorLabel => 'gat';

  @override
  String get dayTotal => 'GÜNÜŇ JEMI';
  @override
  String get cashOnHand => 'ELDÄKI NAGT';
  @override
  String deliveries(int count) => '$count gowşuryş';
  @override
  String get handedOver => 'Operatora tabşyryldy';

  @override
  String get historyTitle => 'Gowşuryşlarym';
  @override
  String get historyRecent => 'Golaýky';
  @override
  String get historyArchive => 'Arhiw';
  @override
  String get historyEmptyHint => 'Şu ýerde gowşurylan sargytlar peýda bolar';
  @override
  String get orderItemsLabel => 'Sargydyň düzümi';

  @override
  String get nextStop => 'INDIKI NOKAT';
  @override
  String get pickupStop => 'ALYNJAK ÝER';

  @override
  String get returnToBranch => 'FILIALA DOLAN';
  @override
  String get km => 'km';
  @override
  String get orderNo => 'Sargyt';
  @override
  String get callCustomer => 'Müşderä jaň et';
  @override
  String get openInMapsMe => 'MAPS.ME-de aç';
  @override
  String get mapsMeMissingTitle => 'MAPS.ME gurnalmadyk';
  @override
  String get mapsMeMissingMessage =>
      'Sesli ugrukdyrma we oflaýn kartalar üçin MAPS.ME gurnaň.';
  @override
  String get mapsMeInstall => 'Gurnamak';
  @override
  String get buildingRoute => 'Ugur gurulýar…';
  @override
  String get loadingOrders => 'Sargytlar ýüklenýär…';
  @override
  String get showAllOrders => 'Ähli sargytlary görkez';
  @override
  String get showThisOrder => 'Diňe şu sargydy görkez';

  @override
  String get actionPickUp => 'Aldym';
  @override
  String get actionDepart => 'Ýola çykdym';
  @override
  String get actionDeliver => 'Gowşurdym';
  @override
  String get actionOpenRoute => 'Ugur';
  @override
  String get centerOnMe => 'Meniň ýerleşişim';
  @override
  String get showWholeRoute => 'Ähli ugur';
  @override
  String get waitingForGps => 'Ýerleşiş kesgitlenýär…';

  @override
  String get deliverySuccessTitle => 'Sargyt gowşuryldy!';
  @override
  String get deliverySuccessMessage =>
      'Aferin saňa! Ýene-de köp sargyt gowşuryp bilersiň, dowam et.';
  @override
  String get deliverySuccessButton => 'Dowam et';

  @override
  String offlineQueued(int count) =>
      'Internet ýok — $count status nobatda, aragatnaşyk gelende ugradylar';
  @override
  String locationsWaiting(int count) => '$count nokat aragatnaşyga garaşýar';
  @override
  String locationsSent(int count) => '$count nokat ugradyldy';
  @override
  String get offlineNoConnection => 'Internet ýok — oflaýn işleýäris';
  @override
  String get syncing => 'Ugradylýar…';
  @override
  String get allSynced => 'Hemmesi ugradyldy';

  @override
  String get cashTitle => 'Nagt';
  @override
  String get cashReceived => 'Müşderiden alyndy';
  @override
  String get changeGiven => 'Gaýtargy berildi';
  @override
  String get confirmDelivery => 'Gowşuryşy tassykla';
  @override
  String get cancel => 'Ýatyr';

  @override
  String get loginTitle => 'Kurýer girişi';
  @override
  String get loginSubtitle => 'Iş belgiňizi giriziň — SMS kody ugradarys';
  @override
  String get phoneNumber => 'Telefon belgisi';
  @override
  String get requestCode => 'Kod al';
  @override
  String get smsCode => 'SMS kody';
  @override
  String get smsCodeHint => '4 sany giriziň';
  @override
  String get verify => 'Gir';
  @override
  String get demoHint => 'Demo režim: kod 0000';
  @override
  String get codeInvalid => 'Kod nädogry, barlap gaýtadan synanyşyň';
  @override
  String get otpTooManyRequests =>
      'Synanyşyk gaty köp, birazdan gaýtadan synanyşyň';
  @override
  String get otpRequestFailed => 'Kod ugradyp bolmady, gaýtadan synanyşyň';

  @override
  String get profile => 'Profil';
  @override
  String get language => 'Dil';
  @override
  String get clearMapCache => 'Karta keşini arassala';
  @override
  String get mapCacheCleared => 'Karta keşi arassalandy';
  @override
  String get dataUsage => 'Internet harajaty';
  @override
  String get appDataUsed => 'Şu gün bu programma tarapyndan ulanyldy';
  @override
  String get mobileData => 'Mobil internet';
  @override
  String get wifiData => 'Wi-Fi';
  @override
  String get dataUsageNote =>
      'Şu gün diňe bu programmanyň karta, sargyt, geolokasiýa we beýleki trafiki hasaplanýar.';
  @override
  String get dataUsageUnavailable =>
      'Bu enjamda trafik hasaplaýjy elýeterli däl';
  @override
  String get resetDataUsage => 'Hasaplaýjyny täzeden başla';
  @override
  String get dataUsageReset => 'Internet harajatynyň hasaplaýjysy täzelendi';
  @override
  String get dataUsedLast30Days => '30 günde ulanyldy';
  @override
  String get dataUsageByDay => 'Günlere görä';
  @override
  String get dataUsageYesterday => 'Düýn';
  @override
  String get dataUsageToday => 'Şu gün';
  @override
  String get dataUsageNoHistory =>
      'Geçen günler üçin maglumat entek ýok — ertir peýda bolar.';
  @override
  String get signOut => 'Çyk';

  @override
  String get noOrders => 'Sargyt ýok';
  @override
  String get noOrdersHint => 'Operator sargyt bellänsoň, şu ýerde görüner';
  @override
  String get locationDenied => 'Geolokasiýa rugsat ýok';
  @override
  String get locationDeniedHint =>
      'Operator we müşderi sizi kartada görmeýär. Sazlamalarda rugsat beriň.';
  @override
  String get locationWaiting => 'Telefonyň koordinatlaryna garaşylýar';
  @override
  String get locationWaitingHint =>
      'Täze ýerleşiş entek alynmady. Geolokasiýany açyň we açyk ýerde gaýtadan synanyşyň.';
  @override
  String get locationServiceOff => 'Telefonyň geolokasiýasy öçürilen';
  @override
  String get locationBackgroundHint =>
      'Ekran ýapyk wagty işlemek üçin programmanyň sazlamalarynda geolokasiýa hemişelik rugsat beriň.';

  @override
  String get trackingNotificationChannel => 'Nobat yzarlamasy';
  @override
  String get trackingNotificationTitle => 'A7-TAGAM · Siz nobatdasyňyz';
  @override
  String get trackingNotificationSubtitle =>
      'Ýerleşişiňiz operatora ugradylýar. Programmany ýapmaň.';

  @override
  String get backgroundGateTitle => 'Geolokasiýa «Hemişe» rugsat beriň';
  @override
  String get backgroundGateBody =>
      'Bu rugsat bolmasa, ekran sönen badyna operatoryň kartasyndan ýitýärsiňiz. '
      'Sazlamalary açyp «Hemişe rugsat ber» saýlaň.';
  @override
  String get backgroundGateStartAnyway => 'Şonda-da nobaty başla';

  @override
  String get batteryGateTitle => 'Batareýa tygşytlamasyny öçüriň';
  @override
  String get batteryGateBody =>
      'Telefon batareýany tygşytlamak üçin nobat wagty programmany ýapyp biler. '
      'Yzarlama kesilmez ýaly arka planda işlemäge rugsat beriň.';
  @override
  String get batteryGateAllow => 'Rugsat ber';
  @override
  String get batteryGateSkip => 'Häzir däl';

  @override
  String locationAge(Duration age) {
    final hours = age.inHours;
    final minutes = age.inMinutes.remainder(60);
    if (hours > 0) return 'Soňky nokat: $hours sag $minutes min öň';
    if (age.inMinutes > 0) return 'Soňky nokat: ${age.inMinutes} min öň';
    return 'Soňky nokat: bir minutdan az öň';
  }
  @override
  String locationAccuracy(int meters) => 'Takyklyk: takmynan $meters m';
  @override
  String get retry => 'Gaýtala';
  @override
  String get openSettings => 'Sazlamalar';
}
