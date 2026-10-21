# Action Desk | A Native macOS Desktop Widget for Codex

[English](README.md) · [简体中文](README.zh-CN.md)

Keep your existing work plan on your macOS desktop, then open the corresponding Codex thread directly from an item.

Action Desk provides ring, list, and calendar views. It reads your Markdown work plan instead of creating another task database.

## Features

- A native WidgetKit desktop widget.
- Colourful rings with up to two layers and two-digit project labels.
- Click a segment to expand an item, click it again to collapse it, or select another segment to switch items.
- Switch between ring and list views.
- A calendar for scheduled activities.
- Open an item's Codex thread from its details, or open your configured main thread from the centre of the ring.
- Categories, deduplicated totals, and calendar entries generated from the same source.

The categories are Priority, In Progress, Ready, and Conditional. The last three are mutually exclusive; Priority is an additional flag.

## Environment

The project has been built and tested offline with:

- An Apple Silicon Mac.
- macOS 27.0.1.
- Xcode 27.1.
- A deployment target of macOS 27.0, arm64.

Other operating systems, Intel Macs, and Xcode versions have not been verified. Users are responsible for preparing their own environment.

## Build

Complete Xcode's first launch and install its macOS development components. From the repository root, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer sh native/build.sh
```

The output is `CXY Action Desk OSS.app`. The script builds and locally signs the application; it does not install or launch it.

This is a source distribution. A Developer ID–signed and Apple-notarized installer is not currently provided.

## Configure and Use

1. Copy the example work plan, project index, and thread mapping from `examples/` into your own data directory.
2. Configure the data directory and your main Codex thread ID in `~/Library/Application Support/CXY Action Desk OSS/config.json`.
3. Replace the example thread IDs with Codex threads you can access.
4. Install and open the application you built.
5. Add “CXY行动台OSS” through macOS Edit Widgets.

Items without a mapped work thread fall back to the main thread. Example thread IDs are blocked from actual navigation.

The host checks the source every 60 seconds. You can also request a refresh from its menu or run:

```sh
open 'cxy-actiondesk-oss://refresh'
```

WidgetKit controls when the widget is actually refreshed.

## Data and Integration Boundaries

Progress remains in the source Markdown files. The application stores only display caches and view preferences; it does not change task status.

This project does not include email, WeChat, recording intake, model calls, or background agents. It does not automatically read Codex conversations.

The process maintaining your work plan is responsible for the 48-hour In Progress rule. Action Desk displays the categories already present in that plan.

The current interface and parts of the input format use Chinese. English documentation does not imply an English-localized interface or input format.

## Tests

```sh
sh tests/run.sh --check-only
```

Completed checks include an independent Release build, signature verification, data projection, categories, ring hit regions, view switching, and calendar logic.

A complete first-time WidgetKit installation, permission, and real-thread navigation test under a separate user account has not been completed for this source distribution. All examples and previews use fictional data.

## Documentation

- [Data format](docs/DATA-FORMAT.md)
- [Environment and verification](docs/ACCEPTANCE.md)
- [Components](THIRD-PARTY.md)
- [Privacy and licensing](docs/PRIVACY-AND-LICENSING.md)

## License

Original project code is licensed under [MIT](LICENSE).

Author: [moxingddyp](https://github.com/moxingddyp).

Third-party frameworks and tools retain their own licenses. Action Desk is an independent project, not an official OpenAI or Apple product.
