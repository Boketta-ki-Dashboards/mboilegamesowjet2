#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
xcrun swiftc Mikrorayon77/GameState.swift Tests/main.swift -o "$work_dir/model-tests"
"$work_dir/model-tests"
xcodebuild -project Mikrorayon77.xcodeproj -scheme Mikrorayon77 -sdk iphonesimulator -configuration Debug -derivedDataPath "$work_dir/build" CODE_SIGNING_ALLOWED=NO build
