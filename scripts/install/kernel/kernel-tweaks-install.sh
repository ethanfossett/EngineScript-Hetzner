#!/usr/bin/env bash
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


#----------------------------------------------------------------------------------
# Start Main Script

# Kernel Tweaks
cp -rf /usr/local/bin/enginescript/config/etc/sysctl.d/60-enginescript.conf /etc/sysctl.d/60-enginescript.conf

# Dynamically detect the primary network interface (works on all cloud providers)
# This fixes compatibility with Hetzner Cloud and other providers that don't use eth0
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)

if [[ -n "${PRIMARY_NIC}" ]] && [[ "${PRIMARY_NIC}" != "eth0" ]]; then
  echo "Detected primary network interface: ${PRIMARY_NIC} (not eth0)"
  echo "Updating sysctl configuration for cloud provider compatibility..."

  # Replace eth0 with the detected interface name
  sed -i "s/net.ipv6.conf.eth0./net.ipv6.conf.${PRIMARY_NIC}./g" /etc/sysctl.d/60-enginescript.conf
else
  echo "Using default network interface: eth0"
fi

chown -R root:root /etc/sysctl.d/60-enginescript.conf
chmod 0664 /etc/sysctl.d/60-enginescript.conf

# KTLS (testing)
echo tls >/etc/modules-load.d/tls.conf

# Enable Kernel Tweaks
sysctl -e -p /etc/sysctl.d/60-enginescript.conf
sysctl --system
