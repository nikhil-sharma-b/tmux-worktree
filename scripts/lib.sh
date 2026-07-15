#!/usr/bin/env bash

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmux_worktree_option() {
  local option=$1 fallback=$2 value=''
  if command -v tmux >/dev/null 2>&1; then
    value=$(tmux show-option -gqv "$option" 2>/dev/null || true)
  fi
  printf '%s' "${value:-$fallback}"
}

expand_home() {
  case $1 in
    '~') printf '%s' "$HOME" ;;
    '~/'*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

worktree_roots() {
  local configured root
  configured=${TMUX_WORKTREE_ROOTS:-$(tmux_worktree_option '@worktree-roots' '~/repos')}
  while IFS= read -r root; do
    [[ -n $root ]] && printf '%s\n' "$(expand_home "$root")"
  done < <(printf '%s\n' "$configured" | tr ',' '\n')
}

worktrees_dir() {
  expand_home "${TMUX_WORKTREE_DIR:-$(tmux_worktree_option '@worktree-dir' '~/worktrees')}"
}

cache_dir() {
  printf '%s/tmux-worktree' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

state_dir() {
  printf '%s/tmux-worktree' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

repo_common_dir() {
  git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

repo_type() {
  if [[ $(git -C "$1" rev-parse --is-bare-repository 2>/dev/null) == true ]]; then
    printf 'bare'
  else
    printf 'regular'
  fi
}

repo_name() {
  local name=${1%/}
  name=${name##*/}
  printf '%s' "${name%.git}"
}

repo_key() {
  local common
  common=$(repo_common_dir "$1") || return 1
  printf '%s' "$common" | git hash-object --stdin
}

safe_name() {
  printf '%s' "$1" | tr '/ .:' '----' | tr -cd '[:alnum:]_-'
}

pause_on_error() {
  [[ ${TMUX_WORKTREE_POPUP:-0} == 1 ]] || return 0
  printf '\nPress enter to close...'
  read -r _ || true
}

die() {
  printf 'tmux-worktree: %s\n' "$*" >&2
  pause_on_error
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "requires $1"
}
