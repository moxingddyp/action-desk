# Action Desk Environment and Verification

[English](ACCEPTANCE.md) · [简体中文](ACCEPTANCE.zh-CN.md)

An independent Release build, local signature verification, and native offline tests were completed on macOS 27.0.1 with Apple Silicon and Xcode 27.1.

Checks cover stable item IDs, mutually exclusive categories, duplicate and invalid data, 4,000 preference-state transitions, hit regions and colour adjacency for 1–34 ring segments, item expansion and selection, dates, and calendar logic. The example plan contains four fictional items and two fictional calendar entries; eight native previews were also generated.

The source distribution has not completed a full WidgetKit installation, permission, and real-navigation test under a separate new user account. Unverified systems and hardware are not listed as verified support.

Local DMG and ZIP review packages for 1.0.1 (build 16) contain the app, widget extension, multi-size app icon, fictional examples, and bilingual installation instructions. The app in each read-only mounted/extracted container matches the build file by file; signature integrity and container checks passed. Local debug-map paths were removed from the binaries, and targeted private-information/credential scans found no matches. The app depends on macOS system frameworks, not an end-user Xcode installation.

The build is ad-hoc signed, not Developer ID–signed, notarized, or distributed through the App Store. Local Gatekeeper assessment explicitly rejects this review build; it has not passed default security acceptance. Signature integrity is not Apple verification of the developer's identity. Internet download, installation, first launch, and WidgetKit loading on another Mac have not been verified. The user approved publishing these packages as version 1.0.1 with these limitations disclosed. End-user installation and developer source builds are documented separately.
