# Fixed black theme and startup surfaces

The iOS launch screen uses the `StartupBackground` named color (#000000). The
window, root view, WKWebView, scroll view and under-page area also use black.
The web view keeps an opaque backing for WebKit's snapshots, with explicit black
loading colors. The app requests Dark appearance for native UI and web
color-scheme defaults. Build 2 invalidates the previous build's launch snapshot.

A native black cover masks WebKit's empty white canvas during initial loading.
The isolated theme script releases it after two animation frames once the black
body style is attached; navigation completion is a fallback. It is also used
while recovering a terminated WebContent process. It is removed for normal page
interaction and history gestures.

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

Delivered on 2026-11-07 through `ios-push` job
`20261107T035227Z-68a340fb41`, using source `67e287b` (build 2). The queue confirmed
`installed`: installed in place and approved for renewal. The signed device build
succeeded; the product was not launched or uninstalled during delivery.

The owner requested an immediate rollback while the swipe-preview repair was being
qualified. Job `20261107T044830Z-defb659ce3` installed source `d3584de` in place and
approved it for renewal on 2026-11-07. That is the version before the black-theme
change, including the previously tested rotation and zoom support.

## Black swipe transitions

At the owner's request, build 4 replaces history preview images with solid black.
`BlackHistoryWebView` clears the transient `SwipeSnapshot` layer's contents and
sets its background to opaque black, including when WebKit has a native image.
The hook runs on native view insertion/layout and leaves gesture recognition,
cancellation, completion and destination-page rendering with WebKit.

The former viewport capture, JPEG encoding, image cache and image checkpoint
code are removed. On startup the app deletes only the obsolete
`interaction-state.previews` sidecar. The original WebKit interaction-state file,
login store and Control Panel preferences retain their existing mechanisms.
The startup cover and fixed Lights Out styling remain in place.

The transient layer name is a WebKit implementation detail. Verify native
back/forward drags after future OS changes, including restored history.

The build-4 native fixture passed with zero failures on 2026-11-07. All six
rendered drag surfaces had no image contents and an opaque black background:
back/forward between documents, same-document history and both directions after
reopening. Canceled drags, completed navigation and session restoration were
checked. A seeded obsolete preview file was removed while an unrelated app-data
sentinel was preserved. The seven standard deployment checks also passed.
Private evidence is in `~/.local/state/custom-twitter-black-swipes/20261107/`.
Diagnostic apps were uninstalled and the shared guest/owned GUI shut down.

The prior image-preview build was installed in place on 2026-11-07 by job
`20261107T062323Z-234ab8defa`, source `00575e1` (build 3), with renewal approval.
Its implementation and qualification history are retained in Git.

Apple API references:
- https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen/uicolorname
- https://developer.apple.com/documentation/webkit/wkwebview/underpagebackgroundcolor
