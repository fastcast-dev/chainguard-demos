# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t tomcat-demo tomcat-demo/
#   docker run -p 8080:8080 tomcat-demo
#
# The Chainguard tomcat image (via the internal mirror, no auth) is a drop-in
# replacement for the official image: CATALINA_HOME=/usr/local/tomcat, ships an
# empty webapps/, runs as uid 65532.
FROM fastcast-dev.self-hosted.io/cgr/tomcat:10-jdk11@sha256:23e4a58f1647d66ef154fd4eac0fcaa6036a5e95a30ab1302523cd74c49ccb0e

COPY webapp/ /usr/local/tomcat/webapps/ROOT/

EXPOSE 8080
