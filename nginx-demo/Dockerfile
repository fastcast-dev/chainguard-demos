# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31.4@sha256:e2d1e6ba5d2d5b88d0ad3a49e32003659e694d10127df4a3fd14fe981c7bf4cd

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
