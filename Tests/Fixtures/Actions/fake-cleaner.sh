#!/bin/sh

set -eu

case "${1:-}" in
    success)
        printf '%s\n' \
            '{"status":"succeeded","logicalBytesAffected":4096,"allocatedBytesAffected":8192,"completedItems":2,"failedItems":0}'
        ;;
    success-with-child)
        if [ -z "${STORNAUT_FAKE_CLEANER_PID_FILE:-}" ]; then
            printf '%s\n' "missing pid file" >&2
            exit 64
        fi
        (
            trap '' INT TERM
            sleep 30
        ) &
        child_pid=$!
        printf '%s\n' "$child_pid" > "$STORNAUT_FAKE_CLEANER_PID_FILE"
        printf '%s\n' \
            '{"status":"succeeded","logicalBytesAffected":4096,"allocatedBytesAffected":8192,"completedItems":2,"failedItems":0}'
        exit 0
        ;;
    dry-run)
        printf '%s\n' \
            '{"status":"dryRun","logicalBytesAffected":0,"allocatedBytesAffected":0,"completedItems":0,"failedItems":0}'
        ;;
    timeout)
        if [ -n "${STORNAUT_FAKE_CLEANER_PID_FILE:-}" ]; then
            (
                sleep 30
            ) &
            child_pid=$!
            printf '%s:%s\n' "$$" "$child_pid" \
                > "$STORNAUT_FAKE_CLEANER_PID_FILE"
            wait "$child_pid"
            exit 0
        fi
        sleep 30
        ;;
    partial-failure)
        printf '%s\n' \
            '{"status":"partiallyFailed","logicalBytesAffected":2048,"allocatedBytesAffected":4096,"completedItems":1,"failedItems":1}'
        exit 3
        ;;
    *)
        printf '%s\n' "unsupported fake-cleaner mode" >&2
        exit 64
        ;;
esac
