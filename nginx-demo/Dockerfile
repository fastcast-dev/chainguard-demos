# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31.4@sha256:9809cbf958d9fe24e3bc3e57eead939642c9ae1af9dd0eacaa3d5237af0036e6

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
