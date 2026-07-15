#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

repo=${1:?repository required}
type=$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null || printf false)
[[ $type == true ]] && type=bare || type=regular
head=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')
saved_base=$("$script_dir/state.sh" get "$repo" || true)

printf '\033[34m%s\033[0m\n\n' "${repo##*/}"
printf '\033[90mPath\033[0m     %s\n' "$repo"
printf '\033[90mType\033[0m     %s\n' "$type"
printf '\033[90mHEAD\033[0m     %s\n' "$head"
printf '\033[90mBase\033[0m     %s\n' "${saved_base:-not saved}"
printf '\033[90mWorktrees\033[0m\n'
git -C "$repo" worktree list 2>/dev/null | sed 's/^/  /'
