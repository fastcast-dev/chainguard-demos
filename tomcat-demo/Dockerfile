# Local-demo build of the same content the cluster serves via ConfigMap.
#
#   docker build -t tomcat-demo tomcat-demo/
#   docker run -p 8080:8080 tomcat-demo
#
# The Chainguard tomcat image (via the internal mirror, no auth) is a drop-in
# replacement for the official image: CATALINA_HOME=/usr/local/tomcat, ships an
# empty webapps/, runs as uid 65532.
FROM fastcast-dev.self-hosted.io/cgr/tomcat:10-jdk11@sha256:577f0c88244165e3c4f1ed632180c144572324827e4c3404aa485fc3c9abf0ad

COPY webapp/ /usr/local/tomcat/webapps/ROOT/

EXPOSE 8080
