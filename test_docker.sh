#!/bin/bash
# =============================================================================
# QEST — End-to-End Test Orchestrator
# =============================================================================
#
# Builds and runs each distro's Dockerfile, parses verify.sh output, and
# prints a consolidated summary table with per-distro timing and check counts.
#
# Usage:
#   ./test_docker.sh                      # all distros, sequential
#   ./test_docker.sh --parallel           # all distros, in parallel
#   ./test_docker.sh ubuntu               # single distro only
#   ./test_docker.sh --no-cache           # force fresh Docker layer cache
#   ./test_docker.sh ubuntu --no-cache    # combine flags freely
#   ./test_docker.sh --help
# =============================================================================
set -uo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
C_GREEN="\e[32m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_CYAN="\e[36m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_RESET="\e[0m"

# ── Print helpers ─────────────────────────────────────────────────────────────
h1()   { echo -e "\n${C_BOLD}${C_CYAN}$*${C_RESET}"; }
info() { echo -e "  ${C_DIM}$*${C_RESET}"; }
ok()   { echo -e "  ${C_GREEN}✔${C_RESET}  $*"; }
err()  { echo -e "  ${C_RED}✘${C_RESET}  $*"; }

# Formats raw seconds into a human-readable duration string.
elapsed_fmt() {
    local s="$1"
    if   [ "$s" -ge 3600 ]; then printf "%dh %02dm %02ds" $((s/3600)) $((s%3600/60)) $((s%60))
    elif [ "$s" -ge 60   ]; then printf "%dm %02ds" $((s/60)) $((s%60))
    else                         printf "%ds" "$s"
    fi
}

# Strips literal \e[...m sequences from a string so we can measure its
# visual (on-screen) length.  Our colour vars use the two-char literal "\e",
# not a real ESC byte, so the pattern matches backslash-e-[…-m.
strip_ansi() { printf '%s' "$1" | sed 's/\\e\[[0-9;]*m//g'; }

# Prints $1 (which may contain \e[…m colour codes) then pads with spaces
# until the visual width equals $2.
pad_right() {
    local text="$1" width="$2"
    local visual
    visual=$(strip_ansi "$text")
    local pad=$(( width - ${#visual} ))
    printf '%b' "$text"
    [ "$pad" -gt 0 ] && printf '%*s' "$pad" ""
}

# ── Argument parsing ──────────────────────────────────────────────────────────
PARALLEL=0
NO_CACHE=""
DISTROS=("ubuntu" "fedora" "arch")

for arg in "$@"; do
    case "$arg" in
        --parallel)         PARALLEL=1 ;;
        --no-cache)         NO_CACHE="--no-cache" ;;
        ubuntu|fedora|arch) DISTROS=("$arg") ;;
        -h|--help)
            echo "Usage: $0 [distro] [--parallel] [--no-cache]"
            echo ""
            echo "  distro      ubuntu | fedora | arch   (default: all three)"
            echo "  --parallel  run all distros simultaneously"
            echo "  --no-cache  pass --no-cache to every docker build"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg   (try --help)"
            exit 1
            ;;
    esac
done

# Parallel mode with a single distro is pointless — downgrade silently.
[ "${#DISTROS[@]}" -eq 1 ] && PARALLEL=0

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    err "Docker is not installed or not in PATH."
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon is not running."
    exit 1
fi

if [ ! -f "qest.sh" ]; then
    err "Run this script from the repo root (the directory containing qest.sh)."
    exit 1
fi

# ── Temp workspace ────────────────────────────────────────────────────────────
LOG_DIR=$(mktemp -d /tmp/qest-test-XXXXXX)
# shellcheck disable=SC2064
trap "rm -rf '$LOG_DIR'" EXIT

# ── Per-distro runner ─────────────────────────────────────────────────────────
# Full build → run pipeline for one distro.
# Results are written to $LOG_DIR/<distro>.result as key=value pairs so that
# both sequential and parallel modes can share the same collection logic.
run_distro() {
    local distro="$1"
    local result_file="$LOG_DIR/${distro}.result"
    local build_log="$LOG_DIR/${distro}-build.log"
    local run_log="$LOG_DIR/${distro}-run.log"
    local image="qest-test-${distro}"

    local build_status="ok"
    local run_status="skip"
    local build_time=0
    local run_time=0
    local passed=0
    local failed=0
    local skipped=0

    # ── Build ──────────────────────────────────────────────────────────────
    local t0; t0=$(date +%s)
    # shellcheck disable=SC2086
    if ! docker build $NO_CACHE \
            --tag  "$image" \
            --file "tests/${distro}.Dockerfile" \
            . > "$build_log" 2>&1; then
        build_status="fail"
    fi
    build_time=$(( $(date +%s) - t0 ))

    # ── Run (only if build succeeded) ─────────────────────────────────────
    if [ "$build_status" == "ok" ]; then
        t0=$(date +%s)
        if ! docker run --rm "$image" > "$run_log" 2>&1; then
            run_status="fail"
        else
            run_status="ok"
        fi
        run_time=$(( $(date +%s) - t0 ))

        # Parse counters from verify.sh's summary line, e.g.
        #   "  45 passed  2 failed  1 skipped"
        if grep -qE '[0-9]+ passed' "$run_log" 2>/dev/null; then
            passed=$(grep -oE  '[0-9]+ passed'   "$run_log" | grep -oE '[0-9]+' | tail -1)
            failed=$(grep -oE  '[0-9]+ failed'   "$run_log" | grep -oE '[0-9]+' | tail -1)
            skipped=$(grep -oE '[0-9]+ skipped'  "$run_log" | grep -oE '[0-9]+' | tail -1)
        fi
    fi

    cat > "$result_file" <<EOF
BUILD_STATUS=${build_status}
RUN_STATUS=${run_status}
BUILD_TIME=${build_time}
RUN_TIME=${run_time}
PASSED=${passed:-0}
FAILED=${failed:-0}
SKIPPED=${skipped:-0}
EOF
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}║      QEST  —  End-to-End Test Orchestrator       ║${C_RESET}"
echo -e "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════╝${C_RESET}"
echo -e "  ${C_DIM}Distros  :${C_RESET} ${DISTROS[*]}"
echo -e "  ${C_DIM}Mode     :${C_RESET} $([ "$PARALLEL" -eq 1 ] && echo "parallel" || echo "sequential")"
echo -e "  ${C_DIM}No-cache :${C_RESET} $([ -n "$NO_CACHE" ] && echo "yes" || echo "no")"
echo -e "  ${C_DIM}Logs     :${C_RESET} $LOG_DIR"

# ── Execute tests ─────────────────────────────────────────────────────────────
WALL_START=$(date +%s)

if [ "$PARALLEL" -eq 1 ]; then
    h1 "Launching ${#DISTROS[@]} distro builds in parallel…"
    pids=()
    for distro in "${DISTROS[@]}"; do
        info "Spawning: $distro"
        run_distro "$distro" &
        pids+=("$!")
    done
    info "Waiting for all jobs to finish…"
    for pid in "${pids[@]}"; do
        wait "$pid" || true   # errors are captured in result files; don't abort here
    done
else
    for distro in "${DISTROS[@]}"; do
        h1 "Testing: $distro"
        info "Building  →  qest-test-${distro}…"
        run_distro "$distro"

        # Live single-line status after each distro in sequential mode.
        if [ -f "$LOG_DIR/${distro}.result" ]; then
            # shellcheck source=/dev/null
            source "$LOG_DIR/${distro}.result"
            if [ "$BUILD_STATUS" != "ok" ]; then
                err "$distro  build FAILED  ($(elapsed_fmt "$BUILD_TIME"))"
            elif [ "$RUN_STATUS" != "ok" ] || [ "${FAILED:-0}" -gt 0 ]; then
                err "$distro  FAILED  —  ${FAILED} check(s) failed  (run: $(elapsed_fmt "$RUN_TIME"))"
            else
                ok "$distro  passed  —  build $(elapsed_fmt "$BUILD_TIME")  /  run $(elapsed_fmt "$RUN_TIME")  |  ${PASSED} checks OK, ${SKIPPED} skipped"
            fi
        fi
    done
fi

WALL_ELAPSED=$(( $(date +%s) - WALL_START ))

# ── Results table ─────────────────────────────────────────────────────────────
h1 "Results"

# Visual column widths (characters on screen, excluding ANSI codes).
W_DISTRO=10
W_BUILD=7
W_RUN=7
W_PASS=8
W_FAIL=8
W_SKIP=9
W_TIME=10

# Table header row
echo ""
printf "  "
pad_right "${C_BOLD}DISTRO${C_RESET}"   $W_DISTRO; printf "  "
pad_right "${C_BOLD}BUILD${C_RESET}"    $W_BUILD;  printf "  "
pad_right "${C_BOLD}RUN${C_RESET}"      $W_RUN;    printf "  "
pad_right "${C_BOLD}PASSED${C_RESET}"   $W_PASS;   printf "  "
pad_right "${C_BOLD}FAILED${C_RESET}"   $W_FAIL;   printf "  "
pad_right "${C_BOLD}SKIPPED${C_RESET}"  $W_SKIP;   printf "  "
printf "${C_BOLD}TIME${C_RESET}\n"

DIVIDER="  $(printf '─%.0s' {1..74})"
echo -e "$DIVIDER"

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
OVERALL_FAIL=0

for distro in "${DISTROS[@]}"; do
    result_file="$LOG_DIR/${distro}.result"

    # Guard: result file missing means the subshell itself crashed.
    if [ ! -f "$result_file" ]; then
        printf "  "
        pad_right "$distro"                       $W_DISTRO; printf "  "
        pad_right "${C_RED}missing${C_RESET}"     $W_BUILD;  printf "  "
        pad_right "-"                             $W_RUN;    printf "  "
        pad_right "-"                             $W_PASS;   printf "  "
        pad_right "-"                             $W_FAIL;   printf "  "
        pad_right "-"                             $W_SKIP;   printf "  "
        printf "-\n"
        OVERALL_FAIL=1
        continue
    fi

    # Reset before sourcing to avoid inheriting values from a previous loop iteration.
    BUILD_STATUS=""; RUN_STATUS="skip"
    BUILD_TIME=0; RUN_TIME=0; PASSED=0; FAILED=0; SKIPPED=0
    # shellcheck source=/dev/null
    source "$result_file"

    TOTAL_TIME=$(( BUILD_TIME + RUN_TIME ))
    TOTAL_PASSED=$(( TOTAL_PASSED + PASSED ))
    TOTAL_FAILED=$(( TOTAL_FAILED + FAILED ))
    TOTAL_SKIPPED=$(( TOTAL_SKIPPED + SKIPPED ))

    # Colour-code BUILD column
    case "$BUILD_STATUS" in
        ok)   build_col="${C_GREEN}ok${C_RESET}" ;;
        fail) build_col="${C_RED}FAIL${C_RESET}"; OVERALL_FAIL=1 ;;
        *)    build_col="${C_YELLOW}-${C_RESET}" ;;
    esac

    # Colour-code RUN column
    case "$RUN_STATUS" in
        ok)   run_col="${C_GREEN}ok${C_RESET}" ;;
        fail) run_col="${C_RED}FAIL${C_RESET}"; OVERALL_FAIL=1 ;;
        *)    run_col="${C_YELLOW}skip${C_RESET}" ;;
    esac

    # Colour-code check counters
    pass_col="${C_GREEN}${PASSED}${C_RESET}"
    skip_col="${C_YELLOW}${SKIPPED}${C_RESET}"
    if [ "${FAILED:-0}" -gt 0 ]; then
        fail_col="${C_RED}${FAILED}${C_RESET}"
        OVERALL_FAIL=1
    else
        fail_col="${C_GREEN}${FAILED}${C_RESET}"
    fi

    printf "  "
    pad_right "$distro"      $W_DISTRO; printf "  "
    pad_right "$build_col"   $W_BUILD;  printf "  "
    pad_right "$run_col"     $W_RUN;    printf "  "
    pad_right "$pass_col"    $W_PASS;   printf "  "
    pad_right "$fail_col"    $W_FAIL;   printf "  "
    pad_right "$skip_col"    $W_SKIP;   printf "  "
    printf "%s\n" "$(elapsed_fmt "$TOTAL_TIME")"
done

echo -e "$DIVIDER"

# Totals row
printf "  "
pad_right "${C_BOLD}TOTAL${C_RESET}" $W_DISTRO; printf "  "
pad_right ""                         $W_BUILD;  printf "  "
pad_right ""                         $W_RUN;    printf "  "
pad_right "${C_BOLD}${C_GREEN}${TOTAL_PASSED}${C_RESET}"   $W_PASS;  printf "  "
if [ "$TOTAL_FAILED" -gt 0 ]; then
    pad_right "${C_BOLD}${C_RED}${TOTAL_FAILED}${C_RESET}"   $W_FAIL
else
    pad_right "${C_BOLD}${C_GREEN}${TOTAL_FAILED}${C_RESET}" $W_FAIL
fi
printf "  "
pad_right "${C_BOLD}${C_YELLOW}${TOTAL_SKIPPED}${C_RESET}" $W_SKIP; printf "  "
printf "${C_BOLD}%s${C_RESET}\n" "$(elapsed_fmt "$WALL_ELAPSED")"

# ── Failure details ───────────────────────────────────────────────────────────
# For any distro that failed, tail the relevant log so the cause is visible
# right in the terminal without having to dig into $LOG_DIR manually.
for distro in "${DISTROS[@]}"; do
    result_file="$LOG_DIR/${distro}.result"
    [ -f "$result_file" ] || continue

    BUILD_STATUS=""; RUN_STATUS="skip"; FAILED=0
    # shellcheck source=/dev/null
    source "$result_file"

    if [ "$BUILD_STATUS" == "fail" ]; then
        echo ""
        echo -e "  ${C_RED}${C_BOLD}── $distro  build output (last 30 lines) ──────────────────────${C_RESET}"
        tail -30 "$LOG_DIR/${distro}-build.log" 2>/dev/null | sed 's/^/    /' || true
    fi

    if [ "$RUN_STATUS" == "fail" ] || [ "${FAILED:-0}" -gt 0 ]; then
        echo ""
        echo -e "  ${C_RED}${C_BOLD}── $distro  run / verify output (last 60 lines) ────────────────${C_RESET}"
        tail -60 "$LOG_DIR/${distro}-run.log" 2>/dev/null | sed 's/^/    /' || true
    fi
done

# ── Final verdict ─────────────────────────────────────────────────────────────
echo ""
echo -e "  ${C_DIM}Wall time: $(elapsed_fmt "$WALL_ELAPSED")${C_RESET}"
echo ""

if [ "$OVERALL_FAIL" -eq 0 ]; then
    echo -e "  ${C_GREEN}${C_BOLD}╔══════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║   ✔   ALL TESTS PASSED               ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╚══════════════════════════════════════╝${C_RESET}"
    exit 0
else
    echo -e "  ${C_RED}${C_BOLD}╔══════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║   ✘   SOME TESTS FAILED              ║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}╚══════════════════════════════════════╝${C_RESET}"
    exit 1
fi
