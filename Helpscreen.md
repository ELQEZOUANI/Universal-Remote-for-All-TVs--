# Helpscreen

This app now runs in full screen on iPad by setting `UIRequiresFullScreen` to `true` in `ios/Runner/Info.plist`.

## What I changed

I added this key to the iOS app configuration:

```xml
<key>UIRequiresFullScreen</key>
<true/>
```

## Why this is needed

On iPad, apps can run in Split View or Slide Over unless the app explicitly says it requires full screen. Flutter will not force full-screen mode by itself.

When `UIRequiresFullScreen` is enabled:

- the app opens as a full-screen iPad app
- iPad multitasking modes like Split View are disabled
- the app can behave like a dedicated remote-control layout

## File updated

- `ios/Runner/Info.plist`

## Optional improvement

If you want to lock the app to landscape on iPad, you can also set preferred orientations in `lib/main.dart` before `runApp()` using `SystemChrome.setPreferredOrientations(...)`.

## How to verify

1. Run the app on an iPad simulator or physical iPad.
2. Open the app.
3. Confirm it uses the whole screen.
4. Confirm Split View / Slide Over is not available for this app.