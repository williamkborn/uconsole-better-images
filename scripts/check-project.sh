#!/usr/bin/env bash
# Fast, read-only checks. Never build an image or write a disk.
set -euo pipefail
cd "$(dirname "$0")/.."
for script in scripts/*.sh; do bash -n "$script"; done
python3 - <<'PY'
import json
import pathlib
import re
import subprocess

project = pathlib.Path.cwd()
for path in (project / 'scripts').glob('*.py'):
    compile(path.read_text(), str(path), 'exec')
for path in [project / 'sources.lock.json', *(project / 'config').glob('*.json')]:
    json.loads(path.read_text())
artifacts = json.loads((project / 'sources.lock.json').read_text())['artifacts']
assert len({a['path'] for a in artifacts}) == len(artifacts)
for item in artifacts:
    assert re.fullmatch(r'[0-9a-f]{64}', item['sha256'])
    assert not pathlib.PurePosixPath(item['path']).is_absolute()
    assert '..' not in pathlib.PurePosixPath(item['path']).parts
for name in ('README.md', 'docs/BUILDING.md', 'docs/VALIDATION.md',
             'docs/THIRD-PARTY.md', 'patches/clockworkpi-6.12.patch',
             'config/vendor-elf-dependencies.json', 'config/assets.json'):
    assert (project / name).is_file(), name
for args, expected in [([], 2), (['--help'], 0), (['--device'], 2), (['--invalid'], 2)]:
    result = subprocess.run(['bash', 'scripts/flash-image.sh', *args], capture_output=True, text=True)
    assert result.returncode == expected, (args, result.stderr)
print('Project syntax, inputs, required files and flash argument guards passed.')
PY
