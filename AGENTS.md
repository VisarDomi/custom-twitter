# Custom Twitter

Read README.md before editing. Source lives here; Xcode builds run on macOS.

- Keep personal settings in ignored `twitter.local.json`; never commit signing keys, profiles, device data, or build products.
- Preserve an existing installation's configured bundle ID. Install updates in place; do not uninstall to update.
- Keep the app's behavior, WebKit session restoration, and Control Panel overrides unless the requested change concerns them.
- Keep upstream LICENSE, NOTICE, and VERSION alongside the vendored script. `build.py` checks its settings-injection contract.
- `ios-tools` renewal is optional. Retain the shared signing lock and inherited descriptor when using it. A changed approved input needs deliberate build/install/approval.
- A direct Xcode build does not need `ios-tools`, a Linux server, a developer API token, or another person's Apple account.
- Run `python3 -m unittest discover -s tests` for deployment policy checks. Verify native compilation on a Mac when changing the project or Swift source.
- This target is iPhone-only. Do not claim verified iPad layouts from successful signing alone.
