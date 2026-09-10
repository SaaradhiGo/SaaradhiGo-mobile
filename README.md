# VahanGo (SaaradhiGo Mobile)

Rider-facing Flutter application for the SaaradhiGo ride-hailing platform. Built with Flutter 3 / Dart 3, targeting Android, iOS, and the web.

The Flutter package name is `vahango` (see [pubspec.yaml](pubspec.yaml)).

## Features

- Phone-number + OTP authentication, profile setup, and session persistence
- Live map and ride flow (set destination, precise pickup, route preview, search, driver matched, tracking, ride summary, rating) powered by `flutter_map` + OpenStreetMap tiles and `flutter_polyline_points`
- WebSocket-backed live ride state (request channel + per-trip channel) with sync / cancelled / payment-pending overlays driven by Riverpod state
- In-app wallet: add money, transaction status, payment success — integrated with Cashfree (`flutter_cashfree_pg_sdk`) and a web fallback helper
- Push notifications via Firebase Cloud Messaging, plus foreground local notifications and an ongoing-ride notification service (`flutter_local_notifications`, `flutter_background_service`)
- Ride history, notifications inbox with pagination, profile management (personal info, payment methods, privacy/security, help & support)
- Local caching via Hive and `shared_preferences`; geolocation via `geolocator`

## Project structure

```
lib/
├── main.dart                  # Entry point, GoRouter, theme, lifecycle wiring
├── core/
│   └── app_config.dart        # Base URLs and API/WS route constants
├── navigation/
│   └── ride_navigation_handler.dart
├── providers/                 # ChangeNotifier providers (auth, map, history, wallet, notifications)
├── state/                     # Riverpod ride state + lifecycle observer
├── screens/
│   ├── splash/
│   ├── auth/                  # login, OTP verification
│   ├── home/                  # home, rider flow, wallet, payments, notifications, route/precise-pickup
│   ├── profile/               # profile setup, edit info, payment methods, privacy, help
│   └── components/            # overlays and shared banners
├── services/                  # api, websocket, location, map, ride, wallet, payment, notifications
│   └── models/                # location, notification, trip, wallet
└── utils/
    └── geometry_utils.dart
assets/
├── markers/                   # map marker assets
└── icon/                      # app icon assets
test/                          # widget and provider tests
```

## Prerequisites

- Flutter SDK with Dart `^3.11.1`
- Android Studio / Xcode for native builds
- A Firebase project (Android `google-services.json` / iOS `GoogleService-Info.plist`) for push notifications
- Cashfree merchant credentials (sandbox or production)
- A reachable SaaradhiGo backend (see [SaaradhiGo-backend](../SaaradhiGo-backend))

## Configuration

Runtime configuration is loaded from `assets/.env` via `flutter_dotenv` and is **declared as an asset** in `pubspec.yaml`, so the file must exist before running.

Create `assets/.env` with:

```env
BASE_URL=https://dev.api.saaradhigo.in/api/v1
WS_BASE_URL=wss://dev.api.saaradhigo.in/ws
GOOGLE_MAPS_API_KEY=your_google_maps_key
CASHFREE_APP_ID=your_cashfree_app_id
CASHFREE_ENVIRONMENT=sandbox
```

Defaults (used when a key is missing) live in [lib/core/app_config.dart](lib/core/app_config.dart).

## Getting started

```bash
flutter pub get
flutter run                    # default device
flutter run -d chrome          # web build
flutter run -d <android|ios>   # specific platform
```

Build artifacts:

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release
```

## Code generation

Riverpod generators are used for some providers. After changing annotated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Testing

```bash
flutter test
flutter analyze
```

Existing tests cover auth/map providers, notification pagination, the personal-info and privacy-security screens, the profile tab, and ride state recovery.

## Backend integration

The app expects the SaaradhiGo backend at the URLs configured above. Endpoints and WebSocket channels are centralized in [lib/core/app_config.dart](lib/core/app_config.dart):

- REST: `/auth/otp/`, `/auth/login/`, `/auth/update/`, `/auth/profile/`, `/rider/notifications/`, `/ride/ride-history/`, `/ride/active/`
- WebSocket: `/ride/request/`, `/ride/trip/{tripId}/`

## State management

The app uses **both** `provider` (ChangeNotifier) and `flutter_riverpod`:

- `provider` for cross-screen concerns: auth, map, history, wallet, notifications
- `riverpod` for the ride state machine, lifecycle observation, and global overlays (sync / cancelled / payment-pending)

Both are bridged in [lib/main.dart](lib/main.dart) via an outer `UncontrolledProviderScope` wrapping a `MultiProvider`.

## Related repositories

- [SaaradhiGo-backend](../SaaradhiGo-backend) — API, WebSocket gateway, and database
- [SaaradhiGo-web](../SaaradhiGo-web) — web client and platform monorepo
