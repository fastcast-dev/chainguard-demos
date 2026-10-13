# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31@sha256:4d28bb935112fdab6ee87ef7b21eef5f47313e160806316be19262a9228132a5

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
