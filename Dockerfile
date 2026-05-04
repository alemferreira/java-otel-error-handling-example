FROM eclipse-temurin:17-jdk AS build
WORKDIR /app
COPY . .
RUN ./mvnw package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    wget -q -O /otel-agent.jar \
      https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar && \
    apt-get remove -y wget && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/target/java-error-handling-otel-*.jar app.jar

ENV JAVA_TOOL_OPTIONS="-javaagent:/otel-agent.jar"

ENTRYPOINT ["java", "-jar", "app.jar"]
