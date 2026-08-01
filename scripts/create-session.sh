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
no_editor=${6:-0}

if tmux has-session -t "=$session" 2>/dev/null; then
  printf '%s\n' "$session"
  exit 0
fi

pane_runner="$script_dir/run-pane.sh"
# Without an editor the main window is a single pane running the right command,
# so callers that only want one program get exactly that.
if [[ $no_editor == 1 ]]; then
  main_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$worktree" -n main \
    -e "TMUX_WORKTREE_PANE_COMMAND=$right_command" "$pane_runner")
else
  main_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -c "$worktree" -n edit \
    -e "TMUX_WORKTREE_PANE_COMMAND=$editor_command" "$pane_runner")
  tmux split-window -h -t "$main_pane" -c "$worktree" \
    -e "TMUX_WORKTREE_PANE_COMMAND=$right_command" "$pane_runner"
fi
tmux new-window -d -t "=$session:" -c "$worktree" -n shell \
  -e "TMUX_WORKTREE_PANE_COMMAND=$shell_command" "$pane_runner"

tmux select-window -t "$main_pane"
tmux select-pane -t "$main_pane"
printf '%s\n' "$session"
