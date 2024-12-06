FROM eclipse-temurin:21-jdk-alpine as build
ENV RELEASE=21

WORKDIR /opt/build

ARG JAR_FILE=bot/target/*.jar
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

COPY --from=build $BUILD_PATH/jdk $JAVA_HOME
COPY --from=build $BUILD_PATH/spring-boot-loader/ ./
COPY --from=build $BUILD_PATH/dependencies/ ./
COPY --from=build $BUILD_PATH/application/ ./

ENV TELEGRAM_API_KEY=${TELEGRAM_API_KEY}
ENV USE_QUEUE=false
ENV DELAY_TYPE=fixed

EXPOSE 8090 8091

ENTRYPOINT ["java", "-Dspring.profiles.active=docker", "org.springframework.boot.loader.launch.JarLauncher"]
