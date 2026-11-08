#!/usr/bin/env bash
# Publish the Markdown sources in wiki/ to the repository's GitHub Wiki.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-SilverCrow2323/dolphin-rt-core}"
WIKI_URL="https://github.com/$REPO.wiki.git"
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is required; run gh auth login first" >&2; exit 1; }
gh auth status >/dev/null
gh auth setup-git >/dev/null
# Initialise the Wiki feature if it has not been enabled yet.
gh repo edit "$REPO" --enable-wiki
[[ -d "$ROOT/wiki" ]] || { echo "Missing wiki/ source directory" >&2; exit 1; }
git clone "$WIKI_URL" "$TMP/wiki"
find "$ROOT/wiki" -maxdepth 1 -type f -name '*.md' -exec cp {} "$TMP/wiki/" \;
cd "$TMP/wiki"
git add -- '*.md'
if git diff --cached --quiet; then
  echo "Wiki is already up to date."
  exit 0
fi
git -c user.name="Dolphin Rt:Core Docs" -c user.email="docs-bot@users.noreply.github.com" commit -m "docs: sync repository wiki"
git push origin HEAD
echo "Published Wiki pages from $ROOT/wiki"
