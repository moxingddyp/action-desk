#!/bin/sh
set -eu
case "${1:-}" in
 --help) printf '%s\n' 'Usage: sh native/build.sh [--help]' 'ACTION_DESK_BUILD_DIR overrides /tmp/CXY-Workbench-OSS-Build; builds/signs only, never installs or launches.'; exit 0 ;;
 '') ;;
 *) printf '%s\n' 'Unknown option' >&2; exit 2 ;;
esac
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache=${ACTION_DESK_BUILD_DIR:-"/tmp/CXY-Workbench-OSS-Build"}
app="$cache/CXY Workbench OSS.app"
if [ -z "${DEVELOPER_DIR:-}" ]; then
 DEVELOPER_DIR=$(/usr/bin/xcode-select -p)
 export DEVELOPER_DIR
fi
/usr/bin/xcrun xcodebuild -quiet -project "$source_dir/CXYActionDesk.xcodeproj" -scheme CXYActionDesk -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$cache/DerivedData" CODE_SIGNING_ALLOWED=NO build
/usr/bin/ditto "$cache/DerivedData/Build/Products/Release/CXY Workbench OSS.app" "$app"
# Rebuild color icon from editable SwiftUI vector source when needed.
icon_source="$source_dir/Assets/WorkbenchIcon.swift"
icon_asset="$source_dir/Assets/Workbench.icns"
if [ ! -f "$icon_asset" ] || [ "$icon_source" -nt "$icon_asset" ]; then
    /usr/bin/xcrun swiftc -parse-as-library "$icon_source" -o "$cache/WorkbenchIconGenerator"
    "$cache/WorkbenchIconGenerator" "$cache/Workbench.iconset"
    /usr/bin/xcrun iconutil -c icns "$cache/Workbench.iconset" -o "$icon_asset"
fi
mkdir -p "$app/Contents/Resources"
/usr/bin/ditto "$icon_asset" "$app/Contents/Resources/Workbench.icns"
# Removed SSH resources are not part of the unified client. Linux owns sampling.
rm -f "$app/Contents/Resources/windows.ps1" "$app/Contents/Resources/linux.py"
action_extension="$app/Contents/PlugIns/CXYActionWidget.appex"
device_extension="$app/Contents/PlugIns/CXYDeviceWidget.appex"
test -f "$action_extension/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -f "$device_extension/Contents/Resources/Metadata.appintents/extract.actionsdata"
/usr/bin/strip -S "$app/Contents/MacOS/CXYActionDesk"
/usr/bin/strip -S "$action_extension/Contents/MacOS/CXYActionWidget"
/usr/bin/strip -S "$device_extension/Contents/MacOS/CXYDeviceWidget"
/usr/bin/codesign --force --sign - --identifier local.cxy.actiondesk.opensource.widget --entitlements "$source_dir/Widget.entitlements" "$action_extension"
/usr/bin/codesign --force --sign - --identifier local.cxy.actiondesk.opensource.deviceswidget --entitlements "$source_dir/DeviceWidget.entitlements" "$device_extension"
/usr/bin/codesign --force --sign - --identifier local.cxy.actiondesk.opensource "$app"
/usr/bin/codesign --verify --deep --strict "$app"
