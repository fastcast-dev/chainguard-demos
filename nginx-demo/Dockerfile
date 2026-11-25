# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t nginx-demo nginx-demo/
#   docker run -p 8080:8080 nginx-demo
#
# The Chainguard nginx image (via the internal mirror, no auth) is distroless:
# no shell, no package manager, runs as the nonroot `nginx` user, and listens
# on unprivileged 8080.
FROM fastcast-dev.self-hosted.io/cgr/nginx:1.31@sha256:ddd832890a1cc30bd0a042440de06162a1f5b31e299380f38dfc2db4630d9dce

COPY html/ /usr/share/nginx/html/

EXPOSE 8080
