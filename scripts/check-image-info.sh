#!/usr/bin/env bash
# Fail when an app's image-info.json describes a different image than its
# StatefulSet runs, so the version and package count on the page can't drift
# from what's deployed. Regenerate with scripts/image-info.sh.
set -euo pipefail

status=0
for pair in nginx-demo:nginx-demo/html tomcat-demo:tomcat-demo/webapp; do
  app="${pair%%:*}" info="${pair#*:}/image-info.json"
  image="$(sed -n 's/^ *image: *//p' "${app}/k8s/statefulset.yaml" | head -1)"
  if [[ ! -f "${info}" ]]; then
    echo "::error file=${info}::missing; run: scripts/image-info.sh ${app} ${pair#*:}"
    status=1
    continue
  fi
  recorded="$(jq -r .image "${info}")"
  if [[ "${recorded}" != "${image}" ]]; then
    echo "::error file=${info}::describes ${recorded}, but ${app} runs ${image}; run: scripts/image-info.sh ${app} ${pair#*:}"
    status=1
  elif ! jq -e '.main_package.version and (.package_count > 0)' "${info}" >/dev/null; then
    echo "::error file=${info}::has no main package version or package count"
    status=1
  else
    echo "ok: ${info} matches ${image}"
  fi
done
exit "${status}"
