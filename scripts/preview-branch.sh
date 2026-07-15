#!/usr/bin/env bash

set -euo pipefail

repo=${1:?repository required}
branch=${2:-}
[[ -n $branch ]] || exit 0

ref=$branch
git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || ref="origin/$branch"

git -C "$repo" log -1 --date=relative \
  --format=$'\033[34m%h\033[0m  %s%n%n\033[90mAuthor\033[0m  %an%n\033[90mAge\033[0m     %ar%n\033[90mRef\033[0m     %D' \
  "$ref" 2>/dev/null || true
