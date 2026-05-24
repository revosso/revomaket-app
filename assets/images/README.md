# App images

Drop the following PNGs into this folder before publishing the production
build. The runtime falls back to a generated mark when assets are missing, so
the app still renders during development.

| File                       | Size       | Notes                                            |
| -------------------------- | ---------- | ------------------------------------------------ |
| `logo.png`                 | 512x512    | In-app logo (splash + login screen).             |
| `splash_logo.png`          | 1024x1024  | Used by `flutter_native_splash` (transparent BG).|
| `app_icon.png`             | 1024x1024  | Launcher icon (opaque, no transparency).         |
| `app_icon_foreground.png`  | 1024x1024  | Adaptive icon foreground (transparent BG).       |

After replacing the placeholders run:

```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```
