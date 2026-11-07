# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31@sha256:f1f716b19ef04b07d6400669066be89d7e9fe6d3309c437525fc695350f8ffca

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
