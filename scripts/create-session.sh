#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

session=${1:?session required}
worktree=${2:?worktree required}
editor_command=${3:-nvim .}
right_command=${4:-}
shell_command=${5:-}

if tmux has-session -t "=$session" 2>/dev/null; then
  printf '%s\n' "$session"
  exit 0
fi

node_setup=''
if [[ -f $worktree/package.json || -f $worktree/.node-version || -f $worktree/.nvmrc ]]; then
  node_setup='if command -v fnm >/dev/null 2>&1; then fnm use; fi'
fi

with_node() {
  local command=$1
  if [[ -n $node_setup && -n $command ]]; then
    printf '%s; %s' "$node_setup" "$command"
  elif [[ -n $node_setup ]]; then
    printf '%s' "$node_setup"
  else
    printf '%s' "$command"
  fi
}

left_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$worktree" -n edit)
right_pane=$(tmux split-window -h -P -F '#{pane_id}' -t "$left_pane" -c "$worktree")
shell_pane=$(tmux new-window -d -P -F '#{pane_id}' -t "=$session:" -c "$worktree" -n shell)

tmux send-keys -t "$left_pane" "$(with_node "$editor_command")" C-m
if [[ -n $right_command || -n $node_setup ]]; then
  tmux send-keys -t "$right_pane" "$(with_node "$right_command")" C-m
fi
if [[ -n $shell_command || -n $node_setup ]]; then
  tmux send-keys -t "$shell_pane" "$(with_node "$shell_command")" C-m
fi

tmux select-window -t "$left_pane"
tmux select-pane -t "$left_pane"
printf '%s\n' "$session"
