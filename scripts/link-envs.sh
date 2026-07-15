#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

repo=${1:?repository required}
worktree=${2:?worktree required}
type=$(repo_type "$repo")
patterns=${TMUX_WORKTREE_ENV_PATTERNS:-$(tmux_worktree_option '@worktree-env-patterns' '.env,.env.*')}

if [[ $type == bare ]]; then
  source_dir="$(repo_common_dir "$repo")/envs"
  patterns='*'
else
  source_dir=$(git -C "$repo" rev-parse --show-toplevel)
fi

[[ -d $source_dir ]] || exit 0

matches_pattern() {
  local relative=$1 basename pattern
  basename=${relative##*/}
  while IFS= read -r pattern; do
    [[ $basename == $pattern || $relative == $pattern ]] && return 0
  done < <(printf '%s\n' "$patterns" | tr ',' '\n')
  return 1
}

excluded() {
  case $1 in
    *.example|*.sample|*.template) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r -d '' source_file; do
  relative=${source_file#"$source_dir"/}
  matches_pattern "$relative" || continue
  [[ $type == bare ]] || ! excluded "$relative" || continue

  target="$worktree/$relative"
  if [[ -e $target || -L $target ]]; then
    if [[ -L $target && $(readlink "$target") == "$source_file" ]]; then
      continue
    fi
    printf 'tmux-worktree: env target exists, skipped: %s\n' "$target" >&2
    continue
  fi

  mkdir -p "${target%/*}"
  ln -s "$source_file" "$target"
done < <(find "$source_dir" \
  \( -name .git -o -name node_modules \) -prune -o \
  \( -type f -o -type l \) -print0 2>/dev/null)
