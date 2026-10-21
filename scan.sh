#!/usr/bin/env bash
# Runs `ipvault scan` and turns its result into a job summary, annotations and step outputs.
#
# Names inside a scanned archive are untrusted, so the human-readable report is printed with
# workflow commands suspended (::stop-commands::), and annotations come only from the scanner's
# escaped annotations file, after commands resume.
set -euo pipefail

case "$MIN_CONFIDENCE" in low|medium|high) ;; *) echo "::error::min-confidence must be low, medium or high"; exit 2 ;; esac
out="$(mktemp -d "$RUNNER_TEMP/ipvault-scan.XXXXXXXX")"

args=(scan "$SCAN_PATH" --min-confidence "$MIN_CONFIDENCE" --max-bytes "$MAX_BYTES"
  --json-out "$out/report.json" --markdown-out "$out/summary.md"
  --junit-out "$out/junit.xml" --github-annotations-out "$out/annotations.txt")
[[ "$ALLOW_PARTIAL" == true ]] && args+=(--allow-partial)
if [[ "${SECURITY_REPORTS:-false}" == true ]]; then
  args+=(--sarif-out "$out/report.sarif" --gitlab-sast-out "$out/report.sast.json")
fi

token="ipvault-$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
echo "::stop-commands::$token"
set +e
"$IPVAULT_BIN" "${args[@]}"
code=$?
set -e
echo "::$token::"

[[ -f "$out/annotations.txt" ]] && cat "$out/annotations.txt"
[[ -f "$out/summary.md" ]] && cat "$out/summary.md" >> "$GITHUB_STEP_SUMMARY"

{
  echo "exit-code=$code"
  echo "plaintext-found=$([[ $code == 1 ]] && echo true || echo false)"
  echo "report=$out/report.json"
  echo "junit=$out/junit.xml"
  [[ "${SECURITY_REPORTS:-false}" != true ]] || echo "sarif=$out/report.sarif"
} >> "$GITHUB_OUTPUT"

if [[ $code == 1 && "$FAIL_ON_PLAINTEXT" != true ]]; then
  echo "::warning::unprotected plaintext model or firmware found (fail-on-plaintext is off)"
  exit 0
fi
exit "$code"
