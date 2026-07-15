# tmux-worktree

Fast Git worktree session creator for tmux. It supports regular and bare repositories, remembers a base branch per repository, links environment files, and opens a consistent two-window development layout.

The popup matches the visual language and controls of [tmux-session-finder](https://github.com/nikhil-sharma-b/tmux-session-finder).

## Requirements

- tmux 3.2 or newer
- Git
- Bash
- fzf
- `fnm` is optional

## Install with TPM

```tmux
set -g @plugin 'nikhil-sharma-b/tmux-worktree'
```

For a local checkout:

```tmux
run-shell '~/repos/tmux-worktree/tmux-worktree.tmux'
```

Reload tmux, then press `prefix + W`.

## Workflow

1. Select a cached repository. Press `Ctrl-r` to rebuild the cache or `Ctrl-b` to select a base instead of using the saved default.
2. Select a base branch. Press `Ctrl-d` to save it as that repository's default.
3. Type a new branch name or select an existing branch to reopen it.
4. The plugin creates or reuses the worktree and switches to its tmux session.

The session contains:

- `edit`: `nvim .` in the left pane and a shell in the right pane.
- `shell`: one full-window shell.

For Node projects, each pane runs `fnm use` before its configured command.

## Configuration

Set options before loading the plugin:

```tmux
set -g @worktree-key 'W'
set -g @worktree-width '80%'
set -g @worktree-height '70%'
set -g @worktree-border-style 'fg=brightblack'
set -g @worktree-title ''
set -g @worktree-roots '~/repos,~/src'
set -g @worktree-scan-depth '4'
set -g @worktree-list-linked-worktrees 'off'
set -g @worktree-dir '~/worktrees'
set -g @worktree-env-patterns '.env,.env.*'
set -g @worktree-editor-command 'nvim .'
```

Repository discovery uses an XDG cache. Opening the picker reads only that cache; `Ctrl-r` performs the filesystem scan. The first opening builds the cache when none exists.

Linked worktrees are excluded by default. This prevents every worktree belonging to a bare or regular repository from appearing as another repository. Set `@worktree-list-linked-worktrees` to `on` to include them, then press `Ctrl-r` in the picker.

For indexed global discovery, provide a command that prints one repository path per line. It runs only while refreshing the cache:

```tmux
set -g @worktree-discovery-command "plocate -r '/\\.git$'"
```

## Environment Files

For regular repositories, matching files are linked from the selected primary checkout while preserving relative paths. Files ending in `.example`, `.sample`, or `.template` are excluded. Existing worktree files are never replaced.

For a bare repository, every file under its `envs` directory is linked into the worktree with the same relative path:

```text
project.git/envs/.env          -> worktree/.env
project.git/envs/apps/api/.env -> worktree/apps/api/.env
```

## CLI and Wrappers

The popup and wrappers share one command:

```sh
~/repos/tmux-worktree/bin/tmux-worktree create \
  --repo ~/repos/project \
  --base main \
  --branch review-pr-123 \
  --right-command "claude 'Review GitHub PR #123 using gh pr diff 123'"
```

Available options:

```text
--repo PATH|CACHED_NAME
--base REF
--branch NAME
--choose-base
--editor-command COMMAND
--right-command COMMAND
--shell-command COMMAND
--no-switch
```

Omitted repo, base, or branch values are selected interactively. Pane commands are trusted shell input intended for local wrappers.

Refresh repository cache without opening tmux:

```sh
~/repos/tmux-worktree/bin/tmux-worktree refresh
```

## Test

Tests use temporary regular and bare repositories plus an isolated tmux server:

```sh
./tests/run.sh
```
