#!/usr/bin/env bash
################################################################################
# Script Name: hetzner-compatibility-patch.sh
# Description: Automatically patches EngineScript for Hetzner Cloud compatibility
#              after pulling updates from the main repository
# Author: EngineScript Community
# License: MIT
################################################################################

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh

################################################################################
# Constants
################################################################################
PATCH_LOG="/var/log/EngineScript/hetzner-patch.log"
PATCH_VERSION="1.0.0"

################################################################################
# Logging Function
################################################################################
log_patch() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${PATCH_LOG}"
}

################################################################################
# Check if patch is needed
################################################################################
check_if_patch_needed() {
  local file="$1"
  local pattern="$2"

  if grep -q "${pattern}" "${file}" 2>/dev/null; then
    return 1  # Patch already applied
  else
    return 0  # Patch needed
  fi
}

################################################################################
# Patch 1: Nginx Tune - Dynamic Network Interface Detection
################################################################################
patch_nginx_tune() {
  local TARGET_FILE="/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh"

  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Checking Nginx Tune for hardcoded eth0..."

  if [[ ! -f "${TARGET_FILE}" ]]; then
    log_patch "⚠ Warning: ${TARGET_FILE} not found, skipping patch"
    return 1
  fi

  # Check if already patched
  if check_if_patch_needed "${TARGET_FILE}" "PRIMARY_NIC="; then
    log_patch "✓ Nginx Tune already patched, skipping"
    return 0
  fi

  # Check if old hardcoded eth0 pattern exists
  if ! grep -q 'ethtool -k eth0' "${TARGET_FILE}"; then
    log_patch "ℹ Old pattern not found, may be using different format"
    return 0
  fi

  log_patch "Applying dynamic network interface detection patch..."

  # Create backup
  cp "${TARGET_FILE}" "${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

  # Apply patch: Replace the hardcoded eth0 block with dynamic detection
  # Find the line with "HTTP3 - QUIC GSO" comment and replace the entire block
  if sed -i '/# HTTP3 - QUIC GSO (requires hardware support check)/,/^fi$/c\
# HTTP3 - QUIC GSO (requires hardware support check)\
# Dynamically detect the primary network interface (works on all cloud providers)\
if [[ "${INSTALL_HTTP3}" = 1 ]]; then\
  # Get the primary network interface (not lo, not virtual)\
  PRIMARY_NIC=$(ip -o -4 route show to default | awk '\''{print $5}'\'' | head -n1)\
\
  if [[ -n "${PRIMARY_NIC}" ]] && ethtool -k "${PRIMARY_NIC}" 2>/dev/null | grep -q "tx-gso-robust: on"; then\
    sed -i "s|#quic_gso on|quic_gso on|g" /etc/nginx/nginx.conf\
    echo "QUIC GSO enabled on interface ${PRIMARY_NIC}"\
  else\
    echo "QUIC GSO not available on interface ${PRIMARY_NIC} or interface not found, skipping..."\
  fi\
fi' "${TARGET_FILE}"; then
    log_patch "✓ Nginx Tune patched successfully"
    return 0
  else
    log_patch "✗ Failed to patch Nginx Tune"
    return 1
  fi
}

################################################################################
# Patch 2: Kernel Tweaks - Dynamic Network Interface Detection
################################################################################
patch_kernel_tweaks() {
  local TARGET_FILE="/usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh"

  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Checking Kernel Tweaks for hardcoded eth0..."

  if [[ ! -f "${TARGET_FILE}" ]]; then
    log_patch "⚠ Warning: ${TARGET_FILE} not found, skipping patch"
    return 1
  fi

  # Check if already patched
  if check_if_patch_needed "${TARGET_FILE}" "PRIMARY_NIC="; then
    log_patch "✓ Kernel Tweaks already patched, skipping"
    return 0
  fi

  log_patch "Applying dynamic network interface detection patch..."

  # Create backup
  cp "${TARGET_FILE}" "${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

  # Apply patch: Add dynamic interface detection after copying config file
  if sed -i '/^cp -rf .*60-enginescript.conf.*$/a\
\
# Dynamically detect the primary network interface (works on all cloud providers)\
# This fixes compatibility with Hetzner Cloud and other providers that don'\''t use eth0\
PRIMARY_NIC=$(ip -o -4 route show to default | awk '\''{print $5}'\'' | head -n1)\
\
if [[ -n "${PRIMARY_NIC}" ]] && [[ "${PRIMARY_NIC}" != "eth0" ]]; then\
  echo "Detected primary network interface: ${PRIMARY_NIC} (not eth0)"\
  echo "Updating sysctl configuration for cloud provider compatibility..."\
\
  # Replace eth0 with the detected interface name\
  sed -i "s/net.ipv6.conf.eth0./net.ipv6.conf.${PRIMARY_NIC}./g" /etc/sysctl.d/60-enginescript.conf\
else\
  echo "Using default network interface: eth0"\
fi' "${TARGET_FILE}"; then
    log_patch "✓ Kernel Tweaks patched successfully"
    return 0
  else
    log_patch "✗ Failed to patch Kernel Tweaks"
    return 1
  fi
}

################################################################################
# Patch 3: Ensure Hetzner Cloud Install Script Exists
################################################################################
patch_hetzner_install_script() {
  local TARGET_FILE="/usr/local/bin/enginescript/scripts/install/system-misc/hetzner-cloud-install.sh"

  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Checking for Hetzner Cloud install script..."

  if [[ -f "${TARGET_FILE}" ]]; then
    log_patch "✓ Hetzner Cloud install script exists"
    return 0
  fi

  log_patch "Creating Hetzner Cloud install script..."

  cat > "${TARGET_FILE}" <<'EOFSCRIPT'
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
EOFSCRIPT

  chmod +x "${TARGET_FILE}"
  log_patch "✓ Hetzner Cloud install script created successfully"
  return 0
}

################################################################################
# Patch 4: Ensure Main Install Script Has Hetzner Support
################################################################################
patch_main_install_script() {
  local TARGET_FILE="/usr/local/bin/enginescript/scripts/install/enginescript-install.sh"

  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Checking main install script for Hetzner support..."

  if [[ ! -f "${TARGET_FILE}" ]]; then
    log_patch "⚠ Warning: ${TARGET_FILE} not found, skipping patch"
    return 1
  fi

  # Check if already patched
  if grep -q "INSTALL_HETZNER_CLOUD_AGENT" "${TARGET_FILE}"; then
    log_patch "✓ Main install script already has Hetzner support"
    return 0
  fi

  log_patch "Adding Hetzner Cloud agent support to main install script..."

  # Create backup
  cp "${TARGET_FILE}" "${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

  # Find the DigitalOcean block and add Hetzner block after it
  if sed -i '/^# DigitalOcean Remote Console/,/^fi$/!b;/^fi$/a\
\
# Hetzner Cloud Monitoring Agent (optional)\
if [[ "${INSTALL_HETZNER_CLOUD_AGENT}" = "1" ]]; then\
  if [[ "${HETZNER_AGENT}" = 1 ]];\
    then\
      echo "Hetzner Cloud Monitoring Agent script has already run."\
    else\
      /usr/local/bin/enginescript/scripts/install/system-misc/hetzner-cloud-install.sh 2>> /tmp/enginescript_install_errors.log\
      echo "HETZNER_AGENT=1" >> /var/log/EngineScript/install-log.log\
  fi\
  print_last_errors\
  debug_pause "Hetzner Cloud Monitoring Agent"\
fi' "${TARGET_FILE}"; then
    log_patch "✓ Main install script patched successfully"
    return 0
  else
    log_patch "✗ Failed to patch main install script"
    return 1
  fi
}

################################################################################
# Main Execution
################################################################################
main() {
  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Hetzner Cloud Compatibility Auto-Patcher v${PATCH_VERSION}"
  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch ""

  local PATCHES_APPLIED=0
  local PATCHES_FAILED=0

  # Apply all patches
  patch_nginx_tune && ((PATCHES_APPLIED++)) || ((PATCHES_FAILED++))
  patch_kernel_tweaks && ((PATCHES_APPLIED++)) || ((PATCHES_FAILED++))
  patch_hetzner_install_script && ((PATCHES_APPLIED++)) || ((PATCHES_FAILED++))
  patch_main_install_script && ((PATCHES_APPLIED++)) || ((PATCHES_FAILED++))

  log_patch ""
  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch "Patching Summary:"
  log_patch "  Patches Applied: ${PATCHES_APPLIED}"
  log_patch "  Patches Failed:  ${PATCHES_FAILED}"
  log_patch "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_patch ""

  if [[ ${PATCHES_FAILED} -eq 0 ]]; then
    log_patch "✓ All Hetzner Cloud compatibility patches applied successfully"
    return 0
  else
    log_patch "⚠ Some patches failed. Check log for details: ${PATCH_LOG}"
    return 1
  fi
}

# Run main function
main

exit 0
