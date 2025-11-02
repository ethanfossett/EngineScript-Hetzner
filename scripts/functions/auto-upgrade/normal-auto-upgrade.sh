#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh

# Verify EngineScript installation is complete before proceeding
verify_installation_completion

#----------------------------------------------------------------------------------
# Start Main Script

# Upgrade Scripts will be found below:

#----------------------------------------------------------------------------------
# Apply Hetzner Cloud Compatibility Patches (if enabled)
# This ensures compatibility with Hetzner Cloud and other non-DigitalOcean providers
# after pulling updates from the main repository
#----------------------------------------------------------------------------------
if [[ "${INSTALL_HETZNER_CLOUD_AGENT}" == "1" ]] || [[ -f "/var/log/EngineScript/hetzner-patch.log" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Applying Hetzner Cloud Compatibility Patches"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  /usr/local/bin/enginescript/scripts/functions/auto-upgrade/hetzner-compatibility-patch.sh
  echo ""
fi
