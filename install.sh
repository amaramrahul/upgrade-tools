#!/usr/bin/env bash
#
# install.sh - install or uninstall upgrade-tools scripts.
#
# Usage:
#   install.sh [--uninstall]
#
# Prompts for which tools to install (or, with --uninstall, remove). Tools are the
# scripts next to this file. They go to $DESTDIR$PREFIX/bin (default: /usr/local/bin).
#
# Environment:
#   PREFIX   installation prefix (default: /usr/local)
#   DESTDIR  staging root prepended to PREFIX (default: empty)

set -euo pipefail

PREFIX=${PREFIX:-/usr/local}
DESTDIR=${DESTDIR:-}
bindir=$DESTDIR$PREFIX/bin
srcdir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
self=$(basename -- "${BASH_SOURCE[0]}")

usage() {
    echo "Usage: $self [--uninstall]"
}

die() {
    echo "$self: $*" >&2
    exit 1
}

mode=install
case "${1:-}" in
    "") ;;
    --uninstall) mode=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac

# Tools: regular files next to this script that start with a shebang.
tools=()
for f in "$srcdir"/*; do
    name=${f##*/}
    [[ -f $f && $name != "$self" ]] || continue
    [[ $(head -c2 -- "$f") == '#!' ]] || continue
    tools+=("$name")
done
((${#tools[@]})) || die "no tools found in $srcdir"

# Candidates: all tools to install, or only the installed ones to uninstall.
candidates=()
for name in "${tools[@]}"; do
    if [[ $mode == install || -e $bindir/$name ]]; then
        candidates+=("$name")
    fi
done
if ((${#candidates[@]} == 0)); then
    echo "No tools installed in $bindir."
    exit 0
fi

if [[ $mode == install ]]; then
    echo "Tools available to install into $bindir:"
else
    echo "Tools installed in $bindir:"
fi
for i in "${!candidates[@]}"; do
    name=${candidates[i]}
    mark=
    if [[ $mode == install && -e $bindir/$name ]]; then
        mark=" [installed]"
    fi
    printf '  %d) %s%s\n' $((i + 1)) "$name" "$mark"
done

read -r -p "Tools to $mode (numbers separated by spaces, 'a' for all, Enter to cancel): " answer || answer=
if [[ -z ${answer//[[:space:]]/} ]]; then
    echo "Cancelled."
    exit 0
fi

selected=()
if [[ $answer == a || $answer == A ]]; then
    selected=("${candidates[@]}")
else
    for n in $answer; do
        [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#candidates[@]})) || die "invalid selection: $n"
        selected+=("${candidates[n - 1]}")
    done
fi

for name in "${selected[@]}"; do
    if [[ $mode == install ]]; then
        install -D -m 0755 -- "$srcdir/$name" "$bindir/$name" \
            || die "cannot write to $bindir (try sudo)"
        echo "installed $name"
    else
        rm -f -- "$bindir/$name" || die "cannot remove $bindir/$name (try sudo)"
        echo "removed $name"
    fi
done
