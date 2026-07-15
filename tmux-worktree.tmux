#!/usr/bin/env bash

set -eu

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux_option() {
  local option=$1 fallback=$2 value
  value=$(tmux show-option -gqv "$option")
  printf '%s' "${value:-$fallback}"
}

key=$(tmux_option '@worktree-key' 'W')
width=$(tmux_option '@worktree-width' '80%')
height=$(tmux_option '@worktree-height' '70%')
border=$(tmux_option '@worktree-border-style' 'fg=brightblack')
title=$(tmux_option '@worktree-title' '')

tmux bind-key "$key" display-popup -T "$title" -E \
  -d / \
  -w "$width" \
  -h "$height" \
  -b rounded \
  -S "$border" \
  "TMUX_WORKTREE_POPUP=1 '$plugin_dir/bin/tmux-worktree' pick"
