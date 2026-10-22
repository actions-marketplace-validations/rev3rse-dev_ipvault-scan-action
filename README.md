# IP Vault Scan

See which models, firmware and content your app ships before deciding what to protect.
The free scanner reads an APK, AAB, IPA, AAR or ZIP on your CI runner. No account, vault
credential or artifact upload is needed. The action downloads a pinned scanner binary.

You worked hard to create your content and train your models. IP Vault helps keep those
assets under your control by making them harder to extract from your app. It encrypts
selected assets and controls which installations can open them.

**Android supported · iOS coming soon.**
**Scanning is the first inventory step; protection requires integration.**

## Start with a report-only scan

Add this step **after your existing release build**, in the job that has the package:

```yaml
- name: Inventory shipped assets
  id: ip
  uses: rev3rse-dev/ipvault-scan-action@d42ecce90445468eba1f05c026103826f215a4b4 # v0.3.0
  with:
    path: app/build/outputs/apk/release/app-release.apk
    fail-on-plaintext: "false"
```

The job summary lists results, with JSON and JUnit report paths in the `report` and `junit`
outputs. This example reports model and firmware candidates without failing the job. Errors
and incomplete scans still fail. The action itself defaults to `fail-on-plaintext: "true"`;
enable that gate after reviewing your inventory.

The default confidence is medium. SDK/public assets are informational and excluded from
failure counts. Only uncatalogued plaintext models or firmware at the selected confidence
fail the gate. Content collections and font candidates need human review.

## What a report tells you

Our trained handwriting-model reference app has two minified release builds:

| Build | Plaintext models | Sealed assets | Interpretation |
|---|---|---|---|
| Baseline | 1 | 0 | An ordinary reusable model is present in the APK. |
| IP Vault | 0 | 1 | The selected model ships sealed; predictions are checked separately. |

Both scans completed without skipped entries or scan limits. Declared-asset byte searches
catch the baseline and find no declared plaintext model probes in the protected APK.
A passing inventory is not proof that every valuable asset is protected or that purchase
enforcement works. The scan does not establish asset ownership.

[Inspect the baseline scan](https://ip.rev3rse.dev/ip-vault/trained-model/baseline-scan.json) ·
[Inspect the protected scan](https://ip.rev3rse.dev/ip-vault/trained-model/scan.json)

## From inventory to protection

Start with the [working trained-model case study](https://ip.rev3rse.dev/examples/trained-model?utm_source=github-marketplace&utm_medium=marketplace&utm_campaign=first-pilot).
The baseline ships reusable weights. The protected app runs the sealed model and matches
all 20 reference drawings, including offline use after activation. This is an owned
reference integration using generated strokes, not a general handwriting-accuracy benchmark.

Two content examples follow:

- [Field Notes lesson library](https://ip.rev3rse.dev/examples/content-library?utm_source=github-marketplace&utm_medium=marketplace&utm_campaign=first-pilot): original photography lessons and diagrams render from a sealed library.
- [FormFit exercise videos](https://ip.rev3rse.dev/examples/formfit?utm_source=github-marketplace&utm_medium=marketplace&utm_campaign=first-pilot): the existing fitness app plays its encrypted exercise-video bank.

IP Vault aims to put expertise and time back in the way of extraction. Active assets remain
in process memory, and visible or audible content can be captured. Check runtime and reader
compatibility before choosing protection. The scanner is free; guided integration and
verification are a separately scoped paid service.

[Run locally or in GitLab CI/CD](https://ip.rev3rse.dev/scan?utm_source=github-marketplace&utm_medium=marketplace&utm_campaign=first-pilot) ·
[Read the protection integration guide](https://ip.rev3rse.dev/docs/integration)

## Inputs and outputs

| Input | Default | |
|---|---|---|
| `path` | required | The artifact to scan |
| `fail-on-plaintext` | `true` | With `false`, only report: use the `plaintext-found` output to decide |
| `min-confidence` | `medium` | `low`, `medium` or `high` |
| `security-reports` | `false` | Write SARIF and GitLab SAST reports; upload separately |
| `allow-partial` | `false` | Treat a scan that hit a size or depth limit as clean if nothing was found |
| `max-bytes` | `4GiB` | Total bytes read out of archives (the zip-bomb budget) |
| `version` | pinned | The `ipvault` CLI version. It must be pinned in `checksums.txt` |
| `ipvault-path` | | Use your own `ipvault` binary instead of downloading one |
| `download-repo` | | Download the pinned archive from your private mirror's release (`owner/name`) |
| `github-token` | job token | Used only for `download-repo`; no extra scan permission is needed |

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
    uses: rev3rse-dev/ipvault-scan-action@d42ecce90445468eba1f05c026103826f215a4b4 # v0.3.0
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
