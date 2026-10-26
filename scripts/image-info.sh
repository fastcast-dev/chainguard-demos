#!/usr/bin/env bash
# Write image-info.json for a demo app: the version of the image's main
# package and every apk package it ships, read from the image's own apk
# database. The page fetches the JSON, so the numbers it shows always match
# the digest the StatefulSet runs (checked by scripts/check-image-info.sh).
#
#   scripts/image-info.sh nginx-demo  nginx-demo/html
#   scripts/image-info.sh tomcat-demo tomcat-demo/webapp
#
# Chainguard images are distroless, so this can't be asked of a running pod;
# it reads the image straight from the registry with crane instead.
#
# REGISTRY_MAP (prefix=replacement) rewrites the pull ref, mirroring
# digestabot's registry-map, e.g. to read from cgr.dev with chainctl auth.
# Leave it empty to read from the internal mirror (no auth).
set -euo pipefail

app="${1:?usage: image-info.sh APP_DIR CONTENT_DIR}"
out_dir="${2:?usage: image-info.sh APP_DIR CONTENT_DIR}"
platform="${PLATFORM:-linux/amd64}"

image="$(sed -n 's/^ *image: *//p' "${app}/k8s/statefulset.yaml" | head -1)"
[[ "${image}" == *@sha256:* ]] || { echo "${app}: image is not digest-pinned: ${image}" >&2; exit 1; }

ref="${image}"
if [[ -n "${REGISTRY_MAP:-}" ]]; then
  from="${REGISTRY_MAP%%=*}" to="${REGISTRY_MAP#*=}"
  ref="${to}${image#"${from}"}"
fi

labels="$(crane config --platform "${platform}" "${ref}" | jq -c '.config.Labels // {}')"
main_label="$(jq -r '."dev.chainguard.package.main" // ""' <<<"${labels}")"

# Flatten the image and read /usr/lib/apk/db/installed out of it.
db="$(crane export --platform "${platform}" "${ref}" - | tar -xOf - usr/lib/apk/db/installed)"

# One JSON object per installed package: name, version, provides.
packages="$(awk '
  /^P:/ { name = substr($0, 3) }
  /^V:/ { version = substr($0, 3) }
  /^p:/ { provides = substr($0, 3) }
  /^$/  { if (name != "") printf "%s\t%s\t%s\n", name, version, provides; name = version = provides = "" }
  END   { if (name != "") printf "%s\t%s\t%s\n", name, version, provides }
' <<<"${db}" | jq -R -s -c 'split("\n") | map(select(. != "") | split("\t") | {name: .[0], version: .[1], provides: (.[2] | split(" "))})')"

# The main package label can name the package itself (tomcat-10.1-openjdk-11)
# or a stream it provides (nginx-1.31 → nginx-mainline, which provides nginx).
jq -n \
  --arg image "${image}" \
  --arg platform "${platform}" \
  --arg main "${main_label}" \
  --argjson labels "${labels}" \
  --argjson pkgs "${packages}" '
  def provides($n): any(.provides[]; startswith($n + "="));
  ($main | sub("-[0-9][0-9.]*$"; "")) as $base
  | ([$pkgs[] | select(.name == $main)]
     + [$pkgs[] | select(provides($main))]
     + [$pkgs[] | select(.name == $base or provides($base))])[0] as $m
  | {
      image: $image,
      platform: $platform,
      created: ($labels."org.opencontainers.image.created" // null),
      main_package: (if $m then {name: $m.name, version: $m.version} else null end),
      package_count: ($pkgs | length),
      packages: ($pkgs | map({name, version}) | sort_by(.name))
    }' > "${out_dir}/image-info.json"

jq -r '"\(.image | sub("@.*"; "")): \(.main_package.name // "?") \(.main_package.version // "?"), \(.package_count) packages"' \
  "${out_dir}/image-info.json"
