# Fixed black theme and startup surfaces

The iOS launch screen uses the `StartupBackground` named color (#000000). The
window, root view, WKWebView, scroll view and under-page area also use black;
WebKit is non-opaque. The app requests Dark appearance for native UI and web
color-scheme defaults. Build 2 invalidates the previous build's launch snapshot.

Before restoring/loading the first page, WebKit's persistent cookie store receives
only the `night_mode=2` display preference for x.com and twitter.com. Login cookies,
interaction-state restoration, Control Panel choices unrelated to appearance,
rotation and pinch zoom keep their existing mechanisms. Control Panel's theme is
fixed to Lights Out after merging stored overrides.

`Resources/black-theme.js` runs at document start on X/Twitter hosts. It sets black
root/main/dialog/navigation/form surfaces and dark color scheme before first paint;
body-style and head/document replacement observers retain the theme after site
updates. There is no permanent polling timer or full tweet-tree scan. Accent controls
and media pixels are not inverted. External sign-in hosts do not receive this CSS.

Verification on the shared virtual iPhone uses separate baseline/fixed diagnostic
bundle IDs and local HTML, with no account session. The fixture holds the system
launch screen, the native blank-web-view stage, unstyled HTML, styled HTML and a
subsequent attempt to set a white page. Baseline shows white at launch/native/unstyled;
the fixed build stays black across these stages in both system appearances. Fixture
hooks are confined to separate QA source copies; they are not part of the product.
Both temporary apps are uninstalled, the guest/owned GUI shut down and its appearance
restored. Private captures/receipts are in
`~/.local/state/custom-twitter-startup/20261107/`.

DOM checks also cover white-style rewrites, style/body replacement, colored controls
and external sign-in scope. The standard deployment-policy suite and native compilation
pass. The app is registered with the existing `ios-push twitter` queue for in-place
installation and persistent renewal approval; product UI is not driven during delivery.

Apple API references:
- https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen/uicolorname
- https://developer.apple.com/documentation/webkit/wkwebview/underpagebackgroundcolor
