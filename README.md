# chainguard-demos

🐙 Demo services built on [Chainguard Containers](https://images.chainguard.dev), pulled
from the internal mirror (`fastcast-dev.self-hosted.io/cgr/*`, no auth) and deployed to
dev and prod k3s clusters by a hardened GitHub Actions pipeline.

```
chainguard-demos/
├── nginx-demo/            # Linky's meme page on distroless nginx
│   ├── html/              # served content (published as a ConfigMap)
│   ├── k8s/               # StatefulSet + Service (public namespace)
│   └── Dockerfile         # local-only demo build
├── tomcat-demo/           # Chainguard × Tomcat page
│   ├── webapp/            # ROOT webapp content (published as a ConfigMap)
│   ├── k8s/
│   └── Dockerfile
└── .github/workflows/
    ├── deploy.yml         # push to main → dev, then prod (gated)
    └── deploy-env.yml     # reusable per-environment deploy
```

## How it deploys

Each service runs as a **single-replica StatefulSet** in the `public` namespace, so pod
names are stable and easy to demo against: `nginx-demo-0` and `tomcat-demo-0`.

The clusters already have traefik Ingresses provisioned. The manifests here just have to
honor that contract:

| Ingress backend | Service | Service port | Container port | Image |
|---|---|---|---|---|
| `nginx-demo:80` | `nginx-demo` | 80 | 8080 (Chainguard nginx is unprivileged) | `…/cgr/nginx:latest` |
| `tomcat-demo:8080` | `tomcat-demo` | 8080 | 8080 | `…/cgr/tomcat:10-jdk11` |

Page content is published as ConfigMaps (`nginx-demo-html`, `tomcat-demo-webapp`) by the
workflow, and the pod template is stamped with a content hash so pods only roll when the
content actually changes. No image builds or pushes needed — the stock mirrored images
do the serving.

## Pipeline

`deploy.yml` runs on every push to `main`: deploy to **dev** (`k3s-dev` ARC runners,
in-cluster), then promote to **prod** (`k3s-prod` runners) behind the `prod`
environment's protection rules.

Hardening checklist:

- `permissions: {}` at the top level; jobs request only `contents: read`
- every action pinned to a full commit SHA
- `persist-credentials: false` on checkout
- kubeconfig built in `RUNNER_TEMP` from the environment-scoped token, never written
  into the workspace
- single `concurrency` group so deploys never interleave; `timeout-minutes` on the job
- the images themselves: distroless, nonroot, read-only rootfs, all capabilities
  dropped, `seccompProfile: RuntimeDefault`

## One-time setup

### 1. GitHub environments

Create `dev` and `prod` environments (add required reviewers on `prod`), each with:

| Name | Kind | Value |
|---|---|---|
| `K3S_TOKEN` | secret | ServiceAccount token with rights in the `public` namespace of that cluster |
| `K3S_SERVER` | variable (optional) | API server URL; defaults to `https://kubernetes.default.svc` since ARC runners run in-cluster |

The ServiceAccount needs get/create/patch on `statefulsets`, `services`, and
`configmaps` in `public`.

### 2. Runners

ARC runner scale sets named `k3s-dev` and `k3s-prod`, one in each cluster, running the
Chainguard `actions-runner` image with `kubectl` added via
[Custom Assembly](https://edu.chainguard.dev/chainguard/chainguard-images/features/ca-docs/custom-assembly/).

## Local testing

```sh
# nginx — http://localhost:8080
docker build -t nginx-demo nginx-demo/ && docker run --rm -p 8080:8080 nginx-demo

# tomcat — http://localhost:8080
docker build -t tomcat-demo tomcat-demo/ && docker run --rm -p 8080:8080 tomcat-demo
```
