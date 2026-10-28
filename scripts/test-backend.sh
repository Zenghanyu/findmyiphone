#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
task_python="${EASYFIND_TEST_PYTHON:-$task_root/server/.venv/bin/python}"
task_run_dir="$(mktemp -d /tmp/easyfind-integration.XXXXXX)"
task_api_pid=""
task_output=""
cleanup() {
    if [[ -n "$task_api_pid" ]]; then kill "$task_api_pid" 2>/dev/null || true; wait "$task_api_pid" 2>/dev/null || true; fi
    if [[ -n "$task_output" && -f "$task_run_dir/api.log" ]]; then cp "$task_run_dir/api.log" "$task_output/api.log"; fi
    rm -rf "$task_run_dir"
}
trap cleanup EXIT

"$task_python" -m pytest server/tests -q
"$task_python" -m ruff check server
"$task_python" -m ruff format --check server
swift test --package-path ios/EasyFindCore
clang++ -std=c++11 -Wall -Wextra -Werror -I firmware/EasyFind-XIAO/include firmware/EasyFind-XIAO/tests/protocol_test.cpp -o "$task_run_dir/protocol"
"$task_run_dir/protocol"
clang++ -std=c++11 -Wall -Wextra -Werror -I firmware/EasyFind-XIAO/include firmware/EasyFind-XIAO/tests/find_delivery_test.cpp -o "$task_run_dir/delivery"
"$task_run_dir/delivery"
xcrun swiftc -parse-as-library ios/EasyFind/Sources/SelfieStick/SelfieStickProtocol.swift ios/EasyFind/Sources/SelfieStick/PhoneFindDelivery.swift ios/EasyFind/Tests/PhoneFindDeliveryTests.swift -o "$task_run_dir/phone-find"
"$task_run_dir/phone-find"
clang -std=c11 -Wall -Wextra -Werror -I ios/Vendor/BrushSDK/Support/ImageDither ios/Vendor/BrushSDK/Tests/image_core_test.c ios/Vendor/BrushSDK/Support/ImageDither/XTPhotoResampleCore.c ios/Vendor/BrushSDK/Support/ImageDither/XTInkPhotoCore.c -lm -o "$task_run_dir/image-core"
"$task_run_dir/image-core"

if [[ "${EASYFIND_SKIP_UI:-0}" == 1 ]]; then exit 0; fi
task_simulator="${EASYFIND_SIMULATOR_ID:-$(xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; ds=[d for v in json.load(sys.stdin)["devices"].values() for d in v if "iPhone" in d["name"]]; print(next((d["udid"] for d in ds if d["state"]=="Booted"),ds[0]["udid"] if ds else ""))')}"
if [[ -z "$task_simulator" ]]; then printf '%s\n' 'No iPhone simulator is installed.'; exit 1; fi
if ! xcrun simctl list devices booted | rg -q "$task_simulator"; then xcrun simctl boot "$task_simulator"; fi
xcrun simctl bootstatus "$task_simulator" -b
"$task_python" - <<'PY'
import socket
with socket.socket() as probe:
    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    probe.bind(("127.0.0.1", 8001))
PY
(
    cd server
    EASYFIND_TEST_DATA_DIR="$task_run_dir/api-data" exec "$task_python" -m uvicorn tests.live_fixture:fixture_app --factory --host 127.0.0.1 --port 8001 > "$task_run_dir/api.log" 2>&1
) &
task_api_pid=$!
if ! "$task_python" - <<'PY'
import time, urllib.request
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
for _ in range(100):
    try:
        opener.open('http://127.0.0.1:8001/health', timeout=1).close()
        break
    except OSError:
        time.sleep(.1)
else:
    raise SystemExit('HTTP integration fixture failed to start')
PY
then
    cat "$task_run_dir/api.log"
    exit 1
fi
task_output="$task_root/outputs/backend-tests-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$task_output"
task_build_dir="${EASYFIND_DERIVED_DATA:-/tmp/easyfind-backend-build}"
xcodebuild -project ios/EasyFindPrototype/EasyFind.xcodeproj -scheme EasyFind -sdk iphonesimulator -destination "id=$task_simulator" -derivedDataPath "$task_build_dir" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build > "$task_output/build.log" 2>&1
xcrun simctl install "$task_simulator" "$task_build_dir/Build/Products/Debug-iphonesimulator/EasyFind.app"
task_test_filter=("-only-testing:ButtonReview")
if [[ -n "${EASYFIND_UI_TEST:-}" ]]; then task_test_filter=("-only-testing:ButtonReview/ButtonReview/$EASYFIND_UI_TEST"); fi
xcodebuild -project ios/EasyFindPrototype/UIReview/ButtonReview.xcodeproj -scheme ButtonReview -destination "id=$task_simulator" -derivedDataPath "${EASYFIND_UI_DERIVED_DATA:-/tmp/easyfind-backend-ui-tests}" -resultBundlePath "$task_output/ui.xcresult" -parallel-testing-enabled NO -collect-test-diagnostics never "${task_test_filter[@]}" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$task_output/ui.log" 2>&1
printf 'Backend validation passed. Results: %s\n' "$task_output"
