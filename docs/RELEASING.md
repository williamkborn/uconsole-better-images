# Automated image releases

The **Build and release CM4 image** workflow runs lightweight project and release
packaging tests for pushes to `main` and pull requests. It builds and publishes
an image when a version tag is pushed, or when manually dispatched for an existing
version tag. It never writes a physical SD card.

## Start a release

After the changes are on `main`, choose a new version and push its tag:

```sh
git switch main
git pull --ff-only
git tag -a v2026.10.21 -m 'Ubuntu 26.04 CM4 image'
git push origin v2026.10.21
```

Alternatively, open **Actions → Build and release CM4 image → Run workflow** and
enter an existing tag such as `v2026.10.21`. Tags must start with `v` and a digit;
only letters, digits, periods, underscores and hyphens are accepted afterward.
The workflow checks out that exact tag and verifies it again before publication.
No personal access token or repository secret is required: the publishing job
uses `GITHUB_TOKEN` with `contents: write`. The build job has only read access.

Allow time for the kernel build, ARM64 package configuration and compression.
The build has a 350-minute timeout. The current workflow uses the standard
`ubuntu-26.04` GitHub-hosted runner, frees unused SDK directories on that disposable
VM, and checks that at least 50 GiB is available. The cleanup script refuses to
run on a normal workstation or self-hosted runner. If runner images change and
there is insufficient disk space, the job fails before starting the image build.

## What is uploaded

- The verified 16 GiB image compressed with XZ. If necessary, it is split into
  ordered parts of at most 1900 MiB to stay below GitHub's 2 GiB per-asset limit.
- `SHA256SUMS` for the downloadable assets and `IMAGE-SHA256SUMS` for the unpacked image.
- Exact patched kernel sources (`kernel-source.tar.xz`) and the kernel config.
- Installed package versions, pinned inputs, verification reports and build metadata.
- Release notes with checksum and reconstruction commands.

The packager decompresses the completed image asset(s) and checks the raw image
hash and byte count before upload. The publisher checks every transferred asset,
verifies that the tag has not moved, uploads into a draft release, and publishes
only after all uploads succeed. Published releases are never overwritten.

Build artifacts are retained for three days; diagnostic logs for seven days.
Release assets remain attached to the GitHub Release. No caches or mounted
filesystems are uploaded as workflow artifacts.

## Release profile

Public images use `UCONSOLE_BUILD_PROFILE=release`. This preserves CM4 hardware
support, desktop integration, applications and settings, but omits Tyrian's
proprietary game data because its bundled notice prohibits redistribution. Its
engine remains installed and can use separately supplied data. The verifier and
packager enforce the omission. See [third-party notices](THIRD-PARTY.md).

Ordinary local builds still default to `full`, preserving the original personal
image's content. A local release-profile build can be made with:

```sh
sudo env UCONSOLE_BUILD_PROFILE=release bash scripts/build-image.sh
```

Use a fresh image when changing profiles. A resumed full image containing Tyrian
data fails release verification. Never publish an image just because it builds:
third-party terms still apply, and CI checks do not replace native hardware tests.

## Failed runs and retries

The publishing job does not run if the build, filesystem checks, packaging or
artifact transfer fails. Inspect the diagnostic artifact and job logs.

If an upload fails after a draft was created, that release stays a draft. Inspect
and explicitly delete the incomplete draft before rerunning the publishing job.
Keep the tag. If a release has already been published, use a new version tag.
Do not move an existing release tag to a different commit.

The repository change adding this workflow was checked with actionlint and local
packaging/failure tests. A full hosted image build is only validated after its
first successful version-tag run; the earlier native hardware report applies to
the original locally built image.

References: [runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[release asset limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas).
