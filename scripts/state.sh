#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

action=${1:?action required}
repo=${2:?repository required}
key=$(repo_key "$repo")
defaults_dir="$(state_dir)/defaults"
file="$defaults_dir/$key"

case $action in
  get)
    [[ -f $file ]] && IFS= read -r base <"$file" && printf '%s\n' "$base"
    ;;
  set)
    base=${3:?base branch required}
    mkdir -p "$defaults_dir"
    printf '%s\n' "$base" >"$file"
    ;;
  clear)
    rm -f "$file"
    ;;
  *) die "unknown state action: $action" ;;
esac
