# IP Vault scan: GitHub Action

Fails the build when a release artifact ships a model in plaintext. No account is needed.

```yaml
- uses: rev3rse-dev/ipvault-scan-action@<commit-sha>   # pin by commit: it pins the binary too
  with:
    path: app/build/outputs/apk/release/app-release.apk  # APK, AAB, IPA, AAR or ZIP
```

The step fails if any plaintext model is found at or above `min-confidence`. The job summary
gets a table of findings, and each plaintext model gets an annotation. A JUnit XML report and a
JSON report are written, and their paths are the step's `junit` and `report` outputs.

| Input | Default | |
|---|---|---|
| `path` | required | The artifact to scan |
| `fail-on-plaintext` | `true` | With `false`, only report: use the `plaintext-found` output to decide |
| `min-confidence` | `medium` | `low`, `medium` or `high` |
| `allow-partial` | `false` | Treat a scan that hit a size or depth limit as clean if nothing was found |
| `max-bytes` | `4GiB` | Total bytes read out of archives (the zip-bomb budget) |
| `version` | pinned | The `ipvault` CLI version. It must be pinned in `checksums.txt` |
| `ipvault-path` | | Use your own `ipvault` binary instead of downloading one |
| `download-repo` | | Download the pinned archive from your private mirror's release (`owner/name`) |

Outputs: `plaintext-found`, `exit-code` (0 clean, 1 plaintext found, 2 error or incomplete),
`report`, `junit`, and `sarif` when security reports are enabled.

## Security reports (CLI 0.3.0+)

Set `security-reports` to `true` to generate SARIF and GitLab SAST. It defaults to `false`
so uploading security findings remains an explicit workflow choice.

```yaml
permissions:
  contents: read
  security-events: write
steps:
  - id: ip
    uses: rev3rse-dev/ipvault-scan-action@<commit-sha-with-this-change>
    with:
      path: app/build/outputs/apk/release/app-release.apk
      security-reports: "true"
      fail-on-plaintext: "false"
  - uses: github/codeql-action/upload-sarif@<pinned-commit-sha>
    if: always() && steps.ip.outputs.sarif != ''
    with:
      sarif_file: ${{ steps.ip.outputs.sarif }}
      category: ipvault-android-release
```

The new scanner defaults to medium confidence and excludes SDK/public models from counts and
failures. Content collections and restricted-font candidates are review items; only uncatalogued
models/firmware become security findings. JSON schema 2 includes origin and covered-file count.
The SARIF file describes binary package locations; no source line is fabricated. Source-linked
alerts require files that exist in the repository. Code scanning availability depends on the
repository's GitHub plan. The scan itself needs no extra permission; upload needs the permission
shown above. Use a distinct upload category when scanning multiple artifacts.

## Supply chain

- **The binary is pinned by this action's commit.** `install.sh` downloads the release archive
  for the runner's platform and refuses it unless its SHA-256 matches `checksums.txt`, which
  ships in the same commit as the action. Pin the action by commit SHA, never by a tag.
- **No permissions are needed.** The archive comes from the public release. With
  `download-repo` it comes from a GitHub release in a repository the job's token can read
  instead, such as your own private mirror of the same archives; the pinned checksum decides
  either way.
- **Untrusted names cannot run workflow commands.** Names inside a scanned archive are
  untrusted. The report is printed with workflow commands suspended. Annotations come only from
  the scanner's escaped annotations file, after commands resume.
- **Inputs reach the scripts only as environment variables.**

## What a clean result means

No actionable known plaintext model/firmware was found under the selected confidence and scan
limits. It does not mean the package is safe. SDK/public assets remain informational. Once your assets are declared with IP Vault, the release
action's `verify` checks every declared asset by content, whatever its type: video, map data and
anything else you seal.

---

This repository is generated from `actions/scan` in the IP Vault source by `ci/mirror.py`, which also
checks a published copy byte for byte against the source at the source commit named by the release. Changes go to the
source, not here. Pin this action by commit SHA: the commit pins the `ipvault` binary through
`checksums.txt`.
