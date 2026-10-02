#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command="${1:?Pass a SwiftPM command such as build or test}"
shift
build_root="${SECOND_EARTH_BUILD_ROOT:-$PWD/.build}"
mkdir -p "$build_root/clang-cache" "$build_root/cache" "$build_root/config" "$build_root/security"
export CLANG_MODULE_CACHE_PATH="$build_root/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_root/clang-cache"
options=(--disable-sandbox --scratch-path "$build_root/artifacts" --cache-path "$build_root/cache" --config-path "$build_root/config" --security-path "$build_root/security")
if [[ "$command" == "test" ]]; then
    options+=(--disable-xctest)
    developer_path="$(xcode-select -p)"
    frameworks="$developer_path/Library/Developer/Frameworks"
    if [[ -d "$frameworks/Testing.framework" ]]; then
        options+=(-Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
        # Some Command Line Tools releases ship the Testing cross-import declaration
        # without its Foundation overlay module. These tests need no overlay features.
        if [[ ! -d "$frameworks/_Testing_Foundation.framework/Modules" ]]; then
            options+=(-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays)
        fi
    fi
fi
exec swift "$command" "${options[@]}" "$@"
