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
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$tmp_dir/state"
export TMUX_WORKTREE_ROOTS="$tmp_dir/repos"
export TMUX_WORKTREE_DIR="$tmp_dir/worktrees"
export TMUX_TEST_SOCKET=$socket
export TMUX_CALL_LOG="$tmp_dir/tmux-calls"
export FNM_CALL_LOG="$tmp_dir/fnm-calls"
export REAL_TMUX=$real_tmux
export PATH="$repo_dir/tests/bin:$PATH"
export SHELL
SHELL=$(command -v fish)
mkdir -p "$HOME/.config/fish" "$TMUX_WORKTREE_ROOTS"
: >"$TMUX_CALL_LOG"
: >"$FNM_CALL_LOG"

printf '%s\n' \
  'set -gx TEST_NODE_VERSION default' \
  'function fnm' \
  '  set -gx TEST_NODE_VERSION project' \
  '  printf "use\\n" >> "$FNM_CALL_LOG"' \
  'end' >"$HOME/.config/fish/config.fish"

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

regular_linked="$TMUX_WORKTREE_ROOTS/regular-linked"
bare_linked="$TMUX_WORKTREE_ROOTS/bare-linked"
git -C "$regular" worktree add -q -b regular-linked "$regular_linked" main
git -C "$bare" worktree add -q -b bare-linked "$bare_linked" main

discovery=$("$repo_dir/scripts/discover.sh" refresh)
[[ $discovery == *"$regular"* ]] || fail 'regular repository not discovered'
[[ $discovery == *"$bare"* ]] || fail 'bare repository not discovered'
[[ $discovery != *"$regular_linked"* ]] || fail 'regular linked worktree discovered by default'
[[ $discovery != *"$bare_linked"* ]] || fail 'bare linked worktree discovered by default'

export TMUX_WORKTREE_LIST_LINKED_WORKTREES=on
discovery=$("$repo_dir/scripts/discover.sh" refresh)
[[ $discovery == *"$regular_linked"* ]] || fail 'regular linked worktree missing when enabled'
[[ $discovery == *"$bare_linked"* ]] || fail 'bare linked worktree missing when enabled'
unset TMUX_WORKTREE_LIST_LINKED_WORKTREES
"$repo_dir/scripts/discover.sh" refresh >/dev/null

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
for _ in 1 2 3 4 5; do
  [[ $(wc -l <"$FNM_CALL_LOG") == 3 ]] && break
  sleep 0.1
done
[[ $(wc -l <"$FNM_CALL_LOG") == 3 ]] || fail 'fnm setup did not run in every pane'
grep -q 'TMUX_WORKTREE_PANE_COMMAND=:' "$TMUX_CALL_LOG" || fail 'editor command not passed to pane runner'

right_pane=$(tmux list-panes -t '=regular-project-feature-test:edit' -F '#{pane_id}' | sed -n '2p')
tmux send-keys -t "$right_pane" "printf '%s' \"\$TEST_NODE_VERSION\" > '$tmp_dir/node-version'" C-m
for _ in 1 2 3 4 5; do
  [[ -f $tmp_dir/node-version ]] && break
  sleep 0.1
done
[[ $(<"$tmp_dir/node-version") == project ]] || fail 'fnm environment did not persist in interactive shell'

# fzf exits 1 when a new query matches no existing branch. The query must still
# proceed to worktree creation instead of being mistaken for cancellation.
mkdir -p "$tmp_dir/query-test-bin"
printf '#!/usr/bin/env bash\nprintf "brand-new\\n"\nexit 1\n' >"$tmp_dir/query-test-bin/fzf"
chmod +x "$tmp_dir/query-test-bin/fzf"
PATH="$tmp_dir/query-test-bin:$PATH" "$repo_dir/bin/tmux-worktree" create \
  --repo "$regular" \
  --base main \
  --editor-command ':' \
  --no-switch
[[ -d "$TMUX_WORKTREE_DIR/regular project/brand-new" ]] || fail 'unmatched fzf query did not create worktree'

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
