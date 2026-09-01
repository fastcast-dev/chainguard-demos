# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31.4@sha256:5e5a9ff32fff0da67d8e0d3c96f6999f3adbc70ceb5e39d9d631c5f537762043

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
