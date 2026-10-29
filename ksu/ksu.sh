#!/usr/bin/env bash
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$outside/ksu/setup_bakasu.sh"
bash "$outside/configs/select-bakasu-hooks.sh" manual
bash "$outside/ksu/apply_hooks.sh"
version="$(git -C KernelSU rev-parse --short HEAD)"
printf '\nIncludes BakaSU (%s), without SUSFS\n' "$version" >> banner_append
