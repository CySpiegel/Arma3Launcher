#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
EVIDENCE="$PWD/.build/evidence/M0-001-A6-worker"
mkdir -p "$EVIDENCE" .build/DerivedData
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"

python3 scripts/verify_repo.py --line-output "$EVIDENCE/line-count.log" 2>&1 \
  | tee "$EVIDENCE/repo-verify.log"
python3 scripts/gate_self_test.py 2>&1 | tee "$EVIDENCE/gate-self-test.log"

xcrun swift-format lint --strict --recursive Package.swift Sources Tests App 2>&1 \
  | tee "$EVIDENCE/swift-format.log"
swift test --disable-sandbox --scratch-path .build/swiftpm -Xswiftc -warnings-as-errors 2>&1 \
  | tee "$EVIDENCE/swift-test.log"
xcodebuild -project Arma3Launcher.xcodeproj -scheme Arma3Launcher -configuration Debug \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  build 2>&1 | tee "$EVIDENCE/xcode-build.log"

python3 scripts/verify_repo.py --manifest-output "$EVIDENCE/source-sha256.txt"

echo "Gate passed"
