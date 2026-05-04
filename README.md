# java-error-handling-otel

## Objective

This repository is a lab for exploring how OpenTelemetry captures errors in a Java application. It contains a minimal Spring Boot service with a single endpoint that intentionally throws an exception. A global exception handler catches it, returns a standardised HTTP 500 response, and — following the [OTel exception recording spec](https://opentelemetry.io/docs/specs/otel/trace/exceptions/#recording-an-exception) — records the exception as an event on the active span and marks the span status as `ERROR`.

The result is that every error request produces a trace in Grafana Tempo with full stack trace, exception type, and error status — with zero manual instrumentation code in the business logic.

---

## How it works

### Endpoint

`GET /error-test` always throws a `RuntimeException`:

```java
@GetMapping("/error-test")
public String triggerError() {
    throw new RuntimeException("Intentional error for OTel demo");
}
```

### GlobalExceptionHandler

`@RestControllerAdvice` intercepts every unhandled exception across the application. Beyond returning the HTTP 500 response, it explicitly instruments the active OTel span:

```java
@ExceptionHandler(Exception.class)
public ResponseEntity<Map<String, String>> handleAll(Exception ex) {
    Span span = Span.current();
    span.recordException(ex);
    span.setStatus(StatusCode.ERROR, ex.getMessage());

    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                         .body(Map.of("message", "error"));
}
```

| Call | Effect on the trace |
|---|---|
| `Span.current()` | Retrieves the active span created automatically by the OTel Java agent for the incoming HTTP request |
| `span.recordException(ex)` | Adds an event named `exception` to the span containing `exception.type`, `exception.message`, and `exception.stacktrace` attributes |
| `span.setStatus(StatusCode.ERROR, ex.getMessage())` | Sets the span status to `ERROR` with the exception message as description, making the span queryable as an error in Tempo |

### OTel auto-instrumentation

The [OpenTelemetry Java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation) (`v2.9.0`) is attached via `-javaagent` at startup. It automatically creates spans for every incoming HTTP request, outgoing HTTP calls, database queries, and more — without any changes to application code. The `opentelemetry-api` dependency (`1.42.1`) is included only at compile time so the handler can access `Span.current()`; the agent provides the full implementation at runtime.

---

## Running locally with Docker

### Prerequisites
- Docker

### Build and run

```bash
docker build -t java-error-handling-otel:latest .

docker run --rm -p 8080:8080 \
  -e OTEL_SERVICE_NAME=java-error-handling-otel \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://<your-collector>:4317 \
  -e OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
  java-error-handling-otel:latest
```

If you don't have a collector, you can disable OTLP export and just run the app:

```bash
docker run --rm -p 8080:8080 \
  -e OTEL_TRACES_EXPORTER=none \
  java-error-handling-otel:latest
```

### Test

```bash
curl -i http://localhost:8080/error-test
# HTTP/1.1 500
# {"message":"error"}
```

---

## Running in Kubernetes (minikube)

### Prerequisites
- minikube (multi-node)
- kubectl
- Docker

### 1. Start minikube

```bash
minikube start
```

### 2. Build and load the image

```bash
docker build -t java-error-handling-otel:latest .
minikube image load java-error-handling-otel:latest
```

> `eval $(minikube docker-env)` does not work with multi-node clusters — use `minikube image load` instead.

### 3. Deploy

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

kubectl rollout status deployment/java-error-handling-otel -n java-error-handling-lab
```

The deployment is pre-configured to send traces to the Grafana k8s monitoring Alloy receiver:

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://grafana-k8s-monitoring-alloy-receiver.grafana-k8s-monitoring.svc.cluster.local:4317
```

Update `k8s/deployment.yaml` if your collector endpoint is different.

### 4. Generate load

```bash
# 20 requests (default), 0.2s apart
./generate-load.sh

# Custom: 50 requests, 0.5s apart
./generate-load.sh 50 0.5
```

The script handles port-forwarding automatically and cleans up on exit.

### 5. Verify traces in Grafana Tempo

Query with TraceQL in Grafana Explore:

```
{.service.name="java-error-handling-otel"} && {status=error}
```

Each trace should show:
- Span status: `ERROR`
- Event: `exception` with `exception.type`, `exception.message`, and `exception.stacktrace`

---

## Project structure

```
.
├── Dockerfile                          # Multi-stage build + OTel agent download
├── generate-load.sh                    # Port-forward + load generation script
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── pom.xml
└── src/main/java/com/example/otel_demo/
    ├── OtelDemoApplication.java
    ├── controller/ErrorController.java         # GET /error-test
    └── exception/GlobalExceptionHandler.java   # OTel exception recording
```
