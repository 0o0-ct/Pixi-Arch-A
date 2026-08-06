#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -t 1 ]]; then
  BOLD="$(tput bold || true)"
  DIM="$(tput dim || true)"
  RED="$(tput setaf 1 || true)"
  GREEN="$(tput setaf 2 || true)"
  YELLOW="$(tput setaf 3 || true)"
  BLUE="$(tput setaf 4 || true)"
  RESET="$(tput sgr0 || true)"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

log() { printf "%b\n" "${BLUE}==>${RESET} $*"; }
ok() { printf "%b\n" "${GREEN}✔${RESET} $*"; }
warn() { printf "%b\n" "${YELLOW}⚠${RESET} $*"; }
err() { printf "%b\n" "${RED}✖${RESET} $*"; }

log "${BOLD}Hyprland-Dots updater${RESET}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Not inside a git repository."
  exit 1
fi

branch="main"

log "Forcing branch: ${BOLD}${branch}${RESET}"
git checkout -B "$branch" 2>/dev/null || git switch "$branch" 2>/dev/null || true

log "Fetching remote updates..."
git fetch origin "$branch":refs/remotes/origin/"$branch" --tags --quiet

upstream="origin/${branch}"
if ! git show-ref --verify --quiet "refs/remotes/${upstream}"; then
  err "No remote branch '${upstream}' found."
  exit 1
fi

log "Current branch: ${BOLD}${branch}${RESET}"
log "Upstream: ${BOLD}${upstream}${RESET}"

behind_count="$(git rev-list --count "HEAD..${upstream}")"
ahead_count="$(git rev-list --count "${upstream}..HEAD")"

if [[ "$behind_count" -eq 0 ]]; then
  ok "Already up to date with ${upstream}."
  if [[ "$ahead_count" -gt 0 ]]; then
    warn "Local branch is ahead by ${ahead_count} commit(s)."
  fi
  exit 0
fi

warn "Updates available: behind by ${behind_count} commit(s)."
read -r -p "Update now? [y/N] " reply
case "${reply:-}" in
  y|Y|yes|YES)
    log "Pulling latest changes from ${upstream}..."
    git reset --hard "${upstream}"

    ok "Update complete."
    printf "%b\n" "${DIM}Next: run ./copy.sh to upgrade the Hyprland dotfiles.${RESET}"
    ;;
  *)
    warn "Update cancelled."
    ;;
esac
