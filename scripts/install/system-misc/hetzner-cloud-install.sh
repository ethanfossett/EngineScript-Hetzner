#!/bin/bash

################################################################################
# Script Name: hetzner-cloud-install.sh
# Description: Installs Hetzner Cloud monitoring agent for enhanced server metrics
# Author: EngineScript
# License: MIT
################################################################################

# Source common functions and variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh

################################################################################
# Display Header
################################################################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Hetzner Cloud Agent Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

################################################################################
# Check if running on Hetzner Cloud
################################################################################
check_hetzner_cloud() {
  # Check if the server is running on Hetzner Cloud by checking metadata service
  if curl -s --connect-timeout 2 http://169.254.169.254/hetzner/v1/metadata 2>/dev/null | grep -q "instance-id"; then
    return 0
  else
    return 1
  fi
}

################################################################################
# Install Hetzner Cloud Monitoring Agent
################################################################################
install_hetzner_monitoring() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Installing Hetzner Cloud Monitoring Agent"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check if agent is already installed
  if command -v hcloud-metrics-agent &> /dev/null; then
    echo "✓ Hetzner Cloud Monitoring Agent is already installed"
    return 0
  fi

  # Download and install the agent
  echo "Downloading Hetzner Cloud Monitoring Agent..."

  # Determine architecture
  ARCH="$(uname -m)"
  if [[ "${ARCH}" == "x86_64" ]]; then
    AGENT_ARCH="amd64"
  elif [[ "${ARCH}" == "aarch64" ]]; then
    AGENT_ARCH="arm64"
  else
    echo "⚠ Unsupported architecture: ${ARCH}"
    echo "Hetzner Cloud Monitoring Agent installation skipped."
    return 1
  fi

  # Latest version URL (Hetzner provides a static link)
  AGENT_URL="https://github.com/hetznercloud/csi-driver/releases/latest/download/hcloud-metrics-agent-linux-${AGENT_ARCH}"

  # Download the agent
  if wget -q "${AGENT_URL}" -O /usr/local/bin/hcloud-metrics-agent; then
    chmod +x /usr/local/bin/hcloud-metrics-agent
    echo "✓ Hetzner Cloud Monitoring Agent downloaded successfully"
  else
    echo "⚠ Failed to download Hetzner Cloud Monitoring Agent"
    echo "Installation will continue, but monitoring metrics may not be available."
    return 1
  fi

  # Create systemd service
  cat > /etc/systemd/system/hcloud-metrics-agent.service <<'EOF'
[Unit]
Description=Hetzner Cloud Metrics Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hcloud-metrics-agent
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  # Enable and start the service
  systemctl daemon-reload
  systemctl enable hcloud-metrics-agent.service
  systemctl start hcloud-metrics-agent.service

  if systemctl is-active --quiet hcloud-metrics-agent.service; then
    echo "✓ Hetzner Cloud Monitoring Agent installed and started successfully"
    return 0
  else
    echo "⚠ Hetzner Cloud Monitoring Agent service failed to start"
    return 1
  fi
}

################################################################################
# Main Installation Process
################################################################################
main() {
  echo "Checking if server is running on Hetzner Cloud..."

  if check_hetzner_cloud; then
    echo "✓ Detected Hetzner Cloud environment"
    install_hetzner_monitoring
  else
    echo "ℹ This server is not running on Hetzner Cloud"
    echo "Hetzner Cloud agent installation is not required."
    echo ""
    echo "Note: This is not an error. The agent is only useful on Hetzner Cloud servers."
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Hetzner Cloud Agent Installation Complete"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# Run main function
main

exit 0
