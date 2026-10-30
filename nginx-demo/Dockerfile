# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31@sha256:2758c061950f30cbe032778ea0150b73453ef414848576b7d2c25dc74688e767

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
