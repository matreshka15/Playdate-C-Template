#!/usr/bin/env bash
# -------------------------------------------------
# Playdate C Game Build Script for macOS (bash)
# -------------------------------------------------
# Usage: ./build.sh [--clean] [--run] [--sdk-path <path>] [--name <name>]

set -e                     # Exit on any error
shopt -s nullglob          # Make globs expand to nothing if no match

VERSION="2.0.0"
START_TIME=$(date +%s)

# ---------- Helper: colour/emoji output ----------
RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6); MAGENTA=$(tput setaf 5); RESET=$(tput sgr0)

ICON_SUCCESS="[OK]"
ICON_ERROR="[FAIL]"
ICON_WARN="[WARN]"
ICON_INFO="[INFO]"
ICON_STEP="[STEP]"
ICON_BUILD="[BUILD]"
ICON_CLEAN="[CLEAN]"
ICON_LINK="[LINK]"
ICON_PLAY="[PLAY]"
ICON_CODE="[CODE]"

say() {
    local msg=$1; local col=$2; local icon=$3
    printf "%b%s %s%b\n" "$col" "$icon" "$msg" "$RESET"
}

# ---------- Parse arguments ----------
CLEAN=false
RUN=false
SDK_PATH=""
PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean) CLEAN=true; shift ;;
        --run)   RUN=true;   shift ;;
        --sdk-path) SDK_PATH="$2"; shift 2 ;;
        --name) PROJECT_NAME="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------- ASCII art ----------
cat <<'EOF'
      ___________
     |  _______  |  PLAYDATE C
     | |       | |  GAME BUILDER
     | |_______| |__
     |      @    |  | v2.0.0
     |   _    O  |
     | _| |_  O  |
     ||_   _|    |__| (C)ompile it!
     |  |_|      |
     |___________|
EOF

# ---------- Determine script directory ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Load optional JSON config ----------
CONFIG_FILE="${SCRIPT_DIR}/setup-config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    # jq must be installed; if not, fall back to defaults
    if command -v jq >/dev/null; then
        CONFIG_AUTHOR=$(jq -r '.author // empty' "$CONFIG_FILE")
        CONFIG_DESC=$(jq -r '.description // empty' "$CONFIG_FILE")
        CONFIG_BUNDLE=$(jq -r '.bundleID // empty' "$CONFIG_FILE")
        CONFIG_PROJECT=$(jq -r '.projectName // empty' "$CONFIG_FILE")
        CONFIG_VS_PATH=$(jq -r '.visualStudioPath // empty' "$CONFIG_FILE")
    fi
fi

# ---------- Resolve project name ----------
if [[ -z "$PROJECT_NAME" ]]; then
    if [[ -n "$CONFIG_PROJECT" ]]; then
        PROJECT_NAME="$CONFIG_PROJECT"
    else
        PROJECT_NAME="MyPlaydateGame"
    fi
fi

# ---------- Resolve SDK path ----------
resolve_sdk_path() {
    local provided="$1"
    if [[ -n "$provided" && -d "$provided" ]]; then return 0; fi
    if [[ -n "$PLAYDATE_SDK_PATH" && -d "$PLAYDATE_SDK_PATH" ]]; then
        SDK_PATH="$PLAYDATE_SDK_PATH"; return 0
    fi
    # Common locations on macOS
    local candidates=(
        "$HOME/Documents/PlaydateSDK"
        "$HOME/Documents/Playdate SDK"
        "/Applications/PlaydateSDK"
        "/usr/local/PlaydateSDK"
        "/opt/PlaydateSDK"
    )
    for p in "${candidates[@]}"; do
        if [[ -d "$p" ]]; then
            SDK_PATH="$p"; return 0
        fi
    done
    return 1
}
if ! resolve_sdk_path "$SDK_PATH"; then
    say "I can't find the Playdate SDK!" "$RED" "$ICON_ERROR"
    say "Set PLAYDATE_SDK_PATH env var or pass --sdk-path." "$CYAN" "$ICON_INFO"
    exit 1
fi
say "SDK found at $SDK_PATH" "$GREEN" "$ICON_SUCCESS"

# ---------- Verify clang (Xcode command line tools) ----------
if ! command -v clang >/dev/null; then
    say "Clang not found! Install Xcode Command Line Tools (xcode-select --install)." "$RED" "$ICON_ERROR"
    exit 1
fi
say "Clang compiler detected" "$GREEN" "$ICON_SUCCESS"

# ---------- Optional clean ----------
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
if $CLEAN; then
    say "Cleaning previous build artifacts…" "$YELLOW" "$ICON_CLEAN"
    rm -rf "$BUILD_DIR"
    rm -rf "${OUTPUT_DIR}/${PROJECT_NAME}.pdx"
fi

# ---------- Compile ----------
mkdir -p "$BUILD_DIR"
SRC_FILES=("${SCRIPT_DIR}/src"/*.c)
if (( ${#SRC_FILES[@]} == 0 )); then
    say "No .c files found in src/!" "$RED" "$ICON_ERROR"
    exit 1
fi
say "Compiling ${#SRC_FILES[@]} source file(s)…" "$CYAN" "$ICON_CODE"

INCLUDE="-I${SDK_PATH}/C_API"
DEFINES="-DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -DTARGET_SIMULATOR=1 -D_WINDLL"
CFLAGS="-c -Wall -Wextra -g -O0 -MD -MP -fdeclspec $DEFINES $INCLUDE"

for src in "${SRC_FILES[@]}"; do
    obj="${BUILD_DIR}/$(basename "${src%.*}").o"
    clang $CFLAGS "$src" -o "$obj"
done
say "Compilation finished." "$GREEN" "$ICON_SUCCESS"

# ---------- Link ----------
say "Linking into shared library…" "$CYAN" "$ICON_LINK"
OBJ_FILES=("$BUILD_DIR"/*.o)
LIB_PATH="${BUILD_DIR}/pdex.dylib"
clang -dynamiclib -o "$LIB_PATH" "${OBJ_FILES[@]}" -framework CoreFoundation
say "Library created at $LIB_PATH" "$GREEN" "$ICON_SUCCESS"

# ---------- Package with pdc ----------
PDC="${SDK_PATH}/bin/pdc"
if [[ ! -x "$PDC" ]]; then
    say "pdc executable not found at $PDC" "$RED" "$ICON_ERROR"
    exit 1
fi

TMP_DIR="${BUILD_DIR}/temp_game"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cp "$LIB_PATH" "$TMP_DIR/pdex.dylib"

# Metadata (fallback defaults if config missing)
AUTHOR="${CONFIG_AUTHOR:-Developer}"
DESCRIPTION="${CONFIG_DESC:-My Playdate Game}"
BUNDLE_ID="${CONFIG_BUNDLE:-com.example.${PROJECT_NAME}}"

cat > "$TMP_DIR/pdxinfo" <<EOF
name=${PROJECT_NAME}
author=${AUTHOR}
description=${DESCRIPTION}
bundleID=${BUNDLE_ID}
version=1.0.0
buildNumber=1
EOF

OUTPUT_PDX="${OUTPUT_DIR}/${PROJECT_NAME}.pdx"
"$PDC" "$TMP_DIR" "$OUTPUT_PDX"
pdc_exit=$?


# First, look at the return code
if (( pdc_status != 0 )); then
    say "pdc exited with code $pdc_status (may be a warning)." "$YELLOW" "$ICON_WARN"
fi

# Then verify the file exists (absolute path)
if [[ -d "$OUTPUT_PDX" ]]; then
    say "Package created: $OUTPUT_PDX" "$GREEN" "$ICON_SUCCESS"
fi
say "Package created: $OUTPUT_PDX" "$GREEN" "$ICON_SUCCESS"

# ---------- Optional run ----------
if $RUN; then
    # The simulator is a macOS .app bundle located in the SDK's bin folder.
    # We launch the bundle with `open -a` so the OS handles all the
    # resources, frameworks, and environment variables correctly.
    SIMULATOR_APP="${SDK_PATH}/bin/Playdate Simulator.app"

    if [[ -d "$SIMULATOR_APP" ]]; then
        say "Launching Playdate Simulator…" "$CYAN" "$ICON_PLAY"
        # Open the .app and pass the .pdx file as an argument.
        # The `--args` marker tells `open` to forward everything after it
        # to the launched application.
        open -a "$SIMULATOR_APP" --args "$OUTPUT_PDX" &
    else
        say "Simulator not found at $SIMULATOR_APP" "$RED" "$ICON_ERROR"
        exit 1
    fi
else
    say "Build complete! Run with '--run' to launch the simulator." "$GREEN" "$ICON_SUCCESS"
fi

# ---------- Timing ----------
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
printf "%bTotal time: %02d:%02d%b\n" "$MAGENTA" $((ELAPSED/60)) $((ELAPSED%60)) "$RESET"