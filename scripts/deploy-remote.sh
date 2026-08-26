#!/usr/bin/env bash
# ==============================================================================
# Remote Deployment Script for AWS EC2
# Executes zero-downtime container upgrade with automated health validation
# and instant rollback capability.
# ==============================================================================

set -euo pipefail

IMAGE_URI="${1:-ghcr.io/turkardiksha345-oss/devsecops-deployment:latest}"
APP_PORT="${2:-5000}"
CONTAINER_NAME="${3:-devsecops-flask-app}"
ROLLBACK_TAG="devsecops-flask-app:rollback"

echo "=========================================================="
echo " Starting Application Deployment to AWS EC2"
echo " Image:          ${IMAGE_URI}"
echo " Container Name: ${CONTAINER_NAME}"
echo " Port:           ${APP_PORT}"
echo " Timestamp:      $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=========================================================="

# 1. Pull the new Docker container image
echo "[*] Pulling latest Docker image: ${IMAGE_URI}..."
docker pull "${IMAGE_URI}"

# 2. Check for active container and tag current version for instant rollback
HAD_RUNNING_CONTAINER=false
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[*] Existing running container detected. Capturing rollback state..."
    CURRENT_IMAGE_ID=$(docker inspect --format='{{.Image}}' "${CONTAINER_NAME}")
    docker tag "${CURRENT_IMAGE_ID}" "${ROLLBACK_TAG}" || true
    HAD_RUNNING_CONTAINER=true
    
    echo "[*] Stopping and removing previous container '${CONTAINER_NAME}'..."
    docker stop "${CONTAINER_NAME}" || true
    docker rm "${CONTAINER_NAME}" || true
elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[*] Removing stopped container '${CONTAINER_NAME}'..."
    docker rm "${CONTAINER_NAME}" || true
fi

# 3. Launch new container instance
echo "[*] Starting new container instance '${CONTAINER_NAME}'..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart always \
    -p "${APP_PORT}:5000" \
    -e FLASK_ENV=production \
    -e APP_NAME="DevSecOps Flask App" \
    -e PORT=5000 \
    "${IMAGE_URI}"

# 4. Perform Automated Health Validation
echo "[*] Verifying container health via http://localhost:${APP_PORT}/health..."
MAX_ATTEMPTS=15
ATTEMPT=1
HEALTHY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "    Attempt $ATTEMPT/$MAX_ATTEMPTS: checking /health endpoint..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${APP_PORT}/health" || echo "000")
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "[+] Healthcheck PASSED (HTTP 200)!"
        HEALTHY=true
        break
    fi
    
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

# 5. Rollback or Finalize
if [ "$HEALTHY" = false ]; then
    echo "[!] CRITICAL: Container health check FAILED after $MAX_ATTEMPTS attempts!"
    echo "[!] Inspecting container logs:"
    docker logs "${CONTAINER_NAME}" --tail 50 || true

    if [ "$HAD_RUNNING_CONTAINER" = true ]; then
        echo "[!] Initiating automatic rollback to previous container image..."
        docker stop "${CONTAINER_NAME}" || true
        docker rm "${CONTAINER_NAME}" || true
        
        docker run -d \
            --name "${CONTAINER_NAME}" \
            --restart always \
            -p "${APP_PORT}:5000" \
            -e FLASK_ENV=production \
            "${ROLLBACK_TAG}"
        
        echo "[+] Rollback complete. Previous version restored."
    fi
    exit 1
fi

# 6. Cleanup dangling / unused Docker images
echo "[*] Pruning dangling Docker images to preserve disk space..."
docker image prune -f || true

echo "=========================================================="
echo " Deployment Successfully Completed!"
echo " Container: $(docker ps -f name=${CONTAINER_NAME} --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}')"
echo "=========================================================="
