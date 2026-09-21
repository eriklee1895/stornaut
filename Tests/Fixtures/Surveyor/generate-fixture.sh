#!/bin/zsh

set -euo pipefail

marker=".stornaut-surveyor-fixture-v1"

function fail() {
    print -u2 -- "$1"
    exit 1
}

function canonical_parent_path() {
    local target=$1
    local parent=${target:h}
    local leaf=${target:t}
    [[ -d "$parent" ]] || fail "Fixture parent must already exist: $parent"
    print -r -- "${parent:A}/$leaf"
}

function validate_target() {
    local raw_target=$1
    [[ "$raw_target" = /* ]] || fail "Fixture path must be absolute."

    local target
    target=$(canonical_parent_path "$raw_target")
    local repo_root=${0:A:h:h:h}
    local home=${HOME:A}

    [[ "$target" != "/" ]] || fail "Refusing filesystem root."
    [[ "$target" != "$home" ]] || fail "Refusing HOME."
    [[ "$target" != "$repo_root" ]] || fail "Refusing repository root."
    [[ "$target" != "$repo_root/"* ]] || fail "Refusing a path inside the repository."

    print -r -- "$target"
}

function generate_fixture() {
    local target=$1
    if [[ -e "$target" ]]; then
        [[ -d "$target" && -f "$target/$marker" ]] \
            || fail "Refusing existing non-fixture path: $target"
        fail "Fixture already exists: $target"
    fi

    mkdir -p "$target"/{shallow,deep,fanout,package/Example.bundle/Contents}
    print -r -- "stornaut-surveyor-fixture-v1" > "$target/$marker"

    local index
    for index in {0..255}; do
        printf 'shallow-%04d\n' "$index" > "$target/shallow/file-$index.txt"
    done

    local cursor="$target/deep"
    for index in {0..31}; do
        cursor="$cursor/level-$index"
        mkdir "$cursor"
        printf 'deep-%04d\n' "$index" > "$cursor/file.txt"
    done

    for index in {0..511}; do
        mkdir -p "$target/fanout/dir-$index"
        printf 'fanout-%04d\n' "$index" > "$target/fanout/dir-$index/file.bin"
    done

    dd if=/dev/zero of="$target/shallow/allocated.bin" bs=4096 count=256 \
        >/dev/null 2>&1
    mkfile -n 64m "$target/shallow/sparse.bin"
    printf 'package\n' > "$target/package/Example.bundle/Contents/data.txt"
    ln -s ../shallow "$target/fanout/shallow-link"

    print -r -- "$target"
}

function clean_fixture() {
    local target=$1
    [[ -d "$target" && -f "$target/$marker" ]] \
        || fail "Refusing cleanup without fixture marker: $target"
    [[ "$(<"$target/$marker")" == "stornaut-surveyor-fixture-v1" ]] \
        || fail "Fixture marker mismatch: $target"

    rm -rf -- "$target"
}

command_name=${1:-}
raw_target=${2:-}
[[ -n "$command_name" && -n "$raw_target" && $# -eq 2 ]] \
    || fail "Usage: generate-fixture.sh <generate|clean> <absolute-path>"

target=$(validate_target "$raw_target")

case "$command_name" in
    generate)
        generate_fixture "$target"
        ;;
    clean)
        clean_fixture "$target"
        ;;
    *)
        fail "Unknown command: $command_name"
        ;;
esac
