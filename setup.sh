#!/usr/bin/env bash
# -------------------------------------------------
# Playdate C Project Setup Wizard – macOS (bash)
# -------------------------------------------------
# Usage:
#   ./setup.sh [--mode <interactive|check|env|build|repair|vscode|silent>]
#
#   interactive – full wizard (default)
#   check       – only system‑health check
#   env         – only environment‑variable fix
#   build       – build the demo game (asks to run)
#   repair      – run all checks + auto‑fix where possible
#   vscode      – configure / launch VS Code
#   silent      – non‑interactive, exit on first error
#
# -------------------------------------------------

set -e                      # abort on any error
shopt -s nullglob           # globs that match nothing expand to nothing

# -------------------- Global constants --------------------
VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="${SCRIPT_DIR}/build.sh"
LOG_FILE="${SCRIPT_DIR}/setup.log"

# -------------------- Colour helpers --------------------
RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6); MAGENTA=$(tput setaf 5); RESET=$(tput sgr0)

# Icons (simple text, feel free to change)
ICON_OK="[OK]"; ICON_ERR="[FAIL]"; ICON_WARN="[WARN]"
ICON_INFO="[INFO]"; ICON_STEP="[STEP]"; ICON_ARROW="->"
ICON_PLAY="[PLAY]"; ICON_CODE="[CODE]"; ICON_SETUP="[SET]"

say() {
    # $1 = message, $2 = colour variable name, $3 = icon (optional)
    local msg=$1 col=${2:-GREEN} icon=${3:-$ICON_INFO}
    printf "%b%s %s%b\n" "${!col}" "$icon" "$msg" "$RESET"
}

press_any_key() {
    read -n1 -rsp $'Press any key to continue...\n'
}

open_browser() {
    local url=$1
    if [[ "$MODE" != "silent" ]]; then
        read -p "Open browser to $url? [Y/n] " ans
        ans=${ans:-Y}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            open "$url"
        fi
    fi
}

confirm() {
    # $1 = prompt, $2 = default (yes/no)
    local prompt=$1 default=$2 ans
    if [[ "$MODE" == "silent" ]]; then
        [[ "$default" == "yes" ]]
        return
    fi
    read -p "$prompt [${default^^}/$( [[ $default == yes ]] && echo n || echo y )] " ans
    ans=${ans:-$default}
    [[ "$ans" =~ ^[Yy]$ ]]
}

# -------------------- ASCII art --------------------
show_ascii() {
cat <<'EOF'
      ___________
     |  _______  |  PLAYDATE C
     | |       | |  SETUP WIZARD
     | |_______| |__
     |      @    |  | v2.0.0
     |   _    O  |
     | _| |_  O  |
     ||_   _|    |__| (C)rank it!
     |  |_|      |
     |___________|
EOF
}

# -------------------- Argument parsing --------------------
MODE="interactive"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            # Convert to lowercase in a Bash‑3.2‑safe way
            MODE="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# -------------------- Logging --------------------
exec >>"$LOG_FILE" 2>&1   # everything after this goes to the log file

# -------------------- Helper: SDK detection --------------------
candidate_sdk_paths=(
    "$HOME/Documents/PlaydateSDK"
    "$HOME/Documents/Playdate SDK"
    "/Applications/PlaydateSDK"
    "/usr/local/PlaydateSDK"
    "/opt/PlaydateSDK"
)

detect_sdk() {
    # 1️⃣ env var
    if [[ -n "$PLAYDATE_SDK_PATH" && -d "$PLAYDATE_SDK_PATH" ]]; then
        echo "$PLAYDATE_SDK_PATH"
        return
    fi
    # 2️⃣ common locations
    for p in "${candidate_sdk_paths[@]}"; do
        if [[ -d "$p" ]]; then
            echo "$p"
            return
        fi
    done
    # 3️⃣ not found
    echo ""
}

# -------------------- Helper: tool checks --------------------
check_tool() {
    # $1 = command name, $2 = friendly name
    if command -v "$1" >/dev/null; then
        say "$2 found at $(command -v $1)" "$GREEN" "$ICON_OK"
        return 0
    else
        say "$2 NOT found" "$RED" "$ICON_ERR"
        return 1
    fi
}

# -------------------- Main workflow --------------------
main() {
    clear
    show_ascii
    say "Playdate Setup Wizard – mode: $MODE" "$CYAN" "$ICON_SETUP"
    echo

    # ----------- 1️⃣ Detect Playdate SDK -----------
    say "Detecting Playdate SDK…" "$CYAN" "$ICON_STEP"
    SDK_PATH=$(detect_sdk)
    if [[ -z "$SDK_PATH" ]]; then
        say "Playdate SDK not found!" "$RED" "$ICON_ERR"
        if confirm "Download and install the SDK automatically?" "yes"; then
            open_browser "https://play.date/dev/"
            read -p "After installing, press ENTER to continue…" _
            SDK_PATH=$(detect_sdk)
            if [[ -z "$SDK_PATH" ]]; then
                say "Still can't find the SDK – aborting." "$RED" "$ICON_ERR"
                exit 1
            fi
        else
            say "Please install the SDK manually and set PLAYDATE_SDK_PATH." "$YELLOW" "$ICON_WARN"
            exit 1
        fi
    fi
    say "SDK located at $SDK_PATH" "$GREEN" "$ICON_OK"

    # ----------- 2️⃣ Verify required tools -----------
    say "\nChecking required tools…" "$CYAN" "$ICON_STEP"
    missing_tools=()
    check_tool clang "Clang (Xcode command‑line tools)"   || missing_tools+=("clang")
    check_tool "$SDK_PATH/bin/pdc" "Playdate packager (pdc)" || missing_tools+=("pdc")
    # Optional but nice
    check_tool code "VS Code"                           && have_vscode=1 || have_vscode=0
    check_tool make "make"                              && have_make=1  || have_make=0
    check_tool git "git"                                && have_git=1   || have_git=0
    check_tool arm-none-eabi-gcc "ARM GCC toolchain"   && have_arm=1   || have_arm=0

    if (( ${#missing_tools[@]} > 0 )); then
        say "Missing required tools: ${missing_tools[*]}" "$RED" "$ICON_ERR"
        if [[ "$MODE" == "silent" ]]; then exit 1; fi
        open_browser "https://developer.apple.com/xcode/"
        read -p "Install the missing tools, then press ENTER to retry…" _
        main   # restart after user installs
    fi

    # ----------- 3️⃣ Environment variable handling ----------
    say "\nEnsuring PLAYDATE_SDK_PATH is set…" "$CYAN" "$ICON_STEP"
    if [[ -z "$PLAYDATE_SDK_PATH" ]]; then
        if confirm "Add PLAYDATE_SDK_PATH to your shell profile?" "yes"; then
            PROFILE_FILE="${HOME}/.bash_profile"
            [[ -f "${HOME}/.zshrc" ]] && PROFILE_FILE="${HOME}/.zshrc"
            echo "export PLAYDATE_SDK_PATH=\"$SDK_PATH\"" >>"$PROFILE_FILE"
            echo 'export PATH="$PATH:$PLAYDATE_SDK_PATH/bin"' >>"$PROFILE_FILE"
            say "Added to $PROFILE_FILE – reload your terminal to apply." "$GREEN" "$ICON_OK"
        else
            export PLAYDATE_SDK_PATH="$SDK_PATH"
            export PATH="$PATH:$PLAYDATE_SDK_PATH/bin"
            say "Set for this session only." "$YELLOW" "$ICON_WARN"
        fi
    else
        say "PLAYDATE_SDK_PATH already defined." "$GREEN" "$ICON_OK"
    fi

    # ----------- 4️⃣ Mode‑specific actions ----------
    case "$MODE" in
        check|silent)
            say "\nSystem check complete – all required components are present." "$GREEN" "$ICON_OK"
            ;;

        env)
            say "\nEnvironment variable configuration finished." "$GREEN" "$ICON_OK"
            ;;

        build|repair|interactive)
            # Offer to build the demo game
            if confirm "Build the demo game now?" "yes"; then
                if [[ -x "$BUILD_SCRIPT" ]]; then
                    "$BUILD_SCRIPT" --clean
                    if [[ $? -eq 0 && -f "${SCRIPT_DIR}/MyPlaydateGame.pdx" ]]; then
                        say "Demo built successfully!" "$GREEN" "$ICON_OK"
                        if confirm "Launch the Playdate Simulator?" "yes"; then
                            SIMULATOR_APP="${SDK_PATH}/bin/PlaydateSimulator.app"
                            if [[ -d "$SIMULATOR_APP" ]]; then
                                open -a "$SIMULATOR_APP" --args "${SCRIPT_DIR}/MyPlaydateGame.pdx"
                                say "Simulator launched." "$GREEN" "$ICON_OK"
                            else
                                say "Simulator bundle not found at $SIMULATOR_APP" "$RED" "$ICON_ERR"
                            fi
                        fi
                    else
                        say "Build failed – see the log at $LOG_FILE" "$RED" "$ICON_ERR"
                    fi
                else
                    say "Cannot find build.sh – aborting." "$RED" "$ICON_ERR"
                fi
            fi
            ;;

        vscode)
            if (( have_vscode )); then
                say "Opening project in VS Code…" "$CYAN" "$ICON_PLAY"
                (cd "$SCRIPT_DIR" && code .)
            else
                say "VS Code not installed – you can install it from https://code.visualstudio.com/" "$YELLOW" "$ICON_WARN"
                open_browser "https://code.visualstudio.com/"
            fi
            ;;

        *)
            say "Unknown mode: $MODE – exiting." "$RED" "$ICON_ERR"
            exit 1
            ;;
    esac

    # ----------- 5️⃣ Summary table ----------
    echo
    say "=== Summary ===" "$MAGENTA" "$ICON_INFO"
    printf "%-20s %s\n" "Playdate SDK:" "${SDK_PATH}"
    printf "%-20s %s\n" "Clang:" "$(command -v clang || echo 'missing')"
    printf "%-20s %s\n" "pdc:" "$(test -x "$SDK_PATH/bin/pdc" && echo 'found' || echo 'missing')"
    printf "%-20s %s\n" "VS Code:" "$([ $have_vscode -eq 1 ] && echo 'found' || echo 'missing')"
    printf "%-20s %s\n" "Make:" "$([ $have_make -eq 1 ] && echo 'found' || echo 'missing')"
    printf "%-20s %s\n" "Git:" "$([ $have_git -eq 1 ] && echo 'found' || echo 'missing')"
    printf "%-20s %s\n" "ARM GCC:" "$([ $have_arm -eq 1 ] && echo 'found' || echo 'missing (device builds disabled)')"
    echo
    say "All done! Logs are stored in $LOG_FILE" "$CYAN" "$ICON_INFO"
}

# -------------------- Run --------------------
main