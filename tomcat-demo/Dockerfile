# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t tomcat-demo tomcat-demo/
#   docker run -p 8080:8080 tomcat-demo
#
# The Chainguard tomcat image (via the internal mirror, no auth) is a drop-in
# replacement for the official image: CATALINA_HOME=/usr/local/tomcat, ships an
# empty webapps/, runs as uid 65532.
FROM fastcast-dev.self-hosted.io/cgr/tomcat:10-jdk11@sha256:6e6e1b97b379b8ed03d9e99136371f25ac761386842341d8935aa9049ec8a94a

COPY webapp/ /usr/local/tomcat/webapps/ROOT/

EXPOSE 8080
