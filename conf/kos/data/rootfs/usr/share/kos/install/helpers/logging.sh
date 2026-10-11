kos_log_to_stdout() {
  [[ ${KOS_LOG_TO_STDOUT:-} == "1" || -z ${KOS_INSTALL_LOG_FILE:-} ]]
}

kos_log_line() {
  if kos_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$KOS_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! kos_log_to_stdout; then
    mkdir -p "$(dirname "$KOS_INSTALL_LOG_FILE")"
    touch "$KOS_INSTALL_LOG_FILE"
    chmod 666 "$KOS_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export KOS_START_TIME="${KOS_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export KOS_START_EPOCH="${KOS_START_EPOCH:-$(date +%s)}"

  kos_log_line "=== Kos Setup Started: $KOS_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  kos_log_line "=== Kos Setup Completed: $end_time ==="

  if [[ -n ${KOS_START_EPOCH:-} ]]; then
    duration=$((end_epoch - KOS_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    kos_log_line "Kos setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  kos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${KOS_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if kos_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$KOS_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    kos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    kos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
