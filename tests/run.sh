#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "${1:---check-only}" in
  --check-only) preview='' ;;
  --preview) preview=${2:?Pass an output directory} ;;
  --help) printf '%s\n' 'Usage: sh tests/run.sh [--check-only | --preview OUTPUT_DIRECTORY]'; exit 0 ;;
  *) printf '%s\n' 'Unknown option' >&2; exit 2 ;;
esac
build=$(mktemp -d "${TMPDIR:-/tmp}/actiondesk-oss-tests.XXXXXX")
export ACTION_DESK_SOURCE="$repo/examples"
# Generated standalone test translation unit: remove extension entry point only.
sed '/^@main$/d' "$repo/native/Widget.swift" > "$build/Widget.swift"
xcrun swiftc -O -parse-as-library "$repo/native/Shared.swift" "$repo/native/Projection.swift" "$repo/native/ProjectionChecks.swift" -o "$build/projection-checks"
"$build/projection-checks"
xcrun swiftc -O -parse-as-library "$repo/native/Shared.swift" "$repo/native/Projection.swift" "$repo/native/RingColors.swift" "$repo/native/RingHitMap.swift" "$repo/native/CalendarView.swift" "$repo/native/DisplayIntent.swift" "$build/Widget.swift" "$repo/native/Preview.swift" -o "$build/layout-checks"
"$build/layout-checks" --check-only
if [ -n "$preview" ]; then "$build/layout-checks" "$preview"; fi
printf 'PASS: no installed application was launched or changed; test binaries: %s\n' "$build"
