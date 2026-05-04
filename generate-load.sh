#!/bin/bash

NAMESPACE="java-error-handling-lab"
DEPLOYMENT="java-error-handling-otel"
LOCAL_PORT=8081
REMOTE_PORT=8080
ENDPOINT="/error-test"
REQUESTS=${1:-20}
DELAY=${2:-0.2}

cleanup() {
  echo "Stopping port-forward (PID $PF_PID)..."
  kill "$PF_PID" 2>/dev/null
  exit 0
}
trap cleanup INT TERM EXIT

echo "Starting port-forward to $DEPLOYMENT..."
kubectl port-forward -n "$NAMESPACE" "deploy/$DEPLOYMENT" "$LOCAL_PORT:$REMOTE_PORT" > /tmp/pf-load.log 2>&1 &
PF_PID=$!

until curl -sf "http://localhost:$LOCAL_PORT$ENDPOINT" > /dev/null 2>&1; do
  sleep 1
done
echo "Port-forward ready. Sending $REQUESTS requests with ${DELAY}s delay..."

SUCCESS=0
FAIL=0
for i in $(seq 1 "$REQUESTS"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LOCAL_PORT$ENDPOINT")
  if [ "$STATUS" -eq 500 ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
  echo "  [$i/$REQUESTS] HTTP $STATUS"
  sleep "$DELAY"
done

echo ""
echo "Done. $SUCCESS x HTTP 500 (expected), $FAIL unexpected."
