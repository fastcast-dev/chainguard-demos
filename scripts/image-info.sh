#!/usr/bin/env bash
# Describe a deployed image from Chainguard's own signed attestations:
# the SPDX SBOM (packages, versions, shells) and the SLSA provenance
# (builder, build time, run-as user), plus their Rekor transparency-log
# entries. The pages fetch the resulting image-info.json.
#
#   scripts/image-info.sh IMAGE_REF OUT_JSON
#
# The deploy workflow runs this for the exact digest each StatefulSet names,
# so the pages always describe what was just rolled out. Chainguard images
# are distroless, so the running pod can't be asked; the attestations sit
# next to the image in the registry (mirrored with it), signed at build time.
#
# Needs only curl, jq and base64. The internal mirror needs no auth.
set -euo pipefail

image="${1:?usage: image-info.sh IMAGE_REF OUT_JSON}"
out="${2:?usage: image-info.sh IMAGE_REF OUT_JSON}"
arch="${ARCH:-amd64}"

[[ "${image}" == *@sha256:* ]] || { echo "image is not digest-pinned: ${image}" >&2; exit 1; }
host="${image%%/*}"
path="${image#*/}"
repo="${path%@*}" repo="${repo%:*}"
digest="${image#*@}"

reg="https://${host}/v2/${repo}"
accept='application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json'
get() { curl -fsSL --retry 2 -H "Accept: ${accept}" "$@"; }

# SBOM and provenance are attested per architecture, on the platform image.
index="$(get "${reg}/manifests/${digest}")"
platform_digest="$(jq -r --arg arch "${arch}" \
  'if .manifests then (.manifests[] | select(.platform.architecture == $arch) | .digest) else empty end' <<<"${index}")"
platform_digest="${platform_digest:-${digest}}"

# cosign stores attestations under the sha256-<digest>.att tag, one layer each.
att="$(get "${reg}/manifests/sha256-${platform_digest#sha256:}.att")"
layer() { jq -c --arg t "$1" '.layers[] | select(.annotations.predicateType == $t)' <<<"${att}"; }
predicate() { get "${reg}/blobs/$(jq -r .digest <<<"$1")" | jq -r .payload | base64 -d | jq -c .predicate; }
# Rekor entry and Fulcio signing identity, from cosign's layer annotations.
rekor() { jq -c '.annotations["dev.sigstore.cosign/bundle"] | fromjson | .Payload | {log_index: .logIndex, integrated_time: (.integratedTime | todate)}' <<<"$1"; }
identity() {
  jq -r '.annotations["dev.sigstore.cosign/certificate"]' <<<"$1" | sed '/-----/d' | base64 -d \
    | tr -c '[:print:]' '\n' | grep -oE 'https://issuer\.enforce\.dev/[0-9a-f]{40}/[0-9a-f]{16}' | head -1
}

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

sbom_layer="$(layer https://spdx.dev/Document)"
prov_layer="$(layer https://slsa.dev/provenance/v1)"
# Large SBOMs (tomcat: ~1 MB) overflow argv, so hand them to jq as files.
predicate "${sbom_layer}" > "${tmp}/sbom.json"
predicate "${prov_layer}" > "${tmp}/prov.json"

jq -n \
  --arg image "${image}" \
  --arg platform "linux/${arch}" \
  --arg platform_digest "${platform_digest}" \
  --slurpfile sbom "${tmp}/sbom.json" \
  --slurpfile prov "${tmp}/prov.json" \
  --argjson sbom_rekor "$(rekor "${sbom_layer}")" \
  --argjson prov_rekor "$(rekor "${prov_layer}")" \
  --arg identity "$(identity "${prov_layer}")" '
  $sbom[0] as $sbom | $prov[0] as $prov |
  # apk packages only (the SBOM also lists each package source), one per name.
  [ $sbom.packages[]
    | select(any(.externalRefs[]?; .referenceType == "purl" and (.referenceLocator | startswith("pkg:apk/"))))
    | {name, version: .versionInfo} ] | unique_by(.name) as $pkgs
  | $prov.buildDefinition.externalParameters["image-configuration"] as $cfg
  # The main-package label names the package (tomcat-10.1-openjdk-11) or the
  # stream it provides (nginx-1.31 → nginx-mainline): try exact, then the
  # shortest package named after the stream.
  | ($cfg.annotations["dev.chainguard.package.main"] // "") as $main
  | ($main | sub("-[0-9][0-9.]*$"; "")) as $base
  | ([$pkgs[] | select(.name == $main)]
     + ([$pkgs[] | select(.name == $base or (.name | startswith($base + "-")))] | sort_by(.name | length)))[0] as $m
  | {
      image: $image,
      platform: $platform,
      platform_digest: $platform_digest,
      created: $sbom.creationInfo.created,
      main_package: $m,
      package_count: ($pkgs | length),
      packages: $pkgs,
      shells: [$pkgs[] | select(.name | IN("bash", "busybox", "dash", "toybox", "zsh", "mksh", "yash")) | .name],
      run_as: $cfg.accounts["run-as"],
      entrypoint: $cfg.entrypoint.command,
      provenance: {
        builder: $prov.runDetails.builder.id,
        build_type: $prov.buildDefinition.buildType,
        apko_version: $prov.runDetails.builder.version.apko,
        finished_on: $prov.runDetails.metadata.finishedOn,
        signing_identity: $identity,
        rekor: $prov_rekor
      },
      sbom: {
        format: "SPDX",
        creators: $sbom.creationInfo.creators,
        rekor: $sbom_rekor
      }
    }' > "${out}"

jq -r '"\(.image | sub("@.*"; "")): \(.main_package.name // "?") \(.main_package.version // "?"), \(.package_count) packages, shells: \(.shells | join(",") | if . == "" then "none" else . end)"' "${out}"
