# CXY Workbench OSS

[English](README.md) · [简体中文](README.zh-CN.md)

Native macOS and Android clients for a Markdown work plan, device telemetry, and a shared information feed. This updates the original Action Desk repository to the unified workbench.

## Download

[Release v2.2.0](https://github.com/moxingddyp/action-desk/releases/tag/v2.2.0) includes an Apple Silicon macOS DMG/ZIP, Android APK, source bundle and SHA256 checksums. macOS requires 27.0 or later; Android requires 11 or later. Mac binaries are ad-hoc signed and are not notarized. Separate-machine installation has not been tested for this release.

The macOS public app uses its own bundle IDs, `cxy-actiondesk-oss` / `cxy-devices-oss` URL schemes and OSS caches. It can coexist with a private installation. Android uses `com.cxy.workbench`; check the signing notes in [Android setup](android/README.md) before installing over another build.

## Features

- A unified desktop window: actions, device cards, and a four-category information reader.
- Ring/list/calendar views from one Markdown source, with optional navigation to your own Codex chats.
- Independent macOS widgets for Mac, Windows, Linux, phone, and gateway.
- Android device overview, themes, actions/calendar, information reader, widgets and explicit system-confirmed updates.
- Optional role-authenticated Linux API; unavailable hardware or network evidence stays unavailable rather than becoming a fabricated reading.

## Configure

Follow [installation](docs/INSTALL.md). To use the local work plan, copy `examples/` to your own directory. Create `~/Library/Application Support/CXY Action Desk OSS/config.json` with your source directory and main Codex thread UUID. Fictional UUIDs in the examples cannot open a real chat.

For shared telemetry/information, deploy the optional [service](service/README.md), then create a local `client.json` in the same macOS support directory. Import a phone-only connection file on Android. Connection examples contain placeholders; generate your own role tokens and never commit them. HTTPS is supported; unencrypted HTTP is limited to loopback or your encrypted tailnet address (100.64.0.0/10). Do not expose the service to the public internet.

The information page consumes the `/v1/information` JSON API. Your own collector publishes the report; this distribution does not contain private source subscriptions, account sessions, scheduled model agents, or an information archive.

## Build and test

On Apple Silicon with Xcode 27.1 and macOS 27:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh native/build.sh
sh tests/run.sh --check-only
sh native/package.sh /tmp/CXY-Workbench-OSS-Build/CXY\ Workbench\ OSS.app /tmp/workbench-packages
```

These scripts build/package only. They never install or launch the application. See `android/README.md` for Android builds and `service/README.md` for service tests.

## Upgrade from 1.0.1

The macOS public bundle ID and action cache are retained. Quit the old public app, replace it with the new one, keep your `config.json`, and reselect/add widgets if macOS requests it. The application is now named CXY Workbench OSS; device widgets use a separate OSS cache. Optional cross-device features require your own service configuration. The release does not migrate private installations or change any network settings.

See [changelog](CHANGELOG.md), [data format](docs/DATA-FORMAT.md), [verification](docs/ACCEPTANCE.md), [privacy](docs/PRIVACY-AND-LICENSING.md) and [components](THIRD-PARTY.md).

## License

Original code: [MIT](LICENSE). Author: [moxingddyp](https://github.com/moxingddyp). Apple/Android tools retain their licenses. This is an independent project, not an official Apple, Google, or OpenAI product.

For an existing public installation, `native/install-workbench.py` provides validation, backup, and targeted stale-widget reconciliation; use `--help` and review the dry run before `--apply`. It only targets the public OSS application.
