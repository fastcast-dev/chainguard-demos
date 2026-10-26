#!/usr/bin/env bash
# Hold every workload manifest to the posture the README promises: nonroot,
# RuntimeDefault seccomp, no privilege escalation, read-only rootfs, all
# capabilities dropped, and a memory limit.
set -euo pipefail

status=0
checked=0

# expect FILE YQ_PATH WANT MESSAGE
expect() {
  local got
  got="$(yq -r "$2" "$1")"
  if [[ "${got}" != "$3" ]]; then
    echo "::error file=$1::$4 (got: ${got})"
    status=1
  fi
}

for file in ./*-demo/k8s/*.yaml; do
  [[ "$(yq -r '.kind' "${file}")" == "StatefulSet" ]] || continue
  checked=$((checked + 1))
  pod='.spec.template.spec'
  expect "${file}" "${pod}.securityContext.runAsNonRoot" true "pod: runAsNonRoot must be true"
  expect "${file}" "${pod}.securityContext.seccompProfile.type" RuntimeDefault "pod: seccompProfile must be RuntimeDefault"
  for i in $(seq 0 $(($(yq -r "${pod}.containers | length" "${file}") - 1))); do
    c="${pod}.containers[${i}]"
    name="$(yq -r "${c}.name" "${file}")"
    expect "${file}" "${c}.securityContext.allowPrivilegeEscalation" false "${name}: allowPrivilegeEscalation must be false"
    expect "${file}" "${c}.securityContext.readOnlyRootFilesystem" true "${name}: readOnlyRootFilesystem must be true"
    expect "${file}" "${c}.securityContext.capabilities.drop // [] | any_c(. == \"ALL\")" true "${name}: capabilities.drop must include ALL"
    expect "${file}" "${c}.resources.limits.memory != null" true "${name}: resources.limits.memory must be set"
  done
done

if [[ "${checked}" == 0 ]]; then
  echo "::error::no StatefulSets found under */k8s/; the scan itself is broken"
  exit 1
fi
[[ "${status}" == 0 ]] && echo "ok: ${checked} StatefulSets meet the hardening baseline"
exit "${status}"
