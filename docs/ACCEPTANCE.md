# Verification scope

The public release is built independently on Apple Silicon, macOS 27.0.1 and Xcode 27.1. Checks cover the Mac host/two extension signatures, matching versions and AppIntents metadata; read-only Markdown projection, categories, ring hit regions, selection and calendar; configured origin restrictions; telemetry staleness and optional fields. Service tests use synthetic fixtures and a local loopback instance. Android build/model checks are described in android/README.md.

Source and distributable contents are scanned for private identities/paths/network configuration and secret signatures. Remote commit/tag and downloaded release hashes must match reviewed artifacts. Pattern scanning is not a proof of every possible unknown secret being absent.

Not repeated for the public configuration: first installation/WidgetKit loading on another Mac, real chat navigation, complete multi-device service setup, Android real-phone upgrade, long-running background/collector behavior and real network-path observation. Fictional fixtures do not establish these results. Builds/releases do not install over the user's software, restart current services, or change networking.
