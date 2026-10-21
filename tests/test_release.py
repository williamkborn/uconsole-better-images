"""Exercise release packaging and publishing with tiny images and local repos."""
import hashlib
import importlib.util
import io
import json
import lzma
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_release', PROJECT / 'scripts/package-release.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True, stderr=subprocess.DEVNULL).strip()


def init_repo(path):
    path.mkdir(parents=True, exist_ok=True)
    git(path, 'init', '-b', 'main')
    git(path, 'config', 'user.name', 'Release test')
    git(path, 'config', 'user.email', 'test@example.invalid')


class PackagingTests(unittest.TestCase):
    def test_split_roundtrip_and_corruption(self):
        data = os.urandom(32768)
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / 'image.xz'
            parts = package.split_stream(io.BytesIO(lzma.compress(data)), prefix, 4096)
            self.assertGreater(len(parts), 1)
            self.assertTrue(all(p.stat().st_size <= 4096 for p in parts))
            package.verify_compressed(parts, hashlib.sha256(data).hexdigest(), len(data))
            parts[-1].write_bytes(parts[-1].read_bytes()[:-5])
            with self.assertRaises((EOFError, lzma.LZMAError, RuntimeError)):
                package.verify_compressed(parts, hashlib.sha256(data).hexdigest(), len(data))

    def test_single_asset_and_exact_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            prefix = Path(directory) / 'image.xz'
            parts = package.split_stream(io.BytesIO(b'1234'), prefix, 4)
            self.assertEqual(parts, [prefix])
            self.assertEqual(prefix.read_bytes(), b'1234')

    def test_empty_input_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(RuntimeError):
                package.split_stream(io.BytesIO(b''), Path(directory) / 'image.xz', 4)

    def make_project(self, directory):
        project = Path(directory) / 'project'
        init_repo(project)
        (project / 'README.md').write_text('Release fixture\n')
        git(project, 'add', 'README.md')
        git(project, 'commit', '-m', 'Fixture')
        git(project, 'tag', '-a', 'v1.0', '-m', 'Fixture tag')
        kernel = project / 'sources/clockworkpi-linux'
        init_repo(kernel)
        (kernel / 'driver.c').write_text('upstream\n')
        git(kernel, 'add', '.')
        git(kernel, 'commit', '-m', 'Upstream')
        (kernel / 'driver.c').write_text('vendor-patched\n')
        git(kernel, 'add', 'driver.c')
        (project / 'build/kernel').mkdir(parents=True)
        (project / 'build/kernel/.config').write_text('CONFIG_TEST=y\n')
        (project / 'docs').mkdir()
        (project / 'docs/root-verification.json').write_text(json.dumps({
            'kernel': 'test-uconsole', 'build_profile': 'release',
            'checks': ['Release excludes proprietary Tyrian data']}))
        for name in ('installed-packages.tsv', 'final-upgrade-check.txt', 'hardware-helper-tests.txt'):
            (project / 'docs' / name).write_text('fixture\n')
        (project / 'sources.lock.json').write_text('{"artifacts": []}\n')
        image = project.parent / 'ub2604_uconsole.img'
        image.write_bytes(os.urandom(32768))
        (project / 'docs/image.sha256').write_text(f'{package.digest(image)}  {image}\n')
        return project

    def test_package_includes_exact_patched_source_and_checksums(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.make_project(directory)
            with patch.object(package, 'PROJECT', project), patch.dict(os.environ, RELEASE_TAG='v1.0'):
                package.main()
            output = project / 'dist'
            subprocess.run(['sha256sum', '-c', 'SHA256SUMS'], cwd=output, check=True, stdout=subprocess.DEVNULL)
            with tarfile.open(output / 'kernel-source.tar.xz') as archive:
                self.assertEqual(archive.extractfile('linux-uconsole/driver.c').read(), b'vendor-patched\n')
            metadata = json.loads((output / 'build-metadata.json').read_text())
            self.assertEqual(metadata['commit'], git(project, 'rev-parse', 'HEAD'))
            self.assertEqual(metadata['image_bytes'], 32768)

    def test_full_profile_and_changed_image_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.make_project(directory)
            report = project / 'docs/root-verification.json'
            original = report.read_text()
            report.write_text(original.replace('"release"', '"full"'))
            with patch.object(package, 'PROJECT', project), patch.dict(os.environ, RELEASE_TAG='v1.0'):
                with self.assertRaisesRegex(RuntimeError, 'release-profile'):
                    package.main()
                report.write_text(original)
                (project.parent / 'ub2604_uconsole.img').write_bytes(b'changed')
                with self.assertRaisesRegex(RuntimeError, 'differs'):
                    package.main()

    def test_publish_failure_never_publishes_partial_release(self):
        with tempfile.TemporaryDirectory() as directory:
            project = self.make_project(directory)
            git(project, 'remote', 'add', 'origin', str(project))
            (project / 'scripts').mkdir()
            shutil.copyfile(PROJECT / 'scripts/publish-release.sh', project / 'scripts/publish-release.sh')
            with patch.object(package, 'PROJECT', project), patch.dict(os.environ, RELEASE_TAG='v1.0'):
                package.main()
            binaries = Path(directory) / 'bin'
            binaries.mkdir()
            fake = binaries / 'gh'
            fake.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$GH_TEST_LOG"\n'
                            '[ "$2" != view ] || exit "${VIEW_EXIT:-1}"\n'
                            '[ "$2" != upload ] || exit "${UPLOAD_EXIT:-0}"\n')
            fake.chmod(0o755)
            log = Path(directory) / 'gh.log'
            env = dict(os.environ, PATH=str(binaries) + ':' + os.environ['PATH'],
                       GH_REPO='example/test', GH_TOKEN='fixture', RELEASE_TAG='v1.0',
                       RELEASE_SHA=git(project, 'rev-parse', 'HEAD'), GH_TEST_LOG=str(log), UPLOAD_EXIT='1')
            result = subprocess.run(['bash', str(project / 'scripts/publish-release.sh')], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            calls = log.read_text()
            self.assertIn('release create', calls)
            self.assertIn('--draft', calls)
            self.assertIn('release upload', calls)
            self.assertNotIn('release edit', calls)
            # A complete upload can publish, but existing releases are immutable here.
            log.write_text('')
            env['UPLOAD_EXIT'] = '0'
            result = subprocess.run(['bash', str(project / 'scripts/publish-release.sh')], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('--draft=false', log.read_text())
            log.write_text('')
            env['VIEW_EXIT'] = '0'
            result = subprocess.run(['bash', str(project / 'scripts/publish-release.sh')], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('release create', log.read_text())
            # A moved tag must be rejected before any GitHub release mutation.
            log.write_text('')
            env['VIEW_EXIT'] = '1'
            (project / 'README.md').write_text('Moved tag fixture\n')
            git(project, 'add', 'README.md')
            git(project, 'commit', '-m', 'New version')
            git(project, 'tag', '-f', 'v1.0')
            result = subprocess.run(['bash', str(project / 'scripts/publish-release.sh')], env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Remote tag changed', result.stderr)
            self.assertEqual(log.read_text(), '')


if __name__ == '__main__':
    unittest.main()
