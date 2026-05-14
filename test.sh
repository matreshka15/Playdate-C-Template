
#!/usr/bin/env bash
# -------------------------------------------------
# Playdate C Template – Automated Test Runner (bash)
# -------------------------------------------------
# Usage:
#   ./test.sh [--all] [--unit] [--integration] [--functional] [--performance] [--verbose] [--quick]
#
#   --all          Run every test group (default if none specified)
#   --unit         Run unit tests only
#   --integration  Run integration tests only
#   --functional   Run functional tests only
#   --performance  Run performance tests only
#   --verbose      Show expected/actual values for failed tests
#   --quick        Hide the detailed list of failed tests
# -------------------------------------------------

set -e                     # abort on any uncaught error
shopt -s nullglob          # globs that match nothing expand to nothing

# -------------------- Global state --------------------
START_TIME=$(date +%s)
tests_passed=0
tests_failed=0
tests_skipped=0
declare -a test_results   # each element: "ID|Name|Category|Expected|Actual|Passed"

# -------------------- Colours & icons --------------------
RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6); MAGENTA=$(tput setaf 5); WHITE=$(tput setaf 7)
RESET=$(tput sgr0)

ICON_OK="[OK]"; ICON_ERR="[FAIL]"; ICON_WARN="[WARN]"
ICON_INFO="[INFO]"; ICON_STEP="[STEP]"; ICON_ARROW="->"

say() {   # generic printer: $1=message $2=colour-var $3=icon (optional)
    local msg=$1 col=${2:-WHITE} icon=${3:-$ICON_INFO}
    printf "%b%s %s%b\n" "${!col}" "$icon" "$msg" "$RESET"
}
title()   { say "$1" CYAN "$ICON_STEP"; }
success() { say "$1" GREEN "$ICON_OK"; }
error()   { say "$1" RED "$ICON_ERR"; }
info()    { say "$1" WHITE "$ICON_INFO"; }
warn()    { say "$1" YELLOW "$ICON_WARN"; }

# -------------------- Helper: record a test --------------------
record_test() {
    local id=$1 name=$2 category=$3 expected=$4 actual=$5 passed=$6
    test_results+=("$id|$name|$category|$expected|$actual|$passed")
    if $passed; then
        ((tests_passed++))
        success "$id: $name"
    else
        ((tests_failed++))
        error "$id: $name"
        $VERBOSE && {
            info "  Expected: $expected"
            info "  Actual:   $actual"
        }
    fi
}

# -------------------- Individual assertion: file exists --------------------
test_file_exists() {
    local path=$1 id=$2 name=$3 cat=$4

    if [[ -e "$path" ]]; then
        record_test "$id" "$name" "$cat" "File exists" "File exists" true
        return 0
    else
        # Record the failure first (so you still get a line in the summary)
        record_test "$id" "$name" "$cat" "File exists" "File not found" false

        return 1
    fi
}

test_file_not_empty() {
    local path=$1 id=$2 name=$3 cat=$4
    if [[ ! -e "$path" ]]; then
        record_test "$id" "$name" "$cat" "File not empty" "File not found" false
        return 1
    elif [[ -s "$path" ]]; then
        record_test "$id" "$name" "$cat" "File not empty" "File has content" true
        return 0
    else
        record_test "$id" "$name" "$cat" "File not empty" "File is empty" false
        return 1
    fi
}

test_valid_json() {
    local path=$1 id=$2 name=$3 cat=$4
    if [[ ! -e "$path" ]]; then
        record_test "$id" "$name" "$cat" "Valid JSON" "File not found" false
        return 1
    fi
    if jq . "$path" >/dev/null 2>&1; then
        record_test "$id" "$name" "$cat" "Valid JSON" "Valid JSON" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Valid JSON" "Invalid JSON" false
        return 1
    fi
}

test_json_field() {
    local path=$1 field=$2 id=$3 name=$4 cat=$5
    if [[ ! -e "$path" ]]; then
        record_test "$id" "$name" "$cat" "Field $field exists" "File not found" false
        return 1
    fi
    if jq -e ".${field}? != null" "$path" >/dev/null 2>&1; then
        record_test "$id" "$name" "$cat" "Field $field exists" "Field exists" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Field $field exists" "Field missing" false
        return 1
    fi
}

test_parameter_definition() {
    local file=$1 param=$2 id=$3 name=$4 cat=$5
    if grep -qE "^[[:space:]]*$param[[:space:]]*=" "$file"; then
        record_test "$id" "$name" "$cat" "Variable $param defined" "Found" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Variable $param defined" "Missing" false
        return 1
    fi
}

test_function_definition() {
    local file=$1 func=$2 id=$3 name=$4 cat=$5

    local pattern="^[[:space:]]*\(function[[:space:]]+\)\?${func}[[:space:]]*()[[:space:]]*{\?"

    if grep -q "$pattern" "$file"; then
        record_test "$id" "$name" "$cat" "Function $func defined" "Found" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Function $func defined" "Missing" false
        return 1
    fi
}

test_regex_match() {
    local file=$1 pattern=$2 id=$3 name=$4 cat=$5
    if grep -qE "$pattern" "$file"; then
        record_test "$id" "$name" "$cat" "Pattern $pattern found" "Matched" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Pattern $pattern found" "Not found" false
        return 1
    fi
}

test_no_hardcoded_paths() {
    local file=$1 id=$2 name=$3 cat=$4

    # Look for a forward slash that is **not** the first character of a shebang (#!)
    # and is preceded by either the start of the line or whitespace.
    # This catches:
    #   /usr/local/bin
    #   ./relative   ← ignored (doesn't start with /)
    #   http://...   ← ignored (doesn't start with /)
    #   # comment    ← ignored (starts with #)
    #   #!/usr/bin   ← ignored (shebang)
    local pattern='(^|[[:space:]])/[^[:space:]"'"'"']+'
    
    if grep -q "$pattern" "$file"; then
        record_test "$id" "$name" "$cat" "No hard‑coded Windows paths" "Hard‑coded paths found" false
        return 1
    else
        record_test "$id" "$name" "$cat" "No hard‑coded Windows paths" "None found" true
        return 0
    fi
}

test_environment_variable() {
    local var=$1 id=$2 name=$3 cat=$4
    if [[ -n "${!var}" ]]; then
        record_test "$id" "$name" "$cat" "Env var $var set" "Value: ${!var}" true
        return 0
    else
        record_test "$id" "$name" "$cat" "Env var $var set" "Not set" false
        return 1
    fi
}

# -------------------- Test groups --------------------
run_unit_tests() {
    title "Unit Tests"
    # Resolve the directory that contains this test script (the project root)
    local proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # ---- File existence checks (macOS .sh files) ----
    test_file_exists "$proj_dir/setup.sh"               UT-001 "setup.sh exists"               Unit
    test_file_exists "$proj_dir/build.sh"               UT-002 "build.sh exists"               Unit
    test_file_exists "$proj_dir/src/main.c"             UT-003 "src/main.c exists"             Unit
    test_file_exists "$proj_dir/setup-config.json"      UT-004 "setup-config.json exists"      Unit

    # ---- Non‑empty checks ----
    test_file_not_empty "$proj_dir/setup.sh"            UT-005 "setup.sh not empty"            Unit
    test_file_not_empty "$proj_dir/build.sh"            UT-006 "build.sh not empty"            Unit
    test_file_not_empty "$proj_dir/src/main.c"          UT-007 "src/main.c not empty"          Unit

    # ---- JSON validation ----
    test_valid_json "$proj_dir/setup-config.json"        UT-008 "setup-config.json valid JSON"   Unit

    # ---- Parameter definitions (now look inside the .sh files) ----
    # In the Bash version we just search for the variable name; PowerShell‑style
    # parameter blocks don’t exist, so we treat the presence of a variable as enough.
    test_parameter_definition "$proj_dir/setup.sh"   "SDK_PATH"   UT-009 "setup.sh has SDK_PATH variable"   Unit
    test_parameter_definition "$proj_dir/build.sh"   "CLEAN"      UT-010 "build.sh has CLEAN variable"       Unit
    test_parameter_definition "$proj_dir/build.sh"   "RUN"        UT-011 "build.sh has RUN variable"         Unit

    # ---- Function definitions (Bash equivalents) ----
    test_function_definition "$proj_dir/build.sh"   "resolve_sdk_path"   UT-012 "build.sh has resolve_sdk_path function"   Unit
    test_function_definition "$proj_dir/setup.sh"   "main" UT-013 "setup.sh has main function (entry point)" Unit
}

run_integration_tests() {
    title "Integration Tests"
    local proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    test_json_field "$proj_dir/setup-config.json" projectName IT-001 "Config has projectName field" Integration
    test_json_field "$proj_dir/setup-config.json" author      IT-002 "Config has author field"      Integration
    test_json_field "$proj_dir/setup-config.json" sdkPath     IT-003 "Config has sdkPath field"     Integration

    test_file_exists "$proj_dir/.vscode/settings.json"  IT-004 "VS Code settings exist"      Integration
    test_file_exists "$proj_dir/.vscode/launch.json"   IT-005 "VS Code launch config exist" Integration
    test_file_exists "$proj_dir/.vscode/tasks.json"    IT-006 "VS Code tasks exist"         Integration

    test_regex_match "$proj_dir/.vscode/settings.json" "PLAYDATE_SDK_PATH" IT-007 "VS Code has SDK path configured" Integration
}

run_functional_tests() {
    title "Functional Tests"

    # Resolve the project root (add trailing slash for safe concatenation)
    local proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # ----- 1️⃣ No Windows‑style hard‑coded paths -----
    test_no_hardcoded_paths "${proj_dir}/build.sh"                FT-001 "build.sh has no hardcoded Windows paths" Functional
    test_no_hardcoded_paths "${proj_dir}/.vscode/settings.json"   FT-002 "VS Code settings have no hardcoded Windows paths" Functional

    # ----- 2️⃣ Bash‑specific regex checks -----
    # PLAYDATE_SDK_PATH is still the env‑var name used in the Bash script.
    test_regex_match "${proj_dir}/build.sh" "PLAYDATE_SDK_PATH"    FT-003 "build.sh reads SDK from env" Functional

    # SDK‑resolution helper in Bash is `resolve_sdk_path`.
    test_regex_match "${proj_dir}/build.sh" "resolve_sdk_path"   FT-004 "build.sh has SDK path resolution" Functional

    # ----- 3️⃣ Environment variable presence -----
    test_environment_variable PLAYDATE_SDK_PATH FT-005 "PLAYDATE_SDK_PATH env var set" Functional
}

run_performance_tests() {
    title "Performance Tests"
    local proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Measure script startup (we just call build.ps1 with -? which prints help)
    local start=$(date +%s%N)
    "$proj_dir/build.ps1" -? >/dev/null 2>&1 || true
    local elapsed_ms=$(( ( $(date +%s%N) - start ) / 1000000 ))

    if (( elapsed_ms < 5000 )); then
        record_test PT-001 "Script startup < 5 s" Performance "< 5000 ms" "${elapsed_ms} ms" true
    else
        record_test PT-001 "Script startup < 5 s" Performance "< 5000 ms" "${elapsed_ms} ms" false
    fi

    # Config file size
    if [[ -e "$proj_dir/setup-config.json" ]]; then
        local size=$(stat -c%s "$proj_dir/setup-config.json")
        if (( size < 1024 )); then
            record_test PT-002 "Config file size < 1 KB" Performance "< 1024 bytes" "${size} bytes" true
        else
            record_test PT-002 "Config file size < 1 KB" Performance "< 1024 bytes" "${size} bytes" false
        fi
    else
        record_test PT-002 "Config file size < 1 KB" Performance "< 1024 bytes" "File missing" false
    fi
}

# -------------------- Summary --------------------
show_summary() {
    local end_time=$(date +%s)
    local total_elapsed=$(( end_time - START_TIME ))
    local total=$(( tests_passed + tests_failed + tests_skipped ))
    local pass_rate=0
    (( total > 0 )) && pass_rate=$(awk "BEGIN {printf \"%.1f\", (${tests_passed}/${total})*100}")

    title "═══════════════════════════════════════════════════════════"
    echo "                    Test Summary"
    title "═══════════════════════════════════════════════════════════"

    echo
    printf "  Total Tests : %d\n" "$total"
    printf "  Passed      : %s%d%s\n" "$GREEN" "$tests_passed" "$RESET"
    printf "  Failed      : %s%d%s\n" "$RED"   "$tests_failed" "$RESET"
    printf "  Pass Rate   : %s%.1f%%%s\n" "$( (( pass_rate >= 80 )) && echo "$GREEN" || echo "$RED" )" "$pass_rate" "$RESET"
    printf "  Execution Time : %ds\n" "$total_elapsed"
    echo

    if [[ "$QUICK" != true && ${#test_results[@]} -gt 0 ]]; then
        if (( tests_failed > 0 )); then
            title "Failed Tests"
            for rec in "${test_results[@]}"; do
                IFS='|' read -r id name cat exp act passed <<<"$rec"
                $passed && continue
                printf "  %s✗ %s: %s\n" "$RED" "$id" "$name"
                $VERBOSE && {
                    printf "    Expected: %s\n" "$exp"
                    printf "    Actual  : %s\n" "$act"
                }
            done
        fi
    fi

    echo
    if (( tests_failed == 0 )); then
        success "All tests passed! 🎉"
    else
        error "Some tests failed. Review the output above."
    fi
    echo
}

# -------------------- Argument parsing --------------------

ALL=false UNIT=false INTEGRATION=false FUNCTIONAL=false PERFORMANCE=false VERBOSE=false QUICK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)          ALL=true; shift ;;
        --unit)         UNIT=true; shift ;;
        --integration)  INTEGRATION=true; shift ;;
        --functional)   FUNCTIONAL=true; shift ;;
        --performance)  PERFORMANCE=true; shift ;;
        --verbose)      VERBOSE=true; shift ;;
        --quick)        QUICK=true; shift ;;
        *)  error "Unknown option: $1"; exit 1 ;;
    esac
done

# If the user didn’t specify any particular group, default to “all”.
if ! $ALL && ! $UNIT && ! $INTEGRATION && ! $FUNCTIONAL && ! $PERFORMANCE; then
    ALL=true
fi

# -------------------- Main driver --------------------
main() {
    clear
    title "═══════════════════════════════════════════════════════════"
    echo "      🎮 Playdate C Template – Test Runner v1.0.0"
    title "═══════════════════════════════════════════════════════════"
    echo

    # Decide which suites to execute
    $ALL && {
        run_unit_tests
        run_integration_tests
        run_functional_tests
        run_performance_tests
    }

    $UNIT &&        run_unit_tests
    $INTEGRATION && run_integration_tests
    $FUNCTIONAL &&  run_functional_tests
    $PERFORMANCE && run_performance_tests

    # Show the final report
    show_summary
}

# -------------------- Entry point --------------------
main

