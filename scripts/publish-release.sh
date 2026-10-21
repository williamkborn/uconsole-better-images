#!/usr/bin/env bash
# Run only after a successful build and artifact transfer. No image build token.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GH_REPO:?}" "${GH_TOKEN:?}" "${RELEASE_TAG:?}" "${RELEASE_SHA:?}"
[[ $RELEASE_TAG =~ ^v[0-9][A-Za-z0-9._-]*$ ]] || exit 2
[[ $RELEASE_SHA =~ ^[0-9a-f]{40}$ ]] || exit 2
(cd dist && sha256sum -c SHA256SUMS)
python3 - "$RELEASE_TAG" "$RELEASE_SHA" <<'PY'
import json, pathlib, sys
metadata = json.loads(pathlib.Path('dist/build-metadata.json').read_text())
assert metadata['tag'] == sys.argv[1] and metadata['commit'] == sys.argv[2]
assert metadata['build_profile'] == 'release'
PY
# Refuse a tag moved since the build started. Prefer the peeled annotated tag.
remote=$(git ls-remote origin "refs/tags/$RELEASE_TAG" "refs/tags/$RELEASE_TAG^{}")
actual=$(printf '%s\n' "$remote" | awk '/\^\{\}$/ {peeled=$1; next} {direct=$1} END {print peeled ? peeled : direct}')
[[ $actual == "$RELEASE_SHA" ]] || { echo 'Remote tag changed or disappeared' >&2; exit 1; }
if gh release view "$RELEASE_TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
 echo 'Release already exists. Published releases are never overwritten; remove an incomplete draft explicitly before retrying.' >&2
 exit 1
fi
gh release create "$RELEASE_TAG" --repo "$GH_REPO" --verify-tag --draft \
 --title "uConsole CM4 Ubuntu 26.04 — $RELEASE_TAG" --notes-file dist/release-notes.md
gh release upload "$RELEASE_TAG" dist/* --repo "$GH_REPO"
gh release edit "$RELEASE_TAG" --repo "$GH_REPO" --draft=false
