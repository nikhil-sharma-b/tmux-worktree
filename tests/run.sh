#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_tmux=$(command -v tmux)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-worktree-test.XXXXXX")
socket="worktree-test-$$"

cleanup() {
  "$real_tmux" -L "$socket" kill-server 2>/dev/null || true
  for _ in 1 2 3; do
    rm -rf "$tmp_dir" 2>/dev/null && return
    sleep 0.1
  done
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

export HOME="$tmp_dir/home"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_STATE_HOME="$tmp_dir/state"
export TMUX_WORKTREE_ROOTS="$tmp_dir/repos"
export TMUX_WORKTREE_DIR="$tmp_dir/worktrees"
export TMUX_TEST_SOCKET=$socket
export TMUX_CALL_LOG="$tmp_dir/tmux-calls"
export REAL_TMUX=$real_tmux
export PATH="$repo_dir/tests/bin:$PATH"
mkdir -p "$HOME" "$TMUX_WORKTREE_ROOTS"
: >"$TMUX_CALL_LOG"

regular="$TMUX_WORKTREE_ROOTS/regular project"
mkdir -p "$regular/apps/api"
git -C "$TMUX_WORKTREE_ROOTS" init -q -b main "regular project"
git -C "$regular" config user.name Test
git -C "$regular" config user.email test@example.com
printf '{"name":"fixture"}\n' >"$regular/package.json"
printf 'tracked\n' >"$regular/README.md"
git -C "$regular" add package.json README.md
git -C "$regular" commit -qm initial
printf 'TOKEN=one\n' >"$regular/.env"
printf 'API_TOKEN=two\n' >"$regular/apps/api/.env.local"
printf 'example\n' >"$regular/.env.example"

bare="$TMUX_WORKTREE_ROOTS/bare.git"
git clone -q --bare "$regular" "$bare"
mkdir -p "$bare/envs/apps/api"
printf 'BARE=one\n' >"$bare/envs/.env"
printf 'NESTED=two\n' >"$bare/envs/apps/api/.env"

discovery=$("$repo_dir/scripts/discover.sh" refresh)
[[ $discovery == *"$regular"* ]] || fail 'regular repository not discovered'
[[ $discovery == *"$bare"* ]] || fail 'bare repository not discovered'

"$repo_dir/scripts/state.sh" set "$regular" main
[[ $("$repo_dir/scripts/state.sh" get "$regular") == main ]] || fail 'default base not persisted'
"$repo_dir/scripts/state.sh" clear "$regular"
[[ -z $("$repo_dir/scripts/state.sh" get "$regular") ]] || fail 'default base not cleared'

"$repo_dir/bin/tmux-worktree" create \
  --repo "$regular" \
  --base main \
  --branch feature/test \
  --editor-command ':' \
  --no-switch

regular_worktree="$TMUX_WORKTREE_DIR/regular project/feature-test"
[[ -L "$regular_worktree/.env" ]] || fail 'root env file not linked'
[[ -L "$regular_worktree/apps/api/.env.local" ]] || fail 'nested env file not linked'
[[ ! -e "$regular_worktree/.env.example" ]] || fail 'example env file linked'
[[ $(readlink "$regular_worktree/.env") == "$regular/.env" ]] || fail 'env link source incorrect'

windows=$(tmux list-windows -t '=regular-project-feature-test' -F '#{window_name}')
[[ $windows == *edit* && $windows == *shell* ]] || fail 'expected edit and shell windows'
panes=$(tmux list-panes -a -t '=regular-project-feature-test' -F '#{pane_id}' | wc -l)
[[ $panes == 3 ]] || fail "expected 3 panes, got $panes"
grep -q 'fnm\\ use.*:' "$TMUX_CALL_LOG" || fail 'fnm setup did not precede editor command'

"$repo_dir/bin/tmux-worktree" create \
  --repo "$bare" \
  --base main \
  --branch bare-feature \
  --editor-command ':' \
  --no-switch

bare_worktree="$TMUX_WORKTREE_DIR/bare/bare-feature"
[[ -L "$bare_worktree/.env" ]] || fail 'bare root env file not linked'
[[ -L "$bare_worktree/apps/api/.env" ]] || fail 'bare nested env file not linked'
[[ $(readlink "$bare_worktree/apps/api/.env") == "$bare/envs/apps/api/.env" ]] || fail 'bare env link source incorrect'

"$repo_dir/tmux-worktree.tmux"
binding=$(tmux list-keys -T prefix W)
[[ $binding == *display-popup* && $binding == *'-d /'* ]] || fail 'plugin popup binding incorrect'

for script in "$repo_dir"/*.tmux "$repo_dir"/bin/* "$repo_dir"/scripts/*.sh "$repo_dir"/tests/*.sh "$repo_dir"/tests/bin/*; do
  bash -n "$script" || fail "syntax error in $script"
done

printf 'PASS: discovery, state, regular/bare worktrees, env links, tmux layout, fnm, binding, syntax\n'
