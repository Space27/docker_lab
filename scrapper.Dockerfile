FROM eclipse-temurin:21-jdk-alpine as build
ENV RELEASE=21

WORKDIR /opt/build

ARG JAR_FILE=scrapper/target/*.jar
COPY ${JAR_FILE} app.jar

RUN java -Djarmode=layertools -jar app.jar extract
RUN $JAVA_HOME/bin/jlink \
         --add-modules jdk.crypto.ec,`jdeps --ignore-missing-deps -q -recursive --multi-release ${RELEASE} --print-module-deps -cp 'dependencies/BOOT-INF/lib/*' app.jar` \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output jdk

FROM alpine:3.14

ARG BUILD_PATH=/opt/build
ENV JAVA_HOME=/opt/jdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"

RUN addgroup nonrootgroup; adduser  --ingroup nonrootgroup --disabled-password nonroot
USER nonroot

WORKDIR /opt/workspace

COPY migrations ./data/migrations
COPY prometheus.yml ./data

COPY --from=build $BUILD_PATH/jdk $JAVA_HOME
COPY --from=build $BUILD_PATH/spring-boot-loader/ ./
COPY --from=build $BUILD_PATH/dependencies/ ./
COPY --from=build $BUILD_PATH/application/ ./

ENV DATABASE_ACCESS_TYPE=jdbc
ENV DELAY_TYPE=fixed
ENV USE_QUEUE=false
ENV SPRING_DATASOURCE_DB=scrapper
ENV SPRING_DATASOURCE_USERNAME=postgres
ENV SPRING_DATASOURCE_PASSWORD=postgres

EXPOSE 8080 8081
VOLUME ["/opt/workspace/data"]

ENTRYPOINT ["java", "-Dspring.profiles.active=docker", "org.springframework.boot.loader.launch.JarLauncher"]
