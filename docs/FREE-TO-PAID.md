# Free Apple Account first, paid signing later

Use this path when you have a Linux PC, a fresh Mac/Hackintosh, and an iPhone on iOS 26. The Mac does not need to be signed into iCloud to build this app. Your own account belongs in Xcode; no original developer's Apple login, device identity, private key, or backend is required.

The first goal is one working app installed and opened on your phone. Add unattended renewal or other infrastructure only after that works.

## 1. Get the Mac ready

Verify the exact macOS, Xcode, and phone OS point versions. Use a full Xcode compatible with both the Mac OS and device support; see [Apple's compatibility table](https://developer.apple.com/xcode/system-requirements). Xcode 26.3 on Sequoia was the original working build host, but your own combination must be checked. Do not assume every iOS 26 point release works with every Xcode 26 version.

If Xcode is missing, obtain it from Apple, install it, and complete its license and component setup. Apple's download website sign-in is separate from signing into Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
```

If components/destinations remain unavailable, inspect Xcode's component/device UI. An SDK folder existing does not prove all device support is ready. A simulator download is not automatically required for an iPhone build.

For Linux access, enable Remote Login on the Mac, install your Linux public SSH key, and verify/pin the Mac's host-key fingerprint. Configure a trusted alias such as `ios-build`. Keep the normal macOS build user logged into the desktop. Do not copy another Mac's SSH pins, Keychain, or pairing records.

## 2. Use your free Personal Team

1. Open Xcode → Settings → Accounts and add **your own Apple Account**. Complete 2FA and any developer agreement.
2. Verify that its **Personal Team** appears. A paid membership is not required for this first device test.
3. Clone this repository on the Mac and open `Twitter.xcodeproj`.
4. Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig`. Fill in your Personal Team ID and a unique bundle ID such as `com.yourname.CustomTwitter`.
5. Keep automatic signing enabled. Let Xcode create the development identity/profile, including its private key in your login Keychain.

The local xcconfig is ignored by Git. The public `com.example.CustomTwitter` is a placeholder; choose your own identifier. Decide on that identity before your first real install, then preserve it during normal updates.

[Apple's current free-team rules](https://developer.apple.com/help/account/basics/about-your-developer-account) include seven-day provisioning and limits on App IDs/devices/apps. Free development apps are not permanent installations. Expect to rebuild/reinstall in place when needed; deleting the app is not the renewal procedure.

## 3. Pair and trust the phone

Connect the iPhone with a USB **data cable**, unlock it, and accept Trust prompts. Let Xcode prepare it. Enable Settings → Privacy & Security → **Developer Mode**, restart, and confirm after restart. This toggle may appear only after pairing is initiated. Follow [Apple's instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

Select the Twitter scheme and this physical phone in Xcode, then Run. Complete any Keychain access or developer-app trust prompt. Once it opens, sign into x.com **inside this app**. The original developer's Twitter session is not included.

If an app installed but cannot open, distinguish Developer Mode/trust, profile expiry/device authorization, and network verification. If the phone only charges and never appears in the Mac's USB devices, test another data cable/port.

Acceptance: the app builds, signs for your team/device, installs, launches, and displays the expected timeline controls. Try scrolling, sign-in, back/forward, and leaving/reopening the app. These are separate from merely seeing BUILD SUCCEEDED.

## 4. Move editing to Linux

Once the first Xcode install works, clone this repository on Linux too. Linux is the source of truth; the Mac is a build mirror. On Linux, copy `twitter.example.json` to ignored `twitter.local.json` and set:

- `host`: your verified SSH alias.
- `remoteRoot`: a dedicated absolute Mac path such as `/Users/YOUR_MAC_USER/Developer/custom-twitter`.
- `team`: your current **Personal Team** ID.
- `device`: your phone's hardware UDID, from Xcode/device tools.
- `bundleId`: the **same** identifier you just installed.
- `minimumProfileDays`: leave at `1` for fresh free-team profiles.
- `iosTools`: leave `null` while starting out.

The hardware UDID is different from a simulator UUID and can differ from CoreDevice's pairing identifier. Do not use a device ID from somebody else's setup.

Run on Linux:

```sh
python3 scripts/deploy.py sync build install
```

The helper sends source and minimal private build settings, builds attached in the Mac desktop user's session, verifies identity/profile/device authorization, then installs **over the same app** and launches it. It requires the documented noninteractive sudo setup for its GUI-session wrapper; otherwise continue building from the Mac's desktop until that setup is arranged. No password belongs in the configuration.

Keep the phone reachable and unlocked for installation. After initial USB pairing, test Xcode's network-device support if you want wireless deployment. On the original setup, a phone VPN sometimes hid the CoreDevice path; same-LAN deployment normally used the phone VPN off. A successful SSH connection to the Mac does not imply the Mac can reach the phone.

The app does not require `ios-tools`, a Linux HTTP server, a local CA, or an X API credential. Those appear in the larger workflow for other projects or optional maintenance; do not set them up just to get this app running.

## 5. Maintain the free installation

Rebuild and reinstall through Xcode or the same Linux helper before/after its profile expires. Preserve the bundle ID and update in place to retain the app container/session. Keep your account, signing private key, and phone pairing usable on the Mac.

Do **not** enable the shared monthly paid-renewal setup for a seven-day Personal Team profile. Its registrar and paid-profile checks assume a different validity policy. Free-tier app/device limits still apply even if a script can invoke a build.

If Xcode reports signing/account/device support failures, fix that layer first. Do not revoke unrelated certificates, wipe the Keychain, reset the phone, or uninstall the working app as a first response.

## 6. Switch to a paid team later

When you choose to enroll/join the Apple Developer Program, let the authorized account holder finish membership and agreements. Then:

1. Refresh Xcode Accounts and confirm the exact paid team and your signing/device-registration permissions.
2. Check whether your existing App ID and signing team permit an in-place transition. **Do not assume a different team can overwrite the existing app and preserve its data.** Personal/paid team identities can differ, especially when changing accounts or joining another organization.
3. Where authorized, retain the existing bundle ID; adding a `.paid` suffix is not an Apple requirement. If Apple requires a different identity or team migration, plan it explicitly. Expect a new installation/login when continuity cannot be preserved; keep the working free app until the replacement works.
4. Update `Config/Local.xcconfig` for direct Xcode use and `twitter.local.json` for Python/Linux builds with the intended paid team/identity. Keep them consistent.
5. Build/provision for the physical phone and inspect the actual profile/team/device membership and deadlines. A certificate file without its private key is insufficient.
6. Install, open, and verify the intended app. Paid development signing still has certificate/profile/membership expiry.
7. You can set `minimumProfileDays` to `45` once the actual paid profile supports it.

If the existing team/ID allows an ordinary update, install in place. If it does not, do not make the helper silently uninstall the old app to get past the error. Resolve the identity transition first.

## 7. Optional paid renewal

Only after the paid app is working, follow the README's optional integration with [ios-tools](https://github.com/VisarDomi/ios-tools). It fingerprints the deliberately deployed source and refuses unattended renewal after source changes until those changes are deployed/approved.

One repository owns the bundle. Run one real renewal, verify that every profile receives a later deadline **and** the phone installation completes, then enable its scheduler. The Mac must be awake/logged into the appropriate desktop session, and the phone directly reachable/unlocked when renewal runs. A published OTA link or a deferred check is not a completed renewal.

Membership/certificate maintenance is separate from profile renewal. The default helper and renewal registration track one primary phone; they are not a complete multi-device fleet system.

## What about an iPad?

Confirm whether you have one and its actual iPadOS version. Pair/trust/provision it independently, with its own hardware UDID. A profile built for one device does not automatically prove authorization for another.

The current target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`). Native iPad support needs deliberate target/layout/orientation and gesture/restoration testing. A working iPhone install does not establish tablet support, and changing only the target-family flag is not full iPad QA.

## Brief for your coding agent

> Read this guide and README.md. My Linux PC owns source, my fresh Mac/Hackintosh runs Xcode, and my iPhone is on iOS 26. Verify exact versions and SSH identity. First build Custom Twitter with my own free Personal Team and install/launch it on my phone. Batch Apple sign-in/2FA, USB Trust, Developer Mode restart, and Keychain/app-trust prompts after preparing the next steps. Choose my own bundle ID, keep credentials/local settings ignored, and preserve the app data during updates. Then make Linux sync/build/install reproduce the working Xcode path. Do not enable monthly paid renewal yet. Later, help me transition to my authorized paid team, explicitly checking App ID/team continuity before promising an in-place update. Treat a possible iPad as a separate unverified target.
