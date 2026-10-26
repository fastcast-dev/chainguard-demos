# chainguard-demos

🐙 Demo services built on [Chainguard Containers](https://images.chainguard.dev), pulled
from the internal mirror (`fastcast-dev.self-hosted.io/cgr/*`, no auth) and deployed to
dev and prod k3s clusters by a hardened GitHub Actions pipeline.

```
chainguard-demos/
├── nginx-demo/            # Linky's meme page on distroless nginx
│   ├── html/              # served content (published as a ConfigMap)
│   │   └── image-info.json  # nginx version + package list, generated from the image
│   ├── k8s/               # StatefulSet + Service (public namespace)
│   └── Dockerfile         # local-only demo build
├── tomcat-demo/           # Chainguard × Tomcat page
│   ├── webapp/            # ROOT webapp content (published as a ConfigMap)
│   │   └── image-info.json  # tomcat/Java versions + package list
│   ├── k8s/
│   └── Dockerfile
├── scripts/               # image-info generator + the policy checks
├── .chainguard/
│   ├── ci.yaml            # Chainguard Checks: the presubmit gate
│   └── actions.yaml       # Guardener: hardened-actions migration PRs
└── .github/workflows/
    ├── deploy.yml         # push to main → dev, then prod (gated)
    ├── deploy-env.yml     # reusable per-environment deploy
    ├── digestabot.yml     # hourly digest bump → auto-merge → deploy
    └── automerge.yml      # auto-merge for allow-listed bot PRs (Guardener)
```

## How it deploys

Each service runs as a **single-replica StatefulSet** in the `public` namespace, so pod
names are stable and easy to demo against: `nginx-demo-0` and `tomcat-demo-0`.

The clusters already have traefik Ingresses provisioned. The manifests here just have to
honor that contract:

| Ingress backend | Service | Service port | Container port | Image |
|---|---|---|---|---|
| `nginx-demo:80` | `nginx-demo` | 80 | 8080 (Chainguard nginx is unprivileged) | `…/cgr/nginx:1.31` (minor stream) |
| `tomcat-demo:8080` | `tomcat-demo` | 8080 | 8080 | `…/cgr/tomcat:10-jdk11` (major stream) |

Page content is published as ConfigMaps (`nginx-demo-html`, `tomcat-demo-webapp`) by the
workflow, and the pod template is stamped with a content hash so pods only roll when the
content actually changes. No image builds or pushes needed — the stock mirrored images
do the serving.

## Pipeline

`deploy.yml` runs on every push to `main`: deploy to **dev** (`k3s-dev` ARC runners,
in-cluster), then promote to **prod** (`k3s-prod` runners) behind the `prod`
environment's protection rules. Bot merges (digestabot, Guardener) fire no `push`, so
`digestabot.yml` dispatches the deploy for them.

Hardening checklist:

- `permissions: {}` at the top level; jobs request only `contents: read`
- every action pinned to a full commit SHA
- `persist-credentials: false` on checkout
- kubeconfig built in `RUNNER_TEMP` from the environment-scoped token, never written
  into the workspace
- single `concurrency` group so deploys never interleave; `timeout-minutes` on the job
- the images themselves: distroless, nonroot, read-only rootfs, all capabilities
  dropped, `seccompProfile: RuntimeDefault`

## Digest pinning and automated patching

All image references are pinned by digest (`tag@sha256:…`), and patches flow from
Chainguard to prod with no human in the loop (beyond the `prod` environment's reviewers):

1. **digestabot** (`digestabot.yml`, hourly) re-resolves every pinned tag and opens or
   refreshes the `update-digests` PR when one has moved. Files keep the mirror prefix;
   digest lookups are mapped to the upstream catalog (`fastcast-dev.self-hosted.io/cgr/`
   → `cgr.dev/max.bern/`) and authenticated keylessly via a Chainguard assumable
   identity (`CHAINGUARD_IDENTITY` variable + OIDC — no registry credentials in GitHub).
2. The same job regenerates each page's `image-info.json` from the new images
   (`scripts/image-info.sh`) and pushes it onto the PR, so the version and package
   count on the site always describe the digest that's deployed.
3. It enables **auto-merge** on the PR. GitHub merges it once the required
   [Chainguard Checks](#chainguard-checks) pass, never before. If `main` has no required
   checks the job fails rather than merging unchecked.
4. **reconcile-deploy** waits for the merge and dispatches `deploy.yml`. A merge made
   with `GITHUB_TOKEN` fires no `push` event, so this is what deploys it. It also runs
   every hour, so anything else merged that way still ships within the hour.

Guardener's hardened-actions migration PRs (`.chainguard/actions.yaml`) auto-merge the
same way through `automerge.yml`, for the bot logins listed in `AUTOMERGE_BOTS`.

## Chainguard Checks

`.chainguard/ci.yaml` is the presubmit gate every PR runs on the Chainguard sandbox
plane, hermetically (no network):

| Check | What it enforces |
|---|---|
| `actionlint` | workflows are valid: expressions, runner labels, shell |
| `zizmor` | no medium+ supply-chain / injection findings in `.github/` |
| `yamllint` | every YAML file lints clean (`.yamllint.yaml`) |
| `pins` | every action pinned to a commit SHA, every image to a digest |
| `k8s-hardening` | StatefulSets stay nonroot, read-only rootfs, no caps, RuntimeDefault seccomp, memory-limited |
| `image-info` | each page's `image-info.json` matches the digest its StatefulSet runs |

```sh
chainctl checks validate          # lint the config offline
run-ci [CHECK]                    # run the checks on the working tree (develop session)
chainctl checks status owner/repo#N --watch
```

If you bump a digest by hand, regenerate the page data (needs `crane`; the mirror needs
no auth): `scripts/image-info.sh nginx-demo nginx-demo/html` and
`scripts/image-info.sh tomcat-demo tomcat-demo/webapp`.

## One-time setup

### 1. GitHub environments

Create `dev` and `prod` environments (add required reviewers on `prod`), plus:

| Name | Kind | Value |
|---|---|---|
| `K3S_DEV` | secret | ServiceAccount token with rights in the `public` namespace of the dev cluster |
| `K3S_PROD` | secret | Same, for the prod cluster |
| `K3S_SERVER` | variable (optional) | API server URL; defaults to `https://kubernetes.default.svc` since ARC runners run in-cluster |

The ServiceAccount needs get/create/patch on `statefulsets`, `services`, and
`configmaps` in `public`.

### 2. Runners

ARC runner scale sets named `k3s-dev` and `k3s-prod`, one in each cluster, running the
Chainguard `actions-runner` image with `kubectl` added via
[Custom Assembly](https://edu.chainguard.dev/chainguard/chainguard-images/features/ca-docs/custom-assembly/).

> Note: add **both** `kubectl-1.36` and `kubectl-1.36-default` to the Custom Assembly
> config — the versioned package installs `/usr/bin/kubectl-1.36`, and the `-default`
> companion provides the unversioned `/usr/bin/kubectl` symlink the workflow calls.

### 3. Automated patching

For the digestabot → auto-merge → deploy loop to run unattended:

- **Settings → General → Allow auto-merge**: on.
- **Settings → Actions → General → Allow GitHub Actions to create and approve pull
  requests**: on (digestabot opens its PR with `GITHUB_TOKEN`).
- **Branch protection / ruleset on `main`**: require the Chainguard Checks status
  checks. Don't require an approving review, or bot PRs will wait for a human.
- **Chainguard Checks**: the Checks GitHub App installed on the repository.
- **`AUTOMERGE_BOTS`** (repository variable, optional): comma-separated bot logins whose
  PRs auto-merge, e.g. the Guardener app's `…[bot]` login.

## Local testing

```sh
# nginx — http://localhost:8080
docker build -t nginx-demo nginx-demo/ && docker run --rm -p 8080:8080 nginx-demo

# tomcat — http://localhost:8080
docker build -t tomcat-demo tomcat-demo/ && docker run --rm -p 8080:8080 tomcat-demo
```
