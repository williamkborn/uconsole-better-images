#!/usr/bin/env python3
"""Package only a verified release-profile image; keep every asset below 2 GiB."""
import contextlib
import datetime
import hashlib
import io
import json
import lzma
import os
import pathlib
import re
import shutil
import subprocess

PROJECT = pathlib.Path(__file__).resolve().parent.parent
ASSET_LIMIT = 1900 * 1024 * 1024


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def split_stream(stream, prefix, limit=ASSET_LIMIT):
    if limit <= 0:
        raise ValueError('Asset size limit must be positive')
    paths = []
    with contextlib.ExitStack() as stack:
        output = None
        written = 0
        while chunk := stream.read(1024 * 1024):
            offset = 0
            while offset < len(chunk):
                if output is None or written == limit:
                    if output is not None:
                        output.close()
                    path = prefix.with_name(prefix.name + f'.part-{len(paths):03d}')
                    paths.append(path)
                    output = stack.enter_context(path.open('xb'))
                    written = 0
                amount = min(limit - written, len(chunk) - offset)
                output.write(chunk[offset:offset + amount])
                offset += amount
                written += amount
    if len(paths) == 1:
        paths[0].rename(prefix)
        paths = [prefix]
    if not paths:
        raise RuntimeError('Compressor produced no data')
    return paths


class JoinedReader(io.RawIOBase):
    def __init__(self, paths):
        self.paths = iter(paths)
        self.current = None

    def readable(self):
        return True

    def readinto(self, buffer):
        while True:
            if self.current is None:
                path = next(self.paths, None)
                if path is None:
                    return 0
                self.current = path.open('rb')
            count = self.current.readinto(buffer)
            if count:
                return count
            self.current.close()
            self.current = None

    def close(self):
        if self.current is not None:
            self.current.close()
        super().close()


def verify_compressed(paths, expected_hash, expected_size):
    checksum = hashlib.sha256()
    size = 0
    with io.BufferedReader(JoinedReader(paths)) as joined, lzma.LZMAFile(joined) as raw:
        while chunk := raw.read(1024 * 1024):
            size += len(chunk)
            if size > expected_size:
                raise RuntimeError('Decompressed image is larger than expected')
            checksum.update(chunk)
    if size != expected_size or checksum.hexdigest() != expected_hash:
        raise RuntimeError('Compressed image roundtrip does not match the verified image')


def git(repo, *args):
    return subprocess.check_output(['git', '-c', 'safe.directory=' + str(repo.resolve()), '-C', str(repo), *args], text=True).strip()


def main():
    tag = os.environ['RELEASE_TAG']
    if not re.fullmatch(r'v[0-9][A-Za-z0-9._-]*', tag):
        raise RuntimeError('Expected an existing version tag starting with v and a digit')
    image = PROJECT.parent / 'ub2604_uconsole.img'
    report = json.loads((PROJECT / 'docs/root-verification.json').read_text())
    if report.get('build_profile') != 'release' or 'Release excludes proprietary Tyrian data' not in report['checks']:
        raise RuntimeError('Only a verified release-profile image may be published')
    expected = (PROJECT / 'docs/image.sha256').read_text().split()[0]
    if digest(image) != expected:
        raise RuntimeError('Image differs from the filesystem-verified build')
    commit = git(PROJECT, 'rev-parse', 'HEAD')
    if git(PROJECT, 'rev-parse', f'refs/tags/{tag}^{{commit}}') != commit:
        raise RuntimeError('Release tag does not identify this checkout')
    git(PROJECT, 'diff', '--exit-code', 'HEAD')
    output = PROJECT / 'dist'
    output.mkdir(exist_ok=True)
    if any(output.iterdir()):
        raise RuntimeError('dist/ must be empty to avoid stale release assets')
    with subprocess.Popen(['xz', '-T2', '-6', '-c', str(image)], stdout=subprocess.PIPE) as compressor:
        parts = split_stream(compressor.stdout, output / (image.name + '.xz'))
        if compressor.wait() != 0:
            raise RuntimeError('Image compression failed')
    verify_compressed(parts, expected, image.stat().st_size)

    # Include the exact patched kernel sources, not just the unmodified upstream tag.
    kernel = PROJECT / 'sources/clockworkpi-linux'
    git(kernel, 'diff', '--exit-code')
    tree = git(kernel, 'write-tree')
    with (output / 'kernel-source.tar.xz').open('xb') as target:
        with subprocess.Popen(['xz', '-T2', '-6'], stdin=subprocess.PIPE, stdout=target) as compressor:
            result = subprocess.run(['git', '-c', 'safe.directory=' + str(kernel.resolve()), '-C', str(kernel), 'archive', '--format=tar',
                                     '--prefix=linux-uconsole/', tree], stdout=compressor.stdin)
            compressor.stdin.close()
            status = compressor.wait()
            result.check_returncode()
            if status != 0:
                raise RuntimeError('Kernel source compression failed')
    shutil.copyfile(PROJECT / 'build/kernel/.config', output / 'kernel.config')
    for filename in ('installed-packages.tsv', 'root-verification.json',
                     'final-upgrade-check.txt', 'hardware-helper-tests.txt'):
        shutil.copyfile(PROJECT / 'docs' / filename, output / filename)
    shutil.copyfile(PROJECT / 'sources.lock.json', output / 'sources.lock.json')
    (output / 'IMAGE-SHA256SUMS').write_text(f'{expected}  {image.name}\n')
    metadata = dict(tag=tag, commit=commit, kernel_source_tree=tree,
                    kernel=report['kernel'], build_profile='release',
                    image_sha256=expected, image_bytes=image.stat().st_size,
                    image_assets=[p.name for p in parts],
                    built_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    run_url=f"https://github.com/{os.environ.get('GITHUB_REPOSITORY', '')}/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}")
    (output / 'build-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    unpack = ('xz -dk ub2604_uconsole.img.xz' if len(parts) == 1 else
              'cat ub2604_uconsole.img.xz.part-* | xz -d > ub2604_uconsole.img')
    (output / 'release-notes.md').write_text(f'''Ubuntu 26.04 for ClockworkPi uConsole CM4 — {tag}

Built from `{commit}` with kernel `{report['kernel']}`. Automated package,
boot-file, hardware-helper and offline filesystem checks passed. This CI image
has not been boot-tested on physical hardware.

Download all release assets into an empty directory, then verify and unpack:

```sh
sha256sum -c SHA256SUMS
{unpack}
sha256sum -c IMAGE-SHA256SUMS
```

Flash the resulting 16 GiB image to a microSD card. Login is **cpi / cpi**;
a password change is required. First boot expands the filesystem. SSH is off.

Tyrian's proprietary game data is excluded from public release images. Its
engine and settings remain available for separately supplied data. Other
third-party applications retain their own terms; see `docs/THIRD-PARTY.md`.

The exact patched kernel sources, kernel config, package manifest, input locks
and verification reports are attached. `build-metadata.json` records provenance.
''')
    files = sorted(output.iterdir())
    if any(path.stat().st_size >= 2**31 for path in files):
        raise RuntimeError('A release asset exceeds the GitHub per-file size limit')
    (output / 'SHA256SUMS').write_text(''.join(f'{digest(path)}  {path.name}\n' for path in files))
    print(f'Packaged {len(parts)} image asset(s); decompression SHA256 verified.')


if __name__ == '__main__':
    main()
