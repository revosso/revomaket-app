# Revomaket Mobile App

Production-ready Flutter wrapper for [revomaket.com](https://revomaket.com/),
optimized for Android and iOS with Auth0 authentication, deep linking,
Firebase push notifications, offline handling, and a polished UX shell.

- **Package id:** `com.brackstechnologies.revomaket`
- **Web target:** `https://revomaket.com/`
- **Tech stack:** Flutter (Dart), `flutter_inappwebview`, `auth0_flutter`,
  `flutter_secure_storage`, `connectivity_plus`, `firebase_messaging`,
  `app_links`, `url_launcher`, `permission_handler`, `local_auth`, Provider.

## Table of contents

1. [Project structure](#project-structure)
2. [Quick start](#quick-start)
3. [Environment variables](#environment-variables)
4. [Auth0 setup](#auth0-setup)
5. [Firebase Cloud Messaging setup](#firebase-cloud-messaging-setup)
6. [Deep linking & universal links](#deep-linking--universal-links)
7. [Building for Android](#building-for-android)
8. [Building for iOS](#building-for-ios)
9. [Branding (icons & splash)](#branding-icons--splash)
10. [Quality gates](#quality-gates)

## Project structure

```
lib/
├── app.dart                       # Root widget + provider wiring
├── main.dart                      # Entry point + env bootstrap
├── config/
│   ├── app_routes.dart            # Named routes
│   ├── app_theme.dart             # Material 3 light/dark themes
│   └── env_config.dart            # Reads .env / --dart-define
├── core/
│   ├── constants/                 # App-wide constants, colors, strings
│   ├── errors/exceptions.dart     # Typed AppException hierarchy
│   └── utils/                     # Logger, url helpers, etc.
├── services/                      # Cross-cutting singletons
│   ├── biometric_service.dart
│   ├── connectivity_service.dart
│   ├── deep_link_service.dart
│   ├── notification_service.dart  # Firebase + local notifications
│   ├── package_info_service.dart
│   ├── permission_service.dart
│   ├── secure_storage_service.dart
│   └── url_launcher_service.dart
├── features/
│   ├── auth/
│   │   ├── data/                  # Repository + models (session/user)
│   │   ├── services/              # AuthService, SessionManager
│   │   └── presentation/          # AuthProvider + LoginScreen
│   ├── splash/                    # SplashScreen + bootstrap flow
│   ├── webview/                   # WebViewScreen + supporting widgets
│   └── offline/                   # OfflineScreen with auto-reconnect
└── shared/
    └── widgets/                   # AppLogo, LoadingScreen, ...
```

Configuration files live alongside the platform folders:

```
android/app/build.gradle.kts          # Package id, signing, ProGuard
android/app/src/main/AndroidManifest.xml  # Permissions, deep links, Auth0
ios/Runner/Info.plist                 # Permissions, URL schemes, ATS
.env / .env.example                   # Environment variables
```

## Quick start

```bash
# 1. Install dependencies
flutter pub get

# 2. Copy the env template and fill in your values
cp .env.example .env

# 3. Run on a connected device
flutter run
```

If `.env` is missing or `AUTH0_*` values are blank, the app falls back to
loading `https://revomaket.com` without an auth gate so the WebView is still
usable during early development.

## Environment variables

`lib/config/env_config.dart` reads values in this order:

1. `--dart-define=KEY=value` (preferred for CI / release builds)
2. `.env` (bundled as an asset, used for local dev)
3. Empty fallback

| Key                  | Required | Description                                                    |
| -------------------- | -------- | -------------------------------------------------------------- |
| `AUTH0_DOMAIN`       | yes      | Auth0 tenant domain (e.g. `revomaket.us.auth0.com`).           |
| `AUTH0_CLIENT_ID`    | yes      | Native application Client ID.                                  |
| `AUTH0_AUDIENCE`     | optional | Identifier of the Auth0 API the app calls.                     |
| `AUTH0_SCHEME`       | yes      | Custom scheme (matches `applicationId` by default).            |
| `WEB_BASE_URL`       | yes      | URL loaded inside the WebView. Defaults to revomaket.com.      |
| `FIREBASE_VAPID_KEY` | optional | Only required if you also build for Flutter web.               |

> Production builds should pass secrets via `--dart-define` instead of bundling
> them in `.env`. The `.env` file is gitignored.

## Auth0 setup

1. **Create a "Native" application** in the [Auth0 dashboard](https://manage.auth0.com).
2. Under **Allowed Callback URLs** add (replace `YOUR_TENANT`):

   ```
   https://YOUR_TENANT.auth0.com/android/com.brackstechnologies.revomaket/callback,
   com.brackstechnologies.revomaket://YOUR_TENANT.auth0.com/android/com.brackstechnologies.revomaket/callback,
   com.brackstechnologies.revomaket://YOUR_TENANT.auth0.com/ios/com.brackstechnologies.revomaket/callback,
   https://YOUR_TENANT.auth0.com/ios/com.brackstechnologies.revomaket/callback
   ```

3. Use the **same list** for **Allowed Logout URLs**.
4. In the application **Settings → Advanced → Grant Types**, enable
   `Authorization Code`, `Refresh Token`, and (if you call your own API) the
   relevant resource grants.
5. In **APIs → Settings**, enable "Allow Offline Access" so refresh tokens are
   issued.
6. Update `.env` with the resulting values and run `flutter run` again.
7. The Android manifest already wires the placeholder via:

   ```kts
   manifestPlaceholders["auth0Domain"] = "<your domain>"
   manifestPlaceholders["auth0Scheme"] = "com.brackstechnologies.revomaket"
   ```

   Pass `AUTH0_DOMAIN` through Gradle (`gradle.properties` or `-PAUTH0_DOMAIN=...`)
   to override at build time.

### Social logins

Enable the desired connections (Google, Apple, Facebook, etc.) in
**Authentication → Social**. Universal Login then surfaces them automatically -
no extra code is required on the Flutter side.

### Biometric unlock (optional)

`BiometricService` exposes `isAvailable()`, `setEnabled()`, and
`authenticate()`. Hook it into your settings UI when you are ready to expose
biometric unlock; the `local_auth` plugin handles Face ID / Touch ID /
fingerprint prompts.

## Firebase Cloud Messaging setup

Push notifications are fully wired but require platform configuration files
to ship. Until both are present the app logs a single warning and degrades
gracefully (the rest of the app keeps working).

### Android

1. Run `flutterfire configure` **or** manually create a Firebase project and
   download `google-services.json`.
2. Place the file at `android/app/google-services.json`.
3. In `android/settings.gradle.kts`, uncomment the Google Services plugin:

   ```kts
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

4. In `android/app/build.gradle.kts`, uncomment:

   ```kts
   id("com.google.gms.google-services")
   ```

   and the Firebase BoM dependencies in the `dependencies` block.

### iOS

1. Download `GoogleService-Info.plist` and drag it into `ios/Runner/` from
   Xcode (make sure it is added to the **Runner** target).
2. Enable the **Push Notifications** and **Background Modes → Remote
   notifications** capabilities in Xcode.
3. Upload your APNs key in **Firebase → Project Settings → Cloud Messaging**.

### App-level wiring

`NotificationService` is created at app startup via `MultiProvider`. It
requests permissions, fetches the FCM token (cached in secure storage), shows
foreground notifications via `flutter_local_notifications`, and exposes
`onMessageOpened` so screens can react to taps. Deep linking from notifications
just needs the payload to include a Revomaket URL: pipe it through
`DeepLinkService` from your handler.

## Deep linking & universal links

The app accepts:

- Custom scheme: `revomaket://path?query` (mapped to
  `https://revomaket.com/path?query`).
- HTTPS app links / universal links on `revomaket.com` and `www.revomaket.com`.

`DeepLinkService` normalizes both formats to a single `Uri` stream that the
WebView consumes via `Provider`.

### iOS universal links

Add the **Associated Domains** capability in Xcode and include
`applinks:revomaket.com` and `applinks:www.revomaket.com`. Host the matching
`apple-app-site-association` file at `https://revomaket.com/.well-known/`.

### Android app links

`AndroidManifest.xml` declares an `android:autoVerify="true"` intent filter for
`https://revomaket.com`. Host the matching
`https://revomaket.com/.well-known/assetlinks.json` to enable system-level
verification.

## Building for Android

```bash
# Debug
flutter run

# Release APK
flutter build apk --release \
  --dart-define=AUTH0_DOMAIN=YOUR_DOMAIN \
  --dart-define=AUTH0_CLIENT_ID=YOUR_CLIENT \
  --dart-define=AUTH0_AUDIENCE=YOUR_AUDIENCE

# Release App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define=AUTH0_DOMAIN=YOUR_DOMAIN \
  --dart-define=AUTH0_CLIENT_ID=YOUR_CLIENT
```

### Signing

1. Generate a keystore:

   ```bash
   keytool -genkey -v -keystore ~/revomaket-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias revomaket
   ```

2. Create `android/key.properties` (gitignored):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=revomaket
   storeFile=/absolute/path/to/revomaket-release.jks
   ```

3. The build script in `android/app/build.gradle.kts` automatically picks it
   up for release builds.

### Min/target SDK

- `minSdk = 23` (Android 6.0 - required by `auth0_flutter`).
- `targetSdk = compileSdk = 35` (Android 15).
- ProGuard / R8 enabled in release with rules in `android/app/proguard-rules.pro`.

## Building for iOS

```bash
# Open the Xcode project once to set the team / bundle id
open ios/Runner.xcworkspace

# Run on a simulator
flutter run -d ios

# Archive a release build (replace with your dart-defines)
flutter build ipa --release \
  --dart-define=AUTH0_DOMAIN=YOUR_DOMAIN \
  --dart-define=AUTH0_CLIENT_ID=YOUR_CLIENT
```

In Xcode you should also:

- Set the bundle identifier to `com.brackstechnologies.revomaket`.
- Set the team for code signing.
- Add capabilities: **Push Notifications**, **Background Modes** (Remote
  notifications, Background fetch), **Associated Domains** (universal links).
- Confirm Info.plist usage strings (already present) reflect your brand voice.

## Branding (icons & splash)

The placeholders in `assets/images/` keep the app rendering during early
development. Replace them with your final art (sizes documented in
`assets/images/README.md`) and regenerate the launch screens / launcher icons:

```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

## Quality gates

```bash
flutter analyze            # lints + strict typing (must be 0 issues)
flutter test               # unit + widget tests
flutter build apk --debug  # smoke test android build wiring
```

The project ships with strict analyzer settings (`strict-casts`,
`strict-inference`, `strict-raw-types`) and runs cleanly out of the box.

## License

Proprietary - © Bracks Technologies / Revomaket. All rights reserved.
