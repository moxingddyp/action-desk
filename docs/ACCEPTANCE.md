# Action Desk Environment and Verification

[English](ACCEPTANCE.md) · [简体中文](ACCEPTANCE.zh-CN.md)

An independent Release build, local signature verification, and native offline tests were completed on macOS 27.0.1 with Apple Silicon and Xcode 27.1.

Checks cover stable item IDs, mutually exclusive categories, duplicate and invalid data, 4,000 preference-state transitions, hit regions and colour adjacency for 1–34 ring segments, item expansion and selection, dates, and calendar logic. The example plan contains four fictional items and two fictional calendar entries; eight native previews were also generated.

The source distribution has not completed a full WidgetKit installation, permission, and real-navigation test under a separate new user account. Unverified systems and hardware are not listed as verified support.

Builds use local ad-hoc signing. Developer ID signing, notarization, and App Store distribution are not provided. Users prepare their own environment and choose how to install.
