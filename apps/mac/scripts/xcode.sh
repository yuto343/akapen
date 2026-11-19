#!/bin/bash
set -uo pipefail
mkdir -p build/logs
log="build/logs/${1}.log"
xcodebuild -project akapen.xcodeproj -scheme akapen -configuration Debug -derivedDataPath build/DerivedData "$@" >"$log" 2>&1
status=$?
if [ "$status" -eq 0 ]; then
  tail -n 3 "$log"
else
  rg -n -A 4 'error:|failed|Error|warning:' "$log" | tail -n 100
fi
printf 'Log: %s\n' "$log"
exit "$status"
