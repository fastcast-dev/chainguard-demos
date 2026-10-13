# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t tomcat-demo tomcat-demo/
#   docker run -p 8080:8080 tomcat-demo
#
# The Chainguard tomcat image (via the internal mirror, no auth) is a drop-in
# replacement for the official image: CATALINA_HOME=/usr/local/tomcat, ships an
# empty webapps/, runs as uid 65532.
FROM fastcast-dev.self-hosted.io/cgr/tomcat:10-jdk11@sha256:6a99a7f44dda486e3a7b9b7f7d0c50d32a6a6b53aa2d9e7f7c245f1f02623e9d

COPY webapp/ /usr/local/tomcat/webapps/ROOT/

EXPOSE 8080
