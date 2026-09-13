# Naharym Kurýer

Courier application for the Naharym delivery system — Phase 1 / MVP, item 4 of
the five workplaces described in `Naharym-predlozhenie-RU.pptx` (slide 8).

Screens follow the approved mock-ups in `../Naharym-mockups-RU/`
(`courier_list.png`, `courier_route.png`).

## What it does

- **Assigned orders**, nearest first — address, amount, change, distance.
- **Route inside the app**, drawn on our own tile server. No hand-off to an
  external navigation app.
- **Live position reporting every minute** — the courier appears as a car
  marker on the operator's and the customer's map.
- **One-touch statuses**: забрал → выехал → доставил.
- **Cash confirmation** with the change due, feeding the end-of-shift
  reconciliation.
- **Day total** — deliveries done and cash on hand.
- **Call the customer** straight from the order.
- **Works without internet**: statuses queue on the phone and go out when the
  signal returns. Map tiles are cached for 30 days.
- **Data usage**: the profile reports the Android-measured traffic of this app
  only (map, order sync, GPS and push), with mobile data and Wi-Fi shown
  separately.
- **Turkmen and Russian** from the first launch.

## Running it

```bash
flutter run
```

For demo mode, pass `--dart-define=USE_MOCK_DATA=true`; it serves the shift
from the mock-up (Мырат Аннаев, Parahat branch, orders 1042–1044). **Sign in
with any phone number and the code `000000`.**

## Configuration

Everything server-side lives in
[`lib/core/constants/app_config.dart`](lib/core/constants/app_config.dart):

| Constant | Purpose |
|---|---|
| `apiBaseUrl` | Backend. Point at the customer's own server at install time. |
| `useMockData` | `false` switches every repository call to the real backend. |
| `mapTileUrl` | Our tile server — no usage fee, no foreign dependency. |
| `osrmBaseUrl` | Routing endpoint. |
| `trackingInterval` | Position upload period (proposal promises 3–5 min). |
| `tileCacheMaxStale` | How long tiles stay usable offline. |

Backend paths are listed in `ApiPaths`
([`lib/core/network/api_client.dart`](lib/core/network/api_client.dart)).

## Structure

```
lib/
  core/
    constants/     app_config.dart — every server address and tuning value
    data/          repositories + the demo data set
    localization/  AppStrings (ru / tk) and the language provider
    models/        order, address, courier, order status, queued action
    network/       Dio client and the endpoint list
    services/      location, tracking, routing, offline queue, tile cache
    theme/         colours, type, icons — taken from the mock-ups
    widgets/       map, car marker, buttons, sync banner, loader
  modules/
    auth/          phone + SMS code sign-in
    orders/        the order list (courier_list.png)
    route/         the live map and status buttons (courier_route.png)
    shift/         ShiftProvider — the working day
    profile/       shift figures, language, map cache, sign-out
```

### How writes work

Nothing writes straight to the network. Every status tap, cash confirmation and
position ping goes into a Hive-backed outbox
(`core/services/offline_queue_service.dart`) and is sent from there, oldest
first. One code path online and offline, so a tap made in a basement cannot be
lost. Pings are the single exception: a queued ping replaces the previous one,
because the operator wants the current position rather than a backlog.

## Permissions

Location (including background) and internet are declared for both platforms.
Background location is what keeps the marker moving while the phone is in a
pocket between deliveries.

## Assets

- `assets/fonts/` — Gilroy, matching the other Naharym surfaces.
- `assets/animations/delivery_loader.mp4` — the loading animation.
- `assets/icons/car_marker.svg` — the courier's map marker.

## Tests

```bash
flutter test
```

Covers the status life-cycle, change-due arithmetic (including the case where
the customer's note is smaller than the bill) and the money/distance formatting.
