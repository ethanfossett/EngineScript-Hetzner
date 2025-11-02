# Hetzner Cloud Compatibility Guide

## Overview

EngineScript now includes **automatic compatibility patching** for Hetzner Cloud and other cloud providers that use systemd predictable network interface names (e.g., `ens3`, `ens10`) instead of traditional `eth0`.

This system ensures that your EngineScript installation remains compatible with Hetzner Cloud even when pulling updates from the main repository.

---

## How It Works

### The Problem

The main EngineScript repository was originally designed for DigitalOcean, which uses `eth0` as the network interface name. Hetzner Cloud (and many modern cloud providers) use **systemd predictable network names** like:

- `ens3` (common on Hetzner Cloud)
- `ens10` (common on Hetzner Cloud)
- `ens5` (common on AWS EC2)
- `ens4` (common on Google Cloud)

Hardcoded `eth0` references in the scripts cause:
- ❌ Nginx HTTP/3 QUIC GSO detection to fail
- ❌ Kernel IPv6 tuning to apply to wrong interface
- ❌ Potential startup failures on non-DigitalOcean platforms

### The Solution

**Automatic Post-Update Patching System** that:
1. ✅ Detects the primary network interface dynamically
2. ✅ Patches scripts after each update from main repository
3. ✅ Runs automatically during `es.update` and cron-based auto-updates
4. ✅ Can be triggered manually with `es.patch` command
5. ✅ Logs all operations to `/var/log/EngineScript/hetzner-patch.log`

---

## Installation on Hetzner Cloud

### Step 1: Initial Setup

On a fresh Hetzner Cloud VPS running Ubuntu 24.04:

```bash
bash <(curl -s https://raw.githubusercontent.com/EngineScript/EngineScript/master/setup.sh)
```

### Step 2: Configure for Hetzner

After reboot, edit the configuration:

```bash
es.config
```

Set the following options:

```bash
# Enable Hetzner Cloud monitoring agent
INSTALL_HETZNER_CLOUD_AGENT=1

# Disable DigitalOcean agents
INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0
INSTALL_DIGITALOCEAN_METRICS_AGENT=0
```

Fill in all other required fields (Cloudflare API, passwords, etc.)

### Step 3: Run Installation

```bash
es.install
```

The installation will:
1. Install all EngineScript components
2. Automatically detect your network interface (e.g., `ens3`)
3. Apply Hetzner-specific patches
4. Install Hetzner Cloud monitoring agent (if on Hetzner infrastructure)

---

## Automatic Patching

### When Patches Are Applied

The auto-patch system runs automatically:

1. **During Manual Updates**
   ```bash
   es.update
   ```
   Patches are applied immediately after pulling from GitHub

2. **During Auto-Updates** (if `ENGINESCRIPT_AUTO_UPDATE=1`)
   - Runs daily via cron
   - Automatically patches after each update

3. **On Manual Trigger**
   ```bash
   es.patch
   ```
   Run anytime to reapply patches

### What Gets Patched

#### Patch 1: Nginx HTTP/3 QUIC GSO Detection
**File:** `/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh`

**Before:**
```bash
if [[ "${INSTALL_HTTP3}" = 1 ]] && ethtool -k eth0 | grep "tx-gso-robust: on"; then
```

**After:**
```bash
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
if [[ -n "${PRIMARY_NIC}" ]] && ethtool -k "${PRIMARY_NIC}" 2>/dev/null | grep -q "tx-gso-robust: on"; then
```

#### Patch 2: Kernel IPv6 Configuration
**File:** `/usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh`

**Added:**
```bash
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
if [[ -n "${PRIMARY_NIC}" ]] && [[ "${PRIMARY_NIC}" != "eth0" ]]; then
  sed -i "s/net.ipv6.conf.eth0./net.ipv6.conf.${PRIMARY_NIC}./g" /etc/sysctl.d/60-enginescript.conf
fi
```

#### Patch 3: Hetzner Cloud Install Script
**File:** `/usr/local/bin/enginescript/scripts/install/system-misc/hetzner-cloud-install.sh`

- Ensures the script exists
- Makes it executable
- Recreates if missing after update

#### Patch 4: Main Install Script Integration
**File:** `/usr/local/bin/enginescript/scripts/install/enginescript-install.sh`

- Adds Hetzner Cloud agent installation block
- Mirrors DigitalOcean agent pattern
- Conditional based on `INSTALL_HETZNER_CLOUD_AGENT` flag

---

## Monitoring & Logs

### Patch Log Location

```bash
/var/log/EngineScript/hetzner-patch.log
```

### View Patch Log

```bash
cat /var/log/EngineScript/hetzner-patch.log
```

### Example Log Output

```
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Hetzner Cloud Compatibility Auto-Patcher v1.0.0
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15]
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Checking Nginx Tune for hardcoded eth0...
[2025-11-02 14:30:15] Applying dynamic network interface detection patch...
[2025-11-02 14:30:15] ✓ Nginx Tune patched successfully
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Checking Kernel Tweaks for hardcoded eth0...
[2025-11-02 14:30:15] Applying dynamic network interface detection patch...
[2025-11-02 14:30:15] ✓ Kernel Tweaks patched successfully
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Checking for Hetzner Cloud install script...
[2025-11-02 14:30:15] ✓ Hetzner Cloud install script exists
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Checking main install script for Hetzner support...
[2025-11-02 14:30:15] ✓ Main install script already has Hetzner support
[2025-11-02 14:30:15]
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15] Patching Summary:
[2025-11-02 14:30:15]   Patches Applied: 4
[2025-11-02 14:30:15]   Patches Failed:  0
[2025-11-02 14:30:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-11-02 14:30:15]
[2025-11-02 14:30:15] ✓ All Hetzner Cloud compatibility patches applied successfully
```

---

## Manual Commands

### Apply Patches Manually

```bash
es.patch
```

### Check Current Network Interface

```bash
ip -o -4 route show to default | awk '{print $5}'
```

Example output on Hetzner Cloud:
```
ens3
```

Example output on DigitalOcean:
```
eth0
```

### Verify Nginx Configuration

```bash
ng.test
```

### Check Patch Status

```bash
tail -50 /var/log/EngineScript/hetzner-patch.log
```

---

## Troubleshooting

### Issue: Patches Not Applying

**Check if auto-patch is enabled:**

```bash
grep INSTALL_HETZNER_CLOUD_AGENT /home/EngineScript/enginescript-install-options.txt
```

Should show:
```
INSTALL_HETZNER_CLOUD_AGENT=1
```

**Manually trigger patches:**

```bash
es.patch
```

### Issue: Nginx Fails to Start

**Check detected interface:**

```bash
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
echo "Detected interface: ${PRIMARY_NIC}"
```

**Check if interface has proper configuration:**

```bash
ethtool -k ens3
```

**Check sysctl configuration:**

```bash
grep "net.ipv6.conf." /etc/sysctl.d/60-enginescript.conf
```

### Issue: Update Removed Patches

This should never happen with the auto-patch system, but if it does:

1. Check that `/home/EngineScript/enginescript-install-options.txt` has `INSTALL_HETZNER_CLOUD_AGENT=1`
2. Run `es.patch` manually
3. Check patch log: `cat /var/log/EngineScript/hetzner-patch.log`

---

## Compatibility Matrix

| Cloud Provider | Interface Name | Compatible | Auto-Patched |
|----------------|----------------|------------|--------------|
| Hetzner Cloud  | `ens3`, `ens10` | ✅ Yes | ✅ Yes |
| DigitalOcean   | `eth0` | ✅ Yes | ✅ Yes (no-op) |
| AWS EC2        | `ens5`, `eth0` | ✅ Yes | ✅ Yes |
| Google Cloud   | `ens4` | ✅ Yes | ✅ Yes |
| Azure          | `eth0` | ✅ Yes | ✅ Yes (no-op) |
| Vultr          | Various | ✅ Yes | ✅ Yes |
| Linode         | Various | ✅ Yes | ✅ Yes |
| Bare Metal     | Various | ✅ Yes | ✅ Yes |

---

## Advanced Configuration

### Disable Auto-Patching

If you want to disable automatic patching:

```bash
es.config
```

Set:
```bash
INSTALL_HETZNER_CLOUD_AGENT=0
```

And remove the patch log:
```bash
rm /var/log/EngineScript/hetzner-patch.log
```

**Note:** This is NOT recommended on Hetzner Cloud or other non-DigitalOcean providers.

### Custom Patch Script

The patch script is located at:
```
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/hetzner-compatibility-patch.sh
```

You can modify it to add additional custom patches for your environment.

### Backup Files

Timestamped backups are created before patching:
```
/usr/local/bin/enginescript/scripts/install/nginx/nginx-tune.sh.backup.20251102_143022
/usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh.backup.20251102_143022
```

To restore a backup:
```bash
cp nginx-tune.sh.backup.20251102_143022 nginx-tune.sh
```

---

## FAQ

### Q: Will this break compatibility with DigitalOcean?

**A:** No. The patches dynamically detect the network interface. On DigitalOcean, it will detect `eth0` and work exactly as before.

### Q: Do I need to enable this on DigitalOcean?

**A:** No. The patches are designed to be no-ops on DigitalOcean. But enabling them won't break anything.

### Q: Will future updates overwrite the patches?

**A:** No! That's the whole point of the auto-patch system. After each `git pull`, the patches are automatically reapplied.

### Q: Can I submit these patches to the main repository?

**A:** Yes! Please do. These fixes benefit the entire EngineScript community and make it truly cloud-agnostic. Submit a PR to the main repository.

### Q: What if the main repository adds native Hetzner support?

**A:** The patch system will detect that the fixes are already applied and skip patching (no-op). This is safe.

### Q: How do I know if patches are being applied?

**A:** Check the log file:
```bash
cat /var/log/EngineScript/hetzner-patch.log
```

Or run `es.patch` manually and watch the output.

---

## Support

If you encounter issues with Hetzner Cloud compatibility:

1. Check the patch log: `cat /var/log/EngineScript/hetzner-patch.log`
2. Manually run patches: `es.patch`
3. Check your network interface: `ip -o -4 route show to default | awk '{print $5}'`
4. Submit an issue: [GitHub Issues](https://github.com/EngineScript/EngineScript/issues)

---

## Credits

This compatibility system was developed to enable EngineScript to run on Hetzner Cloud and other modern cloud providers that use systemd predictable network interface names.

**License:** MIT
