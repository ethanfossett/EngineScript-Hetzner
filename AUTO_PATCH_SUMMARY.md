# Automatic Compatibility Patching - Technical Summary

## Overview

This document provides a technical overview of the automatic compatibility patching system implemented for Hetzner Cloud and multi-cloud support.

---

## Problem Statement

### Original Issue

EngineScript was designed with DigitalOcean as the primary target platform, which uses traditional `eth0` network interface naming. Modern cloud providers (Hetzner Cloud, AWS, GCP, etc.) use **systemd predictable network interface names** like `ens3`, `ens10`, `ens5`, etc.

### Hardcoded References

Two critical scripts contained hardcoded `eth0` references:

1. **`scripts/install/nginx/nginx-tune.sh:122`**
   - HTTP/3 QUIC GSO hardware capability detection
   - Failure mode: HTTP/3 features silently disabled

2. **`config/etc/sysctl.d/60-enginescript.conf:182-183`**
   - IPv6 kernel configuration applied via `scripts/install/kernel/kernel-tweaks-install.sh`
   - Failure mode: IPv6 security settings not applied to actual interface

### Impact

- ❌ Nginx HTTP/3 QUIC GSO never enabled on non-DigitalOcean platforms
- ❌ IPv6 router advertisements and autoconfiguration settings ineffective
- ❌ Potential performance degradation
- ❌ Installation failures on some Hetzner Cloud configurations

---

## Solution Architecture

### Design Goals

1. **Zero User Intervention**: Patches apply automatically after every update
2. **Idempotent**: Safe to run multiple times without side effects
3. **Non-Breaking**: Works on DigitalOcean (eth0) and all other providers
4. **Auditable**: Comprehensive logging of all patch operations
5. **Maintainable**: Single script manages all compatibility patches

### Components

#### 1. Patch Script
**Location:** `/usr/local/bin/enginescript/scripts/functions/auto-upgrade/hetzner-compatibility-patch.sh`

**Responsibilities:**
- Detects which patches are needed
- Applies patches with error handling
- Creates timestamped backups before modifications
- Logs all operations
- Reports success/failure status

**Patches Implemented:**

| Patch # | Target | Function | Detection Method |
|---------|--------|----------|------------------|
| 1 | nginx-tune.sh | Dynamic network interface for QUIC GSO | Checks for `PRIMARY_NIC=` variable |
| 2 | kernel-tweaks-install.sh | Dynamic network interface for IPv6 | Checks for `PRIMARY_NIC=` variable |
| 3 | hetzner-cloud-install.sh | Ensure Hetzner agent script exists | Checks file existence |
| 4 | enginescript-install.sh | Ensure Hetzner agent integration | Checks for `INSTALL_HETZNER_CLOUD_AGENT` |

#### 2. Update Integration
**Modified Files:**
- `scripts/update/enginescript-update.sh` (line 76-85)
- `scripts/functions/auto-upgrade/normal-auto-upgrade.sh` (line 25-36)

**Trigger Conditions:**
```bash
if [[ "${INSTALL_HETZNER_CLOUD_AGENT}" == "1" ]] || [[ -f "/var/log/EngineScript/hetzner-patch.log" ]]; then
```

**Logic:**
- Activates if user explicitly enabled Hetzner support (`INSTALL_HETZNER_CLOUD_AGENT=1`)
- OR if patch log exists (indicating previous Hetzner installation)
- Runs immediately after `git pull` in update workflow

#### 3. Manual Control
**Alias:** `es.patch`
**Location:** `/root/.bashrc` (added by `scripts/install/alias/enginescript-alias-install.sh`)

**Use Cases:**
- Manual testing
- Troubleshooting
- Re-applying patches after manual code changes
- Verification after updates

#### 4. Logging System
**Log File:** `/var/log/EngineScript/hetzner-patch.log`

**Format:**
```
[TIMESTAMP] MESSAGE
```

**Contents:**
- Patch execution start/end
- Individual patch status (✓ success, ✗ failure, ℹ info, ⚠ warning)
- File paths modified
- Backup file locations
- Summary statistics

---

## Technical Implementation

### Dynamic Network Interface Detection

**Method:**
```bash
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
```

**Why This Works:**
- Queries kernel routing table for default gateway
- Returns interface name of primary route
- Works on all Linux distributions
- No dependency on network manager or systemd
- Returns `eth0` on DigitalOcean, `ens3` on Hetzner, etc.

**Validation:**
```bash
if [[ -n "${PRIMARY_NIC}" ]] && ethtool -k "${PRIMARY_NIC}" 2>/dev/null | grep -q "tx-gso-robust: on"; then
```

### Idempotent Patch Detection

**Method:**
```bash
check_if_patch_needed() {
  local file="$1"
  local pattern="$2"

  if grep -q "${pattern}" "${file}" 2>/dev/null; then
    return 1  # Patch already applied
  else
    return 0  # Patch needed
  fi
}
```

**Signature Patterns:**
- Nginx Tune: `PRIMARY_NIC=`
- Kernel Tweaks: `PRIMARY_NIC=`
- Hetzner Script: File existence check
- Main Install: `INSTALL_HETZNER_CLOUD_AGENT` string presence

### Sed Replacement Strategy

**Nginx Tune - Block Replacement:**
```bash
sed -i '/# HTTP3 - QUIC GSO/,/^fi$/c\
[NEW BLOCK]
' "${TARGET_FILE}"
```

**Rationale:**
- Replaces entire block from comment to closing `fi`
- Preserves surrounding code
- Handles multi-line blocks correctly
- Maintains proper shell quoting

**Kernel Tweaks - Line Insertion:**
```bash
sed -i '/^cp -rf .*60-enginescript.conf.*$/a\
[NEW LINES]
' "${TARGET_FILE}"
```

**Rationale:**
- Inserts after specific line (copy command)
- Maintains file flow
- Doesn't disturb other configuration

**Main Install - Conditional Addition:**
```bash
sed -i '/^# DigitalOcean Remote Console/,/^fi$/!b;/^fi$/a\
[NEW BLOCK]
' "${TARGET_FILE}"
```

**Rationale:**
- Finds DigitalOcean block end
- Appends Hetzner block after
- Creates parallel structure
- Maintains code symmetry

### Backup System

**Format:**
```
{original_filename}.backup.{YYYYMMDD_HHMMSS}
```

**Example:**
```
nginx-tune.sh.backup.20251102_143022
```

**Benefits:**
- Timestamped for easy identification
- Preserves original in case of patch failure
- Allows manual rollback if needed
- Doesn't interfere with git operations (not tracked)

---

## Update Flow Diagram

```
User runs: es.update
    ↓
enginescript-update.sh
    ├─ git fetch origin master
    ├─ git checkout -f master
    ├─ git reset --hard FETCH_HEAD
    └─ Set permissions
    ↓
Check if patching enabled:
    if [[ "${INSTALL_HETZNER_CLOUD_AGENT}" == "1" ]] || [[ -f "/var/log/EngineScript/hetzner-patch.log" ]]
    ↓
    ├─ YES → Run hetzner-compatibility-patch.sh
    │   ├─ Patch 1: nginx-tune.sh
    │   │   ├─ Check if already patched → Skip if yes
    │   │   ├─ Create backup
    │   │   ├─ Apply sed replacement
    │   │   └─ Log result
    │   ├─ Patch 2: kernel-tweaks-install.sh
    │   │   ├─ Check if already patched → Skip if yes
    │   │   ├─ Create backup
    │   │   ├─ Apply sed insertion
    │   │   └─ Log result
    │   ├─ Patch 3: hetzner-cloud-install.sh
    │   │   ├─ Check if exists → Skip if yes
    │   │   ├─ Create script
    │   │   ├─ Set executable
    │   │   └─ Log result
    │   ├─ Patch 4: enginescript-install.sh
    │   │   ├─ Check if already patched → Skip if yes
    │   │   ├─ Create backup
    │   │   ├─ Apply sed addition
    │   │   └─ Log result
    │   └─ Print summary
    │       ├─ Patches Applied: X
    │       └─ Patches Failed: Y
    │
    └─ NO → Continue without patching
    ↓
Continue with normal-auto-upgrade.sh
    ↓
Update EngineScript frontend
    ↓
Update WordPress plugins
    ↓
Complete
```

---

## Testing Strategy

### Test Cases

#### 1. Fresh Installation on Hetzner Cloud
```bash
# Expected: All patches applied during first install
INSTALL_HETZNER_CLOUD_AGENT=1
es.install
# Verify: Check log for 4 successful patches
```

#### 2. Fresh Installation on DigitalOcean
```bash
# Expected: Patches not needed (eth0 detected)
INSTALL_HETZNER_CLOUD_AGENT=0
es.install
# Verify: No patch log created
```

#### 3. Update After Main Repo Pull
```bash
# Expected: Patches reapplied automatically
es.update
# Verify: Check log for "already patched" messages
```

#### 4. Manual Patch Trigger
```bash
# Expected: Patches applied on demand
es.patch
# Verify: Log shows current timestamp entries
```

#### 5. Idempotency Test
```bash
# Expected: Safe to run multiple times
es.patch
es.patch
es.patch
# Verify: "already patched" messages, no errors
```

#### 6. Backup Verification
```bash
# Expected: Backups created before each modification
ls -la /usr/local/bin/enginescript/scripts/install/nginx/*.backup.*
# Verify: Timestamped backup files exist
```

### Validation Commands

```bash
# Check detected interface
ip -o -4 route show to default | awk '{print $5}'

# Verify nginx configuration
ng.test

# Check sysctl IPv6 settings
grep "net.ipv6.conf." /etc/sysctl.d/60-enginescript.conf

# View patch log
cat /var/log/EngineScript/hetzner-patch.log

# List backup files
find /usr/local/bin/enginescript -name "*.backup.*" -type f

# Check if Hetzner script exists and is executable
ls -lh /usr/local/bin/enginescript/scripts/install/system-misc/hetzner-cloud-install.sh

# Verify main install has Hetzner support
grep INSTALL_HETZNER_CLOUD_AGENT /usr/local/bin/enginescript/scripts/install/enginescript-install.sh
```

---

## Security Considerations

### 1. Code Injection Prevention

**Risk:** Malicious code in sed replacements

**Mitigation:**
- All replacement text is hardcoded (no user input)
- Uses single quotes in heredocs to prevent expansion
- Proper shell escaping in sed commands

### 2. File Permission Preservation

**Implementation:**
```bash
chmod +x "${TARGET_FILE}"
chown root:root "${TARGET_FILE}"
```

**Why:**
- Maintains security model
- Prevents execution as non-root
- Preserves original permissions structure

### 3. Backup Before Modification

**Safety:**
- Every patch creates backup before changes
- Timestamped to prevent overwriting
- Allows manual rollback

### 4. Log File Security

**Location:** `/var/log/EngineScript/hetzner-patch.log`

**Permissions:**
- Created by root
- Readable only by root
- Contains system paths and configuration details

---

## Performance Impact

### Patch Execution Time

- **Typical Runtime:** 1-3 seconds
- **Operations:** 4 file checks + 0-4 sed replacements
- **Network Impact:** None (local operations only)
- **Disk I/O:** Minimal (small text files)

### Update Impact

- **Additional Time:** ~2 seconds per update
- **Frequency:** Daily (if auto-update enabled)
- **Resource Usage:** Negligible CPU/RAM

---

## Future Enhancements

### Potential Improvements

1. **Patch Version Tracking**
   - Track which patch version was last applied
   - Allow incremental patches
   - Skip unnecessary re-patching

2. **Cloud Provider Detection**
   - Detect cloud provider automatically
   - Apply provider-specific optimizations
   - Log provider information

3. **Patch Rollback Command**
   - `es.patch.rollback` command
   - Restore from timestamped backups
   - Interactive backup selection

4. **Notification System**
   - Email/webhook on patch failures
   - Integration with existing notification systems
   - Dashboard status indicator

5. **Pre-flight Validation**
   - Test patches before applying
   - Validate sed syntax
   - Check for merge conflicts

---

## Maintenance

### Adding New Patches

To add a new patch to the system:

1. **Edit `hetzner-compatibility-patch.sh`**
2. **Add new patch function:**
   ```bash
   patch_new_feature() {
     local TARGET_FILE="path/to/file"
     log_patch "Checking for new feature..."

     if [[ ! -f "${TARGET_FILE}" ]]; then
       log_patch "⚠ File not found"
       return 1
     fi

     if check_if_patch_needed "${TARGET_FILE}" "SIGNATURE_PATTERN"; then
       log_patch "✓ Already patched"
       return 0
     fi

     cp "${TARGET_FILE}" "${TARGET_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

     # Apply patch using sed
     if sed -i 's/OLD/NEW/g' "${TARGET_FILE}"; then
       log_patch "✓ Patched successfully"
       return 0
     else
       log_patch "✗ Patch failed"
       return 1
     fi
   }
   ```

3. **Call from main():**
   ```bash
   patch_new_feature && ((PATCHES_APPLIED++)) || ((PATCHES_FAILED++))
   ```

4. **Test thoroughly:**
   ```bash
   es.patch
   cat /var/log/EngineScript/hetzner-patch.log
   ```

---

## Conclusion

The automatic compatibility patching system provides:

✅ **Zero-Maintenance Multi-Cloud Support**
✅ **Seamless Updates from Main Repository**
✅ **Non-Breaking Changes for All Platforms**
✅ **Comprehensive Logging and Auditing**
✅ **User Control with Manual Override**

This architecture ensures EngineScript remains compatible with Hetzner Cloud and other modern cloud providers while maintaining full compatibility with DigitalOcean and the ability to receive updates from the main repository.

---

**Version:** 1.0.0
**Last Updated:** 2025-11-02
**Maintainer:** EngineScript Community
