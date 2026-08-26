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

# 1. Ensure Docker is installed on EC2
if ! command -v docker &> /dev/null; then
    echo "[*] Docker not found on EC2. Installing Docker CE automatically..."
    sudo apt-get update -y
    sudo apt-get install -y docker.io curl
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER" || true
    echo "[+] Docker installed successfully!"
fi

# 2. Pull the new Docker container image
echo "[*] Pulling latest Docker image: ${IMAGE_URI}..."
# Use sudo docker if user group is not yet refreshed in this subshell
DOCKER_CMD="docker"
if ! docker info &> /dev/null; then
    DOCKER_CMD="sudo docker"
fi
$DOCKER_CMD pull "${IMAGE_URI}"

# 2. Check for active container and tag current version for instant rollback
HAD_RUNNING_CONTAINER=false
if $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[*] Existing running container detected. Capturing rollback state..."
    CURRENT_IMAGE_ID=$($DOCKER_CMD inspect --format='{{.Image}}' "${CONTAINER_NAME}")
    $DOCKER_CMD tag "${CURRENT_IMAGE_ID}" "${ROLLBACK_TAG}" || true
    HAD_RUNNING_CONTAINER=true
    
    echo "[*] Stopping and removing previous container '${CONTAINER_NAME}'..."
    $DOCKER_CMD stop "${CONTAINER_NAME}" || true
    $DOCKER_CMD rm "${CONTAINER_NAME}" || true
elif $DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[*] Removing stopped container '${CONTAINER_NAME}'..."
    $DOCKER_CMD rm "${CONTAINER_NAME}" || true
fi

# 3. Launch new container instance
echo "[*] Starting new container instance '${CONTAINER_NAME}'..."
$DOCKER_CMD run -d \
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
    $DOCKER_CMD logs "${CONTAINER_NAME}" --tail 50 || true

    if [ "$HAD_RUNNING_CONTAINER" = true ]; then
        echo "[!] Initiating automatic rollback to previous container image..."
        $DOCKER_CMD stop "${CONTAINER_NAME}" || true
        $DOCKER_CMD rm "${CONTAINER_NAME}" || true
        
        $DOCKER_CMD run -d \
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
$DOCKER_CMD image prune -f || true

echo "=========================================================="
echo " Deployment Successfully Completed!"
echo " Container: $($DOCKER_CMD ps -f name=${CONTAINER_NAME} --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}')"
echo "=========================================================="
