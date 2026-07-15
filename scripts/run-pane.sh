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
  startup="$setup; $command"
elif [[ -n $setup ]]; then
  startup=$setup
elif [[ -n $command ]]; then
  startup=$command
else
  exec "$shell" -i
fi

if [[ $shell_name == fish ]]; then
  exec "$shell" -i -C "$startup"
fi

exec "$shell" -lc "$startup; exec \"$shell\" -i"
