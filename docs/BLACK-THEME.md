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

## Swipe previews

WebKit serializes the page/history state separately from its in-memory gesture
images. A history destination restored after process exit can therefore have no
image, and WebKit creates a white fallback surface for that swipe.

`HistoryPreviews` keeps up to eight compressed viewport images in the app's private
Application Support directory. A sidecar records the exact interaction-state bytes,
history URLs and image positions. A mismatched/corrupt sidecar is ignored; the original
interaction-state file retains its format. State and sidecar writes are atomic, and
an interruption between them safely drops the stale preview set.

Captures follow navigation, scrolling/zooming and background checkpoints, with
coalescing and bounded image dimensions. There is no preview polling timer. A small
web-view subclass handles WebKit's transient layer named `SwipeSnapshot`: it preserves
WebKit's own image, supplies a matching cached image when absent, and uses black for
an uncached destination. Native gesture recognition, completion and cancellation
remain owned by WebKit. The layer name is a WebKit implementation detail, so native
gesture checks are required for future OS updates.

Capture requests skip active touch/scroll/zoom and history transitions. Cached images
fit within the gesture surface after orientation changes, with black around them.

### Qualified repair

The 2026-11-07 native fixture passed with zero test failures. It recorded twelve
rendered drag frames: back/forward between documents, same-document history, and
both directions after separate process exits. The control disabled preview capture
and fallback handling; its restored destinations had no native image and a white
surface. Both repaired restored frames contained the matching saved image on black.
Warm native images were retained. The final sidecar matched the exact saved state
and held three images for the three-entry fixture history.

Canceled preview drags and subsequent completed gestures were checked separately.
One control-only forward gesture needed the fixture's public WebKit navigation
fallback; none of the repaired paths used it. Page setup used public WebKit calls
because simulator accessibility link taps proved unreliable. Diagnostic frame
capture ran inside the fixture, and readiness checks waited for loading and prior
transitions to settle. These hooks are absent from production.

The initial response was held back to inspect the empty canvas; the native startup
cover stayed black. The site-style rewrite/replacement DOM checks and seven standard
deployment checks passed. The temporary diagnostic apps were uninstalled, and the
shared guest/owned GUI were closed. Private source, logs, captures and cleanup
receipts are under `~/.local/state/custom-twitter-startup/20261107/gestures/`.

The repaired build was delivered on 2026-11-07 by job
`20261107T062323Z-234ab8defa`, source `00575e1` (build 3). Its signed device build
and in-place installation succeeded, and the queue confirmed `installed` with
renewal approval. The product was not launched or uninstalled during delivery.
Older history without a stored image uses black while loading; previews are
retained as pages are visited with this build.

Apple API references:
- https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen/uicolorname
- https://developer.apple.com/documentation/webkit/wkwebview/underpagebackgroundcolor
