#!/usr/bin/env bash
# Every action pinned to a full commit SHA, every image pinned by digest.
# Tags and branches can be repointed; SHAs and digests can't.
set -euo pipefail

status=0
checked=0

# `uses:` must be a local path or owner/repo[/path]@<40-hex SHA>.
while IFS=: read -r file line ref; do
  checked=$((checked + 1))
  ref="${ref#*uses:}" ref="${ref%%#*}" ref="${ref//[[:space:]\"\']/}"
  [[ "${ref}" == ./* ]] && continue
  if [[ ! "${ref}" =~ @[0-9a-f]{40}$ ]]; then
    echo "::error file=${file},line=${line}::action not pinned to a commit SHA: ${ref}"
    status=1
  fi
done < <(grep -rnE '^[[:space:]-]*uses:' .github/)

# k8s `image:` and Dockerfile `FROM` must carry @sha256:.
# Dockerfile.ubi is a local-only grype comparison image, never deployed.
while IFS=: read -r file line ref; do
  [[ "${file}" == */Dockerfile.ubi ]] && continue
  checked=$((checked + 1))
  ref="${ref#*image:}" ref="${ref#*FROM }" ref="${ref%% AS *}" ref="${ref//[[:space:]\"\']/}"
  if [[ ! "${ref}" =~ @sha256:[0-9a-f]{64}$ ]]; then
    echo "::error file=${file},line=${line}::image not pinned by digest: ${ref}"
    status=1
  fi
done < <(find ./*-demo -type f \( -name '*.yaml' -o -name '*.yml' -o -name 'Dockerfile*' \) \
  -exec grep -nHE '^[[:space:]-]*image:|^FROM ' {} +)

# A pattern that silently matches nothing would pass everything.
if [[ "${checked}" == 0 ]]; then
  echo "::error::no action or image references found; the scan itself is broken"
  exit 1
fi
[[ "${status}" == 0 ]] && echo "ok: ${checked} references, all actions SHA-pinned, all images digest-pinned"
exit "${status}"
