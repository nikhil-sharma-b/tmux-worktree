#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

action=${1:-list}
cache_file="$(cache_dir)/repos"
list_linked_worktrees=off

emit_repo() {
  local candidate=$1 common git_dir type display_type name
  common=$(repo_common_dir "$candidate") || return 0
  type=$(repo_type "$candidate")
  if [[ $type == bare ]]; then
    candidate=$common
    display_type=bare
  else
    git_dir=$(git -C "$candidate" rev-parse --path-format=absolute --git-dir 2>/dev/null) || return 0
    if [[ $git_dir != "$common" ]]; then
      case $list_linked_worktrees in
        1|on|true|yes) ;;
        *) return 0 ;;
      esac
      display_type=worktree
    else
      display_type=regular
    fi
    candidate=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null) || return 0
  fi
  name=$(repo_name "$candidate")
  printf '%s\t%-28s \033[90m%s · %s\033[0m\n' "$candidate" "$name" "$display_type" "$candidate"
}

refresh() {
  local custom depth root candidate tmp
  depth=${TMUX_WORKTREE_SCAN_DEPTH:-$(tmux_worktree_option '@worktree-scan-depth' '4')}
  custom=${TMUX_WORKTREE_DISCOVERY_COMMAND:-$(tmux_worktree_option '@worktree-discovery-command' '')}
  list_linked_worktrees=${TMUX_WORKTREE_LIST_LINKED_WORKTREES:-$(tmux_worktree_option '@worktree-list-linked-worktrees' 'off')}
  mkdir -p "$(cache_dir)"
  tmp="$cache_file.tmp.$$"
  : >"$tmp"

  if [[ -n $custom ]]; then
    while IFS= read -r candidate; do
      [[ -n $candidate ]] || continue
      candidate=$(expand_home "$candidate")
      [[ ${candidate##*/} == .git ]] && candidate=${candidate%/.git}
      emit_repo "$candidate" >>"$tmp"
    done < <(bash -c "$custom")
  else
    while IFS= read -r root; do
      [[ -d $root ]] || continue
      while IFS= read -r candidate; do
        if [[ ${candidate##*/} == .git ]]; then
          candidate=${candidate%/.git}
        fi
        emit_repo "$candidate" >>"$tmp"
      done < <(find "$root" -mindepth 1 -maxdepth "$depth" \
        \( -name .git -o -name '*.git' \) -print 2>/dev/null)

      while IFS= read -r candidate; do
        [[ $(repo_type "$candidate" 2>/dev/null || true) == bare ]] && emit_repo "$candidate" >>"$tmp"
      done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null)
    done < <(worktree_roots)
  fi

  awk -F '\t' '!seen[$1]++' "$tmp" | sort -f -t $'\t' -k2,2 >"$cache_file"
  rm -f "$tmp"
  cat "$cache_file"
}

case $action in
  refresh) refresh ;;
  list)
    if [[ -s $cache_file ]]; then
      cat "$cache_file"
    else
      refresh
    fi
    ;;
  *) die "unknown discovery action: $action" ;;
esac
