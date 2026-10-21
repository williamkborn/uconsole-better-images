#!/usr/bin/env python3
"""Check extracted vendor payloads against the audited file hashes."""
import hashlib
import json
import pathlib
import sys
import tarfile

project = pathlib.Path(__file__).resolve().parent.parent
assets = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else project / 'assets'
for name, expected in json.loads((project / 'config/assets.json').read_text()).items():
    path = assets / name
    if isinstance(expected, str):
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        with tarfile.open(path) as archive:
            actual = {}
            for member in archive:
                if member.name.startswith('/') or '..' in pathlib.PurePosixPath(member.name).parts:
                    raise RuntimeError(f'Unsafe archive member: {member.name}')
                if member.isdir():
                    continue
                if not (member.isfile() or member.issym()):
                    raise RuntimeError(f'Unsafe archive member: {member.name}')
                if member.name in actual:
                    raise RuntimeError(f'Duplicate archive member: {member.name}')
                if member.issym():
                    if member.linkname.startswith('/') or '..' in pathlib.PurePosixPath(member.linkname).parts:
                        raise RuntimeError(f'Unsafe link: {member.name}')
                    actual[member.name] = {'symlink': member.linkname}
                else:
                    actual[member.name] = hashlib.sha256(archive.extractfile(member).read()).hexdigest()
    if actual != expected:
        raise RuntimeError(f'Vendor asset mismatch: {name}')
    print(name, 'OK')
