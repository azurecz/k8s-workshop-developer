### BASE image
FROM openjdk:8-jdk-alpine AS base
VOLUME /tmp
EXPOSE 8080
ENV APP_HOME /app
RUN mkdir $APP_HOME
RUN mkdir $APP_HOME/config

### BUILD image
FROM openjdk:8-jdk-alpine AS build
# Install Maven
RUN apk add --no-cache curl tar bash
ARG MAVEN_VERSION=3.3.9
ARG USER_HOME_DIR="/root"
RUN mkdir -p /usr/share/maven && \
curl -fsSL http://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -xzC /usr/share/maven --strip-components=1 && \
ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"
# speed up Maven JVM a bit
ENV MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
ENTRYPOINT ["/usr/bin/mvn"]
# ----
# Install project dependencies and keep sources
# make source folder
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
# install maven dependency packages (keep in image)
COPY pom.xml /usr/src/app
COPY src /usr/src/app/src
# Build my applicatio
RUN mvn clean package

### CREATE final image
FROM base as final
WORKDIR $APP_HOME
COPY --from=build /usr/src/app/target/app.jar .
# certificate for postgres
RUN mkdir /root/.postgresql
COPY src/main/postgresql/root.crt /root/.postgresql/
# run it ...
ENTRYPOINT [ "java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar" ]
