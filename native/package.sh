#!/bin/sh
set -eu
case "${1:-}" in
  --help) printf '%s\n' 'Usage: sh native/package.sh APP_PATH OUTPUT_DIRECTORY' 'Packages an existing app; never installs, launches, notarizes, or uploads it.'; exit 0 ;;
esac
app=${1:?Pass the compiled .app path}
out=${2:?Pass a new output directory}
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -d "$app/Contents/PlugIns/CXYActionWidget.appex"
/usr/bin/codesign --verify --deep --strict "$app"
test ! -e "$out"
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/actiondesk-package.XXXXXX")
/usr/bin/ditto --norsrc "$app" "$stage/CXY Action Desk OSS.app"
/usr/bin/ditto "$repo/examples" "$stage/Example Work Plan"
cp "$repo/docs/INSTALL.md" "$stage/INSTALL-English.md"
cp "$repo/docs/INSTALL.zh-CN.md" "$stage/安装说明-简体中文.md"
cp "$repo/LICENSE" "$stage/LICENSE"
ln -s /Applications "$stage/Applications"
/usr/bin/codesign --verify --deep --strict "$stage/CXY Action Desk OSS.app"
/usr/bin/hdiutil create -quiet -volname 'Action Desk 1.0.1' -srcfolder "$stage" -fs HFS+ -format UDZO "$out/Action-Desk-1.0.1-macOS-arm64.dmg"
# ZIP includes the same app and documentation, but no Applications alias.
zipstage=$(mktemp -d "${TMPDIR:-/tmp}/actiondesk-zip.XXXXXX")
/usr/bin/ditto --norsrc "$stage/CXY Action Desk OSS.app" "$zipstage/Action Desk/CXY Action Desk OSS.app"
/usr/bin/ditto "$stage/Example Work Plan" "$zipstage/Action Desk/Example Work Plan"
cp "$stage/INSTALL-English.md" "$stage/安装说明-简体中文.md" "$stage/LICENSE" "$zipstage/Action Desk/"
/usr/bin/ditto -c -k --norsrc --keepParent "$zipstage/Action Desk" "$out/Action-Desk-1.0.1-macOS-arm64.zip"
(cd "$out" && /usr/bin/shasum -a 256 Action-Desk-1.0.1-macOS-arm64.dmg Action-Desk-1.0.1-macOS-arm64.zip > SHA256SUMS.txt)
printf 'Local packages only, not installed or uploaded: %s\n' "$out"
