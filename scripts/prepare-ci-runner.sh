#!/usr/bin/env bash
# Reclaim SDK space only on an ephemeral GitHub-hosted Ubuntu 26.04 runner.
set -euo pipefail
[[ $EUID == 0 && ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted && ${ImageOS:-} == ubuntu26 ]] || {
 echo 'This cleanup is restricted to GitHub-hosted Ubuntu 26.04 runners.' >&2; exit 1;
}
python3 - <<'PY'
import pathlib, shutil
for name in ('/usr/local/lib/android', '/usr/share/dotnet', '/opt/ghc',
             '/usr/local/.ghcup', '/opt/hostedtoolcache', '/home/runner/.rustup'):
    path = pathlib.Path(name)
    if path.is_dir():
        print('Removing unused hosted-runner SDK:', path, flush=True)
        shutil.rmtree(path)
free = shutil.disk_usage('.').free
print(f'Available disk: {free / 2**30:.1f} GiB')
if free < 50 * 2**30:
    raise SystemExit('Need at least 50 GiB free for an image build; use a larger runner if the hosted image has changed.')
PY
