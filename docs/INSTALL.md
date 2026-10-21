# Download and Install Action Desk

[English](INSTALL.md) · [简体中文](INSTALL.zh-CN.md)

## Requirements

- An Apple Silicon Mac running macOS 27.0 or later; the local verification environment is macOS 27.0.1.
- No Xcode, Python, Homebrew, or command-line developer tools are required.
- Opening work threads requires Codex and an account authorized to access those threads.
- The interface and work-plan fields currently use Chinese. The app displays an existing Markdown plan; it does not create or maintain tasks automatically.

## Install the App

1. Download and open the DMG, then drag `CXY Action Desk OSS.app` into `Applications`. Alternatively, extract the ZIP and move its app into Applications. Do not run it directly from the disk image.
2. Open the installed app. It runs in the menu bar without a persistent main window; a four-square menu-bar icon indicates that it has started.
3. The current review build is ad-hoc signed, not Developer ID–signed or Apple-notarized. macOS may block its first launch after an internet download. If you trust the source and choose to proceed, follow Apple's instructions to select Open Anyway for this app in System Settings → Privacy & Security. Do not disable Gatekeeper or remove quarantine attributes.
4. A security block is not a successful installation. The complete internet-download, installation, and widget-loading flow on another Mac has not yet been verified.

## Configure Your Existing Plan

1. The included `Example Work Plan` contains fictional work plans, a project index, thread mappings, and `config.example.json`. Copy it to your own writable data directory first; do not overwrite an existing plan.
2. In Finder, press Shift–Command–G, open `~/Library/Application Support/`, and create a folder named `CXY Action Desk OSS`.
3. Copy `config.example.json` into that folder, rename it `config.json`, and edit it with a plain-text editor: set `sourceDirectory` to the absolute path of your plan directory and `chiefThread` to your main Codex thread UUID. Keep the JSON valid.
4. The plan directory must contain `PROJECT.md`, `PROJECTS.md`, and `tools/desktop-action-desk/thread-links.json`. Replace example UUIDs with threads you are authorized to access. Example UUIDs are blocked from actual navigation.
5. Choose Refresh Existing Plan (刷新现有安排) from the menu bar. Then right-click the desktop → Edit Widgets and add CXY行动台OSS. See the repository's bilingual Data Format documentation for the input schema.

The host checks source files every 60 seconds. WidgetKit schedules actual widget refreshes. The OSS edition uses separate app identifiers, configuration storage, and a URL scheme from the non-OSS edition; it does not read that edition's real work plan.

## Uninstall and Data

Quit the menu-bar app, remove its desktop widget, and move the OSS app to Trash. Your source directory is not deleted. Configuration, preferences, and display caches remain in `~/Library/Application Support/CXY Action Desk OSS/`; you decide whether to keep them.

Source: [Apple: Safely open apps on your Mac](https://support.apple.com/102445).
