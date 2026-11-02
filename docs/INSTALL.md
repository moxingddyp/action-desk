# Installation and configuration

1. Download the platform package from Releases and verify SHA256SUMS.txt.
2. Move CXY Workbench OSS.app into Applications. It is ad-hoc signed and not notarized. If macOS blocks opening, follow Apple's official System Settings procedure; do not disable system security.
3. Copy the repository examples into your own data directory and replace fictional work items/thread mappings.
4. Set `sourceDirectory` and `chiefThread` in `~/Library/Application Support/CXY Action Desk OSS/config.json`; see examples/config.example.json.
5. Open the application and add the desired macOS widgets. WidgetKit controls actual refresh scheduling.
6. For cross-device features, deploy service/README.md and create client.json in the same support directory. Distribute only phone-role credentials to a phone.

To upgrade, quit the old public app, replace it and preserve configuration/caches. First installation on another Mac, old-extension replacement, and actual chat navigation need verification in that environment. Android setup is in ../android/README.md.

Apple opening guidance: https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac
