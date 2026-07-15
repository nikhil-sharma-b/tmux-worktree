#!/usr/bin/env bash

set -euo pipefail

shell=${SHELL:-/bin/sh}
shell_name=${shell##*/}
command=${TMUX_WORKTREE_PANE_COMMAND:-}
setup=''

if [[ -f package.json || -f .node-version || -f .nvmrc ]]; then
  if [[ $shell_name == fish ]]; then
    setup='if type -q fnm; fnm use; end'
  else
    setup='if command -v fnm >/dev/null 2>&1; then fnm use; fi'
  fi
fi

if [[ -n $setup && -n $command ]]; then
  startup="$setup; $command; exec \"$shell\" -i"
elif [[ -n $setup ]]; then
  startup="$setup; exec \"$shell\" -i"
elif [[ -n $command ]]; then
  startup="$command; exec \"$shell\" -i"
else
  exec "$shell" -i
fi

exec "$shell" -lc "$startup"
