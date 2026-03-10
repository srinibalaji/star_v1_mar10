# Sprint 2 — SSH Public Key Fix for Sim FW Bastion Access

**Date:** 6 March 2026 | **Priority:** Must-fix before Phase 2 apply
**Impact:** Without this fix, TC-15, TC-19 (Sprint 2) and TC-22, TC-26, TC-27 (Sprint 3) all fail — no SSH into Sim FWs.

---

## Problem

Sprint 2 Sim FW instances have `metadata = { user_data = local.sim_fw_userdata }` but no `ssh_authorized_keys`. The `opc` user has no SSH public key, so Bastion Managed SSH sessions cannot authenticate. This blocks all data plane validation (ping, traceroute, tcpdump) and Sprint 3 forced inspection testing.

## Root Cause

`variable "ssh_public_key"` was not added to Sprint 2 `variables_general.tf`. The Sim FW instance metadata only contains `user_data` (cloud-init) but not `ssh_authorized_keys`.

---

## Fix — 4 files, 3 changes

### 1. `variables_general.tf` — add variable

Add at the end of the file:

```hcl
# =============================================================================
# SSH KEY — Sim FW Bastion access
# =============================================================================
variable "ssh_public_key" {
  description = "SSH public key for Sim FW instance access via Bastion. Paste the contents of your .pub file."
  type        = string
}
```

### 2. `nw_team1.tf`, `nw_team2.tf`, `nw_team3.tf`, `nw_team4.tf` — add ssh_authorized_keys to metadata

In every `oci_core_instance` resource (4 Sim FWs), change:

```hcl
  metadata = {
    user_data = local.sim_fw_userdata
  }
```

To:

```hcl
  metadata = {
    user_data           = local.sim_fw_userdata
    ssh_authorized_keys = var.ssh_public_key
  }
```

Files and resource names:

| File | Resource | Instance Name |
|---|---|---|
| `nw_team1.tf` | `oci_core_instance.sim_fw_os` | FW-C1-OS-ELZ-NW-SIM |
| `nw_team2.tf` | `oci_core_instance.sim_fw_ts` | FW-C1-TS-ELZ-NW-SIM |
| `nw_team3.tf` | `oci_core_instance.sim_fw_ss` | FW-C1-SS-ELZ-NW-SIM |
| `nw_team4.tf` | `oci_core_instance.sim_fw_hub` | FW-C1-R-ELZ-NW-HUB-SIM |

### 3. `schema.yaml` — add SSH key to ORM UI

Add `ssh_public_key` to the Bastion section (Section 8):

```yaml
  - title: "8. Bastion & SSH"
    variables:
      - bastion_client_cidr
      - ssh_public_key
```

Add the variable definition in the `variables:` block:

```yaml
  ssh_public_key:
    type: string
    title: "SSH Public Key"
    description: "Public key for Sim FW SSH access via Bastion. Paste contents of ~/.ssh/id_rsa.pub or your team's shared key."
    required: true
```

---

## ORM Apply Behaviour

If instances already exist from a previous Phase 2 apply without `ssh_authorized_keys`: adding `ssh_authorized_keys` to metadata triggers an **in-place update** (not a destroy/recreate). OCI updates the instance metadata and the Cloud Agent pushes the key to `~opc/.ssh/authorized_keys`. No instance downtime.

If this is the first Phase 2 apply: the key is injected at instance creation via cloud-init. No special handling needed.

---

## Verification

After apply, create a Bastion Managed SSH session to any Sim FW:

```bash
# Console: Bastion → BAS-C1-R-ELZ-NW-HUB → Create Session → Managed SSH
# Target: FW-C1-R-ELZ-NW-HUB-SIM → User: opc

# Or via CLI:
oci bastion session create-managed-ssh \
  --bastion-id $HUB_BASTION_ID \
  --target-resource-id $SIM_FW_HUB_ID \
  --target-os-username opc \
  --key-type PUB \
  --session-ttl 1800 \
  --ssh-public-key-file ~/.ssh/id_rsa.pub

# Connect using the SSH command from the session details
ssh -o ProxyCommand="..." opc@<hub_fw_private_ip>

# Once connected:
whoami                    # opc
cat ~/.ssh/authorized_keys  # should show your public key
```

---

## Sprint 3 Alignment

Sprint 3 `variables_general.tf` already has `variable "ssh_public_key"`. Sprint 3 Bastion sessions (`sec_team1.tf`, `sec_team2.tf`) use `public_key_content = var.ssh_public_key` in `key_details`. After this Sprint 2 fix, the same key works end-to-end: Sprint 2 ORM variable → instance metadata → Sprint 3 Bastion session key → SSH authentication.

---

## Git

```bash
cd star/sprint2
# Edit the 4 files + schema.yaml as described above
git add variables_general.tf nw_team1.tf nw_team2.tf nw_team3.tf nw_team4.tf schema.yaml
git commit -m "fix: add ssh_authorized_keys to Sim FW metadata for Bastion SSH access"
git push origin main
```
