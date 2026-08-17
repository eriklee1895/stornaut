#!/bin/sh

set -eu

name=${0##*/}
mode=${name#fake-codex-}
mode=${mode%.sh}
record_dir=$PWD/.fake-record
mkdir -p "$record_dir"

printf '%s\n' "$$" > "$record_dir/pid.txt"
printf '%s\n' "$(ps -o pgid= -p $$ | tr -d ' ')" > "$record_dir/pgid.txt"
printf '%s\n' "$@" > "$record_dir/arguments.txt"
if [ "$mode" = "early-exit" ]; then
    printf '%s\n' 'exited before reading stdin' >&2
    exit 9
fi
cat > "$record_dir/stdin.txt"
pwd > "$record_dir/cwd.txt"
env | LC_ALL=C sort > "$record_dir/environment.txt"

emit_success() {
    printf '%s\n' '{"type":"thread.started","thread_id":"thread-fake"}'
    printf '%s\n' '{"type":"turn.started"}'
    printf '%s\n' '{"type":"future.event","phase":"fake","sequence":7}'
    printf '%s\n' '{"type":"item.completed","item":{"id":"message-fake","type":"agent_message","text":"{\"summary\":\"Static fake result\",\"findings\":[],\"unresolvedTargetIDs\":[]}"}}'
    printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":4,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":6,"reasoning_output_tokens":0}}'
}

case "$mode" in
    success)
        printf '%s\n' 'diagnostic only' >&2
        emit_success
        ;;
    wait-for-release)
        while [ ! -s "$PWD/.fake-release" ]; do
            sleep 0.01
        done
        emit_success
        ;;
    invalid-envelope)
        printf '%s\n' '{"type":"thread.started","thread_id":"thread-fake"}'
        printf '%s\n' '{"type":"item.completed","item":{"id":"message-fake","type":"agent_message","text":"{\"summary\":\"Missing required fields\"}"}}'
        printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0}}'
        ;;
    malformed)
        printf '%s\n' '{"type":"thread.started","thread_id":"thread-fake"}'
        printf '%s\n' '{"type":"item.completed"'
        while :; do
            sleep 1
        done
        ;;
    large-stdout)
        printf '%02048d' 0
        ;;
    large-stderr)
        printf '%02048d' 0 >&2
        ;;
    many-events)
        index=0
        while [ "$index" -lt 128 ]; do
            printf '{"type":"future.event","sequence":%s}\n' "$index"
            index=$((index + 1))
        done
        ;;
    nonzero)
        printf '%s\n' 'fake process failed' >&2
        exit 7
        ;;
    timeout)
        trap 'printf %s\\n INT >> "$record_dir/signals.txt"' INT
        trap 'printf %s\\n TERM >> "$record_dir/signals.txt"' TERM
        while :; do
            sleep 1
        done
        ;;
    child)
        trap 'printf %s\\n INT >> "$record_dir/signals.txt"' INT
        trap 'printf %s\\n TERM >> "$record_dir/signals.txt"' TERM
        (
            trap '' TERM INT
            while :; do
                sleep 1
            done
        ) &
        child_pid=$!
        printf '%s\n' "$child_pid" > "$record_dir/child-pid.txt"
        while kill -0 "$child_pid" 2>/dev/null; do
            wait "$child_pid" || true
        done
        ;;
    orphan)
        (
            trap '' TERM INT
            while :; do
                sleep 1
            done
        ) &
        child_pid=$!
        printf '%s\n' "$child_pid" > "$record_dir/child-pid.txt"
        emit_success
        ;;
    *)
        printf '%s\n' "unknown fake mode: $mode" >&2
        exit 64
        ;;
esac
