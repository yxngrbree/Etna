#!/bin/bash
set -Eeuo pipefail

CONFIG="./etna.conf"
LOCK="/tmp/etna.lock"
LOG_DIR="./logs"
STATE_FILE="./etna.state"
REPORT_FILE="./etna_report.log"
DRY_RUN=false
MAX_PARALLEL=4
EMAIL=""
SLACK=""

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"

log() {
    local project="$1"
    local step="$2"
    local msg="$3"
    mkdir -p "$LOG_DIR"
    echo -e "$(date '+%F %T') [$project][$step] $msg" | tee -a "$LOG_DIR/$project.log" >>"$REPORT_FILE"
}

notify_failure() {
    local project="$1"
    local step="$2"
    local msg="$3"
    [[ -n $EMAIL ]] && echo "$msg" | mail -s "Pipeline Failed: $project [$step]" "$EMAIL"
    [[ -n $SLACK ]] && curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"Pipeline Failed: $project [$step]\n$msg\"}" "$SLACK" >/dev/null
}

save_state() {
    echo "$@" >>"$STATE_FILE"
}

load_state() {
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
}

run_step() {
    local proj="$1"
    local step="$2"
    local cmd="$3"
    local retries=0
    local backoff=2

    log "$proj" "$step" "START"

    until $DRY_RUN || bash -c "$cmd"; do
        ((retries++))
        if [[ $retries -ge 3 ]]; then
            log "$proj" "$step" "${RED}FAILED after $retries attempts${NC}"
            notify_failure "$proj" "$step" "Step failed after $retries retries"
            save_state "$proj|$step|FAILED"
            return 1
        fi
        log "$proj" "$step" "${YELLOW}Retry $retries, waiting $backoff sec${NC}"
        sleep $backoff
        backoff=$((backoff*2))
    done

    log "$proj" "$step" "${GREEN}COMPLETED${NC}"
    save_state "$proj|$step|SUCCESS"
}

declare -A PROJECT_STEPS
declare -A PROJECT_DEPS
declare -A EXECUTED

resolve_dependencies() {
    local proj="$1"
    for dep in ${PROJECT_DEPS[$proj]:-}; do
        [[ "${EXECUTED[$dep]:-false}" == "false" ]] && run_project "$dep"
    done
}

run_project() {
    local proj="$1"
    resolve_dependencies "$proj"
    EXECUTED[$proj]=true
    echo -ne "${CYAN}Running project: $proj${NC}\n"

    IFS=',' read -ra steps <<< "${PROJECT_STEPS[$proj]}"
    for step_def in "${steps[@]}"; do
        IFS='|' read -r step_name step_cmd <<< "$step_def"
        run_step "$proj" "$step_name" "$step_cmd" || break
    done
}

[[ -e "$LOCK" ]] && { echo "Etna is already running"; exit 1; }
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

[[ -f "$CONFIG" ]] || { echo "Config file $CONFIG missing"; exit 1; }
source "$CONFIG"
load_state

export -f run_step log notify_failure run_project save_state resolve_dependencies

parallel -j "$MAX_PARALLEL" run_project ::: "${PROJECTS[@]}"

echo -e "${CYAN}Etna pipeline completed${NC}"
echo "Logs: $LOG_DIR"
echo "State: $STATE_FILE"
