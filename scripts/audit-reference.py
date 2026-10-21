#!/usr/bin/env python3
"""Inventory vendor-owned files and changed/unowned system configuration."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2])
owned = {}
expected = {}
info = root / 'var/lib/dpkg/info'
for listing in info.glob('*.list'):
    for name in listing.read_text(errors='replace').splitlines():
        owned[name.lstrip('/')] = listing.name[:-5]
for listing in info.glob('*.md5sums'):
    for line in listing.read_text(errors='replace').splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            expected[parts[1]] = parts[0]
# dpkg records conffile baseline hashes separately from md5sums.
for paragraph in (root / 'var/lib/dpkg/status').read_text().split('\n\n'):
    conffiles = False
    for line in paragraph.splitlines():
        if line == 'Conffiles:':
            conffiles = True
        elif conffiles and line.startswith(' '):
            fields = line.split()
            if len(fields) >= 2:
                expected[fields[0].lstrip('/')] = fields[1]
        else:
            conffiles = False
records = []
for base in ('etc', 'usr/local', 'opt'):
    for path in sorted((root / base).rglob('*')):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(root).as_posix()
        # Account credentials and host identity are not reusable customizations.
        if rel in ('etc/shadow', 'etc/gshadow', 'etc/machine-id') or rel.startswith('etc/ssh/ssh_host_'):
            continue
        data = path.read_bytes()
        md5 = hashlib.md5(data).hexdigest()
        owner = owned.get(rel)
        vendor = owner and any(word in owner for word in ('uconsole', 'devterm', 'clockwork'))
        if vendor or not owner or expected.get(rel) != md5:
            records.append(dict(path=rel, package=owner, md5=md5,
                                sha256=hashlib.sha256(data).hexdigest(),
                                state='vendor' if vendor else 'unowned' if not owner else 'changed-or-conffile'))
output.write_text(json.dumps(records, indent=2) + '\n')
print(f'{len(records)} candidate custom files: {output}')
