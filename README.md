# Custom Twitter for iPhone

A small, unofficial iOS app that opens x.com full screen and injects [Control Panel for Twitter](https://github.com/insin/control-panel-for-twitter). Promoted posts are hidden while the **For you** timeline stays available. Built with Swift, UIKit and WKWebView; no backend, X API key, analytics SDK, or third-party Swift packages.

The app supports iOS 17 and later and has been used on iOS 26. The current target is **iPhone-only**; native iPad layouts have not been implemented or verified. This project is not affiliated with X.

**Starting with Linux, a fresh Mac/Hackintosh, and a free Apple Account?** Follow [Free account first, paid later](docs/FREE-TO-PAID.md). It covers first-time Xcode setup, phone trust, Linux deployment, and the later signing transition.

## What it changes

- Hides ads and Control Panel's default upsells/recommendation clutter, while retaining For you, inline retweets/quote tweets, counts, views, and the existing blue-check appearance.
- Hides the header, bottom navigation, and floating compose button together while scrolling down; restores them while scrolling up. Hides the new-posts pill above the timeline.
- Uses the whole screen with no native navigation bars. Supports pull to refresh and WebKit back/forward gestures.
- Keeps the website's login in the app's own persistent WebKit store. Reopens the saved page and back/forward history after the app is ended; settings changes supported by the injected script persist too.
- Opens unrelated sites in a Safari view. Google/Apple sign-in popups stay in the app's web session. Passkeys do not work in this wrapper; use password-based sign-in.

The website still owns its UI and can change it. If iOS terminates only the web content process, the app reloads in place; x.com may rebuild the timeline from its top.

## Build directly in Xcode

You need a Mac with a compatible full Xcode installation and your own Apple Account. A Hackintosh can act as the build host if its macOS/Xcode/device setup already works. The source contains no developer login, signing key, device pairing record, or account-specific signing configuration.

1. Clone this repository on the Mac and open `Twitter.xcodeproj`.
2. Add your account in **Xcode → Settings → Accounts** and choose your own personal or paid team.
3. Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig`. Fill in your team ID and a unique bundle ID in your own namespace. This file is ignored by Git; the project includes it when present. Do not use the public `com.example.CustomTwitter` placeholder for a real installation.
4. Connect/unlock your iPhone with a data cable, trust this Mac, and enable **Settings → Privacy & Security → Developer Mode** when requested. Complete its restart confirmation. Let Xcode prepare the device.
5. Select the **Twitter** scheme and your physical iPhone, then Run. Complete any Keychain or developer-app trust prompts.
6. Sign into x.com inside the app. Nothing from another developer's login is needed or included.

Free Personal Team signing has short-lived profiles and app/device limits; paid development signing still expires. Check [Apple's current account rules](https://developer.apple.com/help/account/basics/about-your-developer-account) and [Xcode compatibility](https://developer.apple.com/xcode/system-requirements). TestFlight/App Store publication is not configured by this project.

**Updates:** keep your chosen bundle ID and signing identity consistent and install over the app. Uninstalling loses the website session and saved app data. Someone else's bundle ID is not required to use the app.

## Command-line build on the Mac

Either copy `twitter.example.json` to ignored `twitter.local.json` and fill in `team`, `device`, and `bundleId`, or provide the equivalent environment variables:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
SIGNING_DEVICE=YOUR_HARDWARE_DEVICE_UDID \
BUNDLE_ID=com.yourname.CustomTwitter \
python3 scripts/build.py
```

Use the **hardware UDID**, not a simulator UUID or an unrelated CoreDevice identifier. The output is `build/native/Release-iphoneos/Twitter.app`. The builder uses automatic signing and can register the specified device through your authorized Xcode account. Its default build requires a usable physical destination. After initial provisioning, `python3 scripts/build.py --generic` can build while that device is disconnected; verify that the resulting profile still includes it before installation.

The Mac user must have signing/Keychain access. When ordinary SSH signing cannot access the login Keychain, run the build attached in the desktop user's GUI session; the Linux helper below does this with `sudo -n launchctl asuser`, then drops back to that user. Arrange the required local sudo policy yourself; no password is stored in the project. No temporary LaunchAgent is used for builds.

`Config/Local.xcconfig` is for direct Xcode usage; `twitter.local.json`/environment values are what the Python builder reads. Command-line build arguments override the project defaults. Keep both local files consistent if you use both approaches.

## Develop on Linux and build on a Mac

Linux owns the source checkout; Xcode runs on the Mac over trusted SSH. Requirements: Python 3, SSH, rsync on Linux; Xcode, system Python, rsync, and a logged-in GUI user on the Mac. Pair the phone with the **Mac**, not merely with Linux.

1. Configure and verify an SSH alias such as `ios-build` for your Mac. Pin its host key; the helper requires strict host checking. It uses the normal SSH configuration, including any trusted LAN/VPN discovery you already have.
2. Copy `twitter.example.json` to `twitter.local.json` on Linux. Fill in your own `host`, dedicated absolute `remoteRoot`, `team`, `device`, and `bundleId`. `knownHosts` is an optional workstation path to a dedicated trust file. Keep `iosTools` null for standalone use.
3. Run from this repository on Linux:

```sh
python3 scripts/deploy.py sync build install
```

You can run each step separately:

```sh
python3 scripts/deploy.py sync
python3 scripts/deploy.py build
python3 scripts/deploy.py install
```

- **sync** mirrors sources with rsync `--delete`, preserving build output, Xcode user state, and local settings. It refuses a populated unrelated destination. It sends a minimal Mac-local JSON with only team/device/bundle ID; workstation settings stay on Linux.
- **build** discovers the actual SSH/desktop user and UID, enters that GUI session, and builds attached under a shared signing lock. The Mac log is `<remoteRoot>/build/xcode.log`.
- **install** verifies the signature, bundle/name, signed identity, profile/team/device membership, and validity margin, then installs in place and launches. It never uninstalls the product. This helper uses direct `devicectl` installation; it does not publish an OTA install page.

`minimumProfileDays` defaults to 1, allowing freshly provisioned free-team development apps. A paid setup can choose 45. A short-lived/free profile does not qualify for the separate monthly-renewal system below.

Do not sync a shared mirror while it is building or between a recorded build and install. The shared lock lives at `~/Library/Caches/ios-app-refresh/signing.lock`; wait for another signer rather than deleting its lock. If the physical device is unavailable, finish pairing/device support or restore wireless reachability; successful source upload alone is not installation.

## Optional monthly renewal with ios-tools

[**ios-tools**](https://github.com/VisarDomi/ios-tools) is an optional separate toolkit for approved-source paid development-app renewal. It is not needed to build in Xcode or to use this app. Read that toolkit's current renewal runbook and establish its Mac account/device configuration first.

For integration, set `iosTools` in your Linux `twitter.local.json` to its absolute **Mac** checkout path. `deploy.py sync` registers this repository using its Mac-local signing settings. The manifest's repository name is `custom-twitter` and its app name is `twitter`.

A deliberate build records the input fingerprint, and a completed direct install approves the exact artifact as the renewal baseline. The app's source, project/configuration, vendored script, builder/settings helper, and Mac-local JSON are approved inputs. An input change blocks unattended renewal until deliberately deployed and approved; do not bypass that gate. The inherited `IOS_REFRESH_LOCK_FD` keeps renewal and the builder on the same signing lock.

After a verified deployment, perform one actual renewal in the Mac user's GUI session using the toolkit's `refresh-installed.py refresh --force --repo custom-twitter`. Check completed installation and advanced profile deadlines, then enable that repository's scheduler with its `install --repo custom-twitter` command. A zero exit from a deferred/locked check is not proof of renewal. Profile renewal does not extend the membership or signing certificate.

If the same installed bundle was previously registered under another repository, coordinate a state-preserving migration and retire its old registration first. The toolkit rejects duplicate bundle ownership. Do not register two schedulers for the same app, and do not change a bundle ID to get past that check.

## Code and maintenance

| Path | Owns |
| --- | --- |
| `Twitter/WebController.swift` | WebKit host, content-control overrides, bar behavior, navigation/popups, durable interaction-state restoration |
| `Twitter/AppDelegate.swift` | App/scene lifecycle and session checkpoints |
| `Config/` | Public defaults and an ignored local Xcode configuration |
| `Resources/` | Info.plist, icon source, asset catalog |
| `Vendor/control-panel-for-twitter/` | Vendored script, version, MIT license and additional notice |
| `scripts/build.py` | Native signed build, injection-contract check, shared signing lock |
| `scripts/deploy.py` | Optional Linux → Mac sync/build/verified in-place install |
| `scripts/settings.py` | Ignored local JSON/environment configuration |
| `scripts/renewal.py` | Optional registration manifest for ios-tools |
| `tests/` | Identity, install-failure, approval-order, and signing-lock policy checks |

Run the Python checks on Linux or macOS:

```sh
python3 -m unittest discover -s tests -v
```

Native compilation needs a Mac. Test actual scrolling/bar controls, sign-in/popups, cold/warm page restoration, and in-place update session retention on the phone when changing those areas. The WKWebView is inspectable for debugging; inspection is not a reason to publish cookie/session data.

For a Control Panel update, fetch the intended upstream release's `script.js`, `LICENSE`, and `NOTICE`, record its tag in `VERSION`, review its defaults against `ControlPanel.overrides`, and build/test. The builder rejects a script that no longer exposes the expected `script#cpftSettings` injection contract; silently dropping that contract would restore unwanted defaults such as hiding For you.

Personal JSON/xcconfig files, signing keys, profiles, build output, and device sessions are not source. Keep them out of commits and release artifacts.

## License

The wrapper/tooling code is MIT licensed; see [LICENSE](LICENSE). The vendored Control Panel script retains its [upstream license](Vendor/control-panel-for-twitter/LICENSE) and [additional notice](Vendor/control-panel-for-twitter/NOTICE). This is an unofficial client; the code license does not grant rights to Twitter/X branding.
