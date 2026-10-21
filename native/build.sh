#!/bin/sh
set -eu
case "${1:-}" in
  --help) printf '%s\n' 'Usage: sh native/build.sh [--help]' 'Environment: ACTION_DESK_BUILD_DIR (output directory), DEVELOPER_DIR (Xcode developer directory)' 'Builds and locally signs only; never installs, launches, or registers login items.'; exit 0 ;;
  '') ;;
  *) printf '%s\n' 'Unknown option' >&2; exit 2 ;;
esac
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache=${ACTION_DESK_BUILD_DIR:-"${TMPDIR:-/tmp}/CXY-Action-Desk-OSS-Build"}
case "$cache" in /*) ;; *) cache="$PWD/$cache" ;; esac
app="$cache/CXY Action Desk OSS.app"
extension="$app/Contents/PlugIns/CXYActionWidget.appex"
if [ -z "${DEVELOPER_DIR:-}" ]; then
  DEVELOPER_DIR=$(/usr/bin/xcode-select -p)
  export DEVELOPER_DIR
fi
/usr/bin/xcrun xcodebuild -quiet -project "$source_dir/CXYActionDesk.xcodeproj" -scheme CXYActionDesk -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$cache/DerivedData" CODE_SIGNING_ALLOWED=NO build
/usr/bin/ditto "$cache/DerivedData/Build/Products/Release/CXY Action Desk OSS.app" "$app"
test -f "$extension/Contents/Resources/Metadata.appintents/extract.actionsdata"
/usr/bin/codesign --force --sign - --identifier local.cxy.actiondesk.opensource.widget --entitlements "$source_dir/Widget.entitlements" "$extension"
/usr/bin/codesign --force --sign - --identifier local.cxy.actiondesk.opensource "$app"
/usr/bin/codesign --verify --deep --strict "$app"
printf 'Build only; not installed or launched: %s\n' "$app"
