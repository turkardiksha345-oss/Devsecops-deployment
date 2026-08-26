#!/usr/bin/env bash
# ==============================================================================
# AWS EC2 Provisioning & Docker Setup Script
# Target OS: Ubuntu 22.04 LTS / 24.04 LTS
# Description: Configures Docker, non-root user permissions, security firewall,
#              and deployment workspace for DevSecOps Python Application.
# ==============================================================================

set -euo pipefail

echo "========================================================="
echo " Starting AWS EC2 Server Initialization for DevSecOps"
echo "========================================================="

# 1. Update system packages
echo "[*] Updating apt package lists and upgrading system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Install prerequisites
echo "[*] Installing prerequisite tools (curl, git, ufw, ca-certificates, gnupg)..."
sudo apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw \
    jq

# 3. Install Docker CE
echo "[*] Setting up official Docker GPG key and repository..."
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Configure Docker daemon for production (log rotation & live restore)
echo "[*] Configuring Docker daemon settings..."
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF

sudo systemctl restart docker
sudo systemctl enable docker

# 5. Add current user to docker group
echo "[*] Adding user '${USER}' to docker group..."
sudo usermod -aG docker "$USER"

# 6. Create deployment workspace
DEPLOY_DIR="/opt/devsecops-app"
echo "[*] Creating deployment directory: ${DEPLOY_DIR}..."
sudo mkdir -p "${DEPLOY_DIR}"
sudo chown -R "$USER:$USER" "${DEPLOY_DIR}"

# 7. Configure host firewall (UFW)
echo "[*] Configuring UFW firewall rules..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Allow SSH (Ensure to restrict this IP via EC2 Security Group in AWS Console)
sudo ufw allow 22/tcp comment 'SSH Access'
# Allow Web Application traffic
sudo ufw allow 80/tcp comment 'HTTP Web Traffic'
sudo ufw allow 443/tcp comment 'HTTPS Web Traffic'
sudo ufw allow 5000/tcp comment 'Flask App Port'
# Enable UFW without prompting
echo "y" | sudo ufw enable

echo "========================================================="
echo " EC2 Provisioning Complete!"
echo " Docker Version: $(docker --version)"
echo " Deployment Path: ${DEPLOY_DIR}"
echo " Note: Please log out and back in for group changes to take effect."
echo "========================================================="
