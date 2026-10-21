#!/usr/bin/env python3
"""Retrieve exactly the locked input artifacts, verifying existing files too."""
import hashlib
import json
import pathlib
import subprocess

project = pathlib.Path(__file__).resolve().parent.parent
for item in json.loads((project / 'sources.lock.json').read_text())['artifacts']:
    target = project / 'downloads' / item['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    candidate = target
    if not target.exists():
        candidate = target.with_name(target.name + '.partial')
        subprocess.run(['curl', '-fL', '--retry', '3', item['url'], '-o', str(candidate)], check=True)
    with candidate.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != item['sha256']:
        raise RuntimeError(f'Checksum mismatch: {target}; remove the corrupt file and rerun')
    if candidate != target:
        candidate.replace(target)
    print(item['path'], 'OK', flush=True)
