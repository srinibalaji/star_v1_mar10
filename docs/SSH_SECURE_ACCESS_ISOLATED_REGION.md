# Secure Admin Access to OCI Compute Instances
## STAR ELZ V1 | OCI Isolated Region | SSH & Authentication Reference

> **Context:** This document covers how administrators securely connect to OCI compute instances (Sim FW, workload VMs, database hosts) in an air-gapped OCI Isolated Region where there is no internet, no public IPs, and no external identity provider reachable from outside the sovereign boundary.

---

## 1. The Access Challenge in an Isolated Region

Standard cloud SSH patterns (public IP, bastion with internet-facing endpoint, cloud shell with browser) are not available. All access is:

- **No public IPs** on any compute instance — enforced by Security Zone policy and `prohibit_public_ip_on_vnic = true` in Terraform
- **No IGW** — no path from the internet into any VCN
- **No OCI Cloud Shell** via public browser — Cloud Shell connects via the OCI Console which is only reachable within the isolated region boundary
- **All access is internal** — admins must be physically or logically inside the isolated region network or connected via the approved WAN path

This means every SSH connection is:
```
Admin workstation (inside isolated network)
    → OCI Bastion Service (private, in Hub MGMT subnet)
        → Target compute instance (private, in FW or app subnet)
```

---

## 2. SSH Key Management

### 2.1 How SSH Keys Work in STAR ELZ V1

The SSH public key is placed on each compute instance at launch time via the `metadata.ssh_authorized_keys` field in Terraform. This is baked into the instance — it cannot be changed post-launch without either replacing the instance or manually editing `~/.ssh/authorized_keys` on the running VM.

STAR ELZ V1 uses the same SSH key pair across all Sim FW instances for the workshop. In production this must change — see Section 2.3.

| Key Component | Where It Lives | Who Has It |
|---|---|---|
| SSH public key | Instance metadata (`ssh_authorized_keys`) | On the instance, not secret |
| SSH public key (copy) | OCI Vault secret `ssh-public-key` in `vlt_r_elz_sec` | Terraform-deployed, SEC compartment |
| SSH public key (copy) | Bastion session `key_details.public_key_content` | Sprint 3 Terraform sessions |
| SSH private key | Admin workstation only | Individual admin — never in OCI |

### 2.2 Where Keys Are Stored — Production Guidance

**OCI Vault (KMS)** is the correct place to store secrets in STAR ELZ V1. However, SSH private keys should **never** be stored in Vault or any shared system. The rule is:

| Key | Store In | Rationale |
|---|---|---|
| SSH public key | OCI Vault secret | Safe to store — not sensitive. Audit trail via Vault access logs. Enables automated provisioning without hardcoding in tf files |
| SSH private key | Admin's workstation only | If stored anywhere else, the security model collapses. Lost private key = revoke the public key on all instances and re-deploy |
| Temporary session key | Admin's workstation memory (ssh-agent) | Generated per session, never persisted |

**For production multi-admin environments:**
- Each admin has their own unique SSH key pair
- Each admin's public key is added to instances independently (not a shared key)
- Key rotation is managed by re-running Terraform with updated `ssh_authorized_keys` values, or via Ansible (see companion doc)
- Revocation is immediate: remove the public key from `~/.ssh/authorized_keys` on target instances via Ansible run — no instance replacement needed

### 2.3 Object Storage for SSH Public Key Backup

Some teams store SSH public keys in a versioned, private Object Storage bucket as a backup/audit record:

```
Bucket: bkt_r_elz_sec_keys (private, versioned, encrypted with Vault master key)
Contents:
  admin1_id_rsa.pub
  admin2_id_rsa.pub
  service_account_id_rsa.pub
```

This is acceptable for **public keys only**. The bucket must be:
- `access_type = NoPublicAccess`
- Encrypted with the KMS master key (`key_r_elz_sec_master`)
- Covered by a Security Zone policy
- Audit-logged via Object Storage audit events → Cloud Guard Activity Detector

**Private keys must never be placed in Object Storage, Vault, or any shared system.**

---

## 3. Connecting via OCI Bastion Service

### 3.1 How the Bastion Works (PORT_FORWARDING)

STAR ELZ V1 uses PORT_FORWARDING sessions (not Managed SSH). This means:

- The Bastion acts as a TCP proxy — it opens a tunnel between the admin workstation and port 22 on the target instance
- No Oracle Cloud Agent required on the target instance
- No Oracle-managed key injection — the admin's own SSH private key is used directly
- The connection is: `admin workstation → Bastion TCP tunnel → target instance sshd`

The Bastion does not have access to the SSH private key. Authentication happens end-to-end between the admin's SSH client and the instance's sshd daemon.

### 3.2 Creating a Session — Console Method

1. Console → Identity & Security → Bastion → `bas_r_elz_nw_hub`
2. Create Session → Session Type: **PORT_FORWARDING**
3. Target resource: select the instance (e.g. `fw_r_elz_nw_hub_sim`)
4. Target port: 22
5. Paste your SSH **public** key into the Public Key field
6. Click Create Session
7. Once Active (30–60 seconds), click the session → Copy SSH Command
8. Run the SSH command on your workstation:

```bash
ssh -i ~/.ssh/id_rsa -N -L 127.0.0.1:2222:<instance-private-ip>:22 \
  -p 22 ocid1.bastionsession...@host.bastion.<region>.oci.oraclecloud.com
```

In a second terminal:
```bash
ssh -i ~/.ssh/id_rsa -p 2222 opc@127.0.0.1
```

### 3.3 Session TTL and Limits

| Parameter | Default | Max |
|---|---|---|
| Session TTL | 1800 seconds (30 min) | 10800 seconds (3 hours) |
| Max concurrent sessions | 20 per Bastion | Configurable |
| Bastion access CIDR | `10.0.0.0/8` (STAR ELZ V1) | Restrict further in production |

Terraform-created sessions (Sprint 3 `sec_team1.tf`, `sec_team2.tf`) expire after TTL. For ongoing admin access, create Console sessions manually. Set TTL to the minimum needed for the task.

### 3.4 Bastion IAM Requirement

To create Bastion sessions, the admin's group needs:
```
allow group UG_ELZ_NW to manage bastion-family in compartment C1_R_ELZ_NW
allow group UG_ELZ_NW to read instance-family in compartment C1_OS_ELZ_NW
allow group UG_ELZ_NW to read instance-agent-plugins in compartment C1_OS_ELZ_NW
```
These are included in the Sprint 1 IAM patch (`docs/SPRINT1_IAM_PATCH_FOR_S3.md`).

---

## 4. Other Secure Authentication Methods

### 4.1 OCI Instance Principal (Recommended for Automation)

For scripts, Ansible, and automation tools running **on OCI compute instances**, Instance Principal is the most secure authentication method. It eliminates all SSH key management for machine-to-machine OCI API calls:

- The instance authenticates to OCI APIs using its **OCID identity** — no API keys, no passwords
- A Dynamic Group is created covering the instance OCIDs
- An IAM policy grants the Dynamic Group specific API permissions
- The SDK/CLI on the instance uses `--auth instance_principal`

```hcl
# Terraform: Dynamic Group for Sim FW instances
resource "oci_identity_dynamic_group" "sim_fw" {
  name           = "DG_ELZ_SIMFW"
  description    = "Sim FW instances for automated OCI API access"
  matching_rule  = "instance.compartment.id = '${var.nw_compartment_id}'"
}

# Policy: allow the instances to read secrets from Vault
resource "oci_identity_policy" "sim_fw_vault" {
  name           = "DG_ELZ_SIMFW-Policy"
  compartment_id = local.tenancy_id
  statements = [
    "allow dynamic-group DG_ELZ_SIMFW to read secret-family in compartment C1_R_ELZ_SEC"
  ]
}
```

Use cases in STAR ELZ V1: Ansible runner on a management instance pulling playbooks from Object Storage, automated config scripts reading secrets from Vault, monitoring agents calling OCI Monitoring API.

### 4.2 OCI Vault-Managed Secrets for Service Accounts

For service account credentials (database passwords, API tokens for internal services), store them in OCI Vault and retrieve at runtime:

```bash
# On instance — retrieve a secret without hardcoding credentials
SECRET=$(oci secrets secret-bundle get \
  --secret-id ocid1.vaultsecret.oc1... \
  --auth instance_principal \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 -d)
```

This means no passwords in config files, no passwords in Ansible vault files, no passwords in Terraform state. All sensitive values live in OCI Vault and are retrieved at runtime by the instance using its own identity.

### 4.3 OCI Certificate-Based Authentication (PKI)

OCI Certificates service (deployed in Sprint 3 as `ca_r_elz_sec`) issues X.509 certificates signed by the internal root CA. Use cases:

| Use Case | How |
|---|---|
| Mutual TLS (mTLS) between services | Issue client and server certs from `ca_r_elz_sec` |
| Internal HTTPS for web admin interfaces | Server cert for Nginx/Apache on compute instances |
| SSH certificate authentication | CA signs SSH public keys — removes per-instance key management |

**SSH certificate authentication** is the most powerful SSH hardening option. Instead of distributing public keys to each instance, the CA signs a short-lived SSH certificate per session:

1. Admin generates an SSH key pair (standard `ssh-keygen`)
2. Admin submits the public key to the SSH CA (a privileged OCI Functions endpoint or an internal CA server)
3. CA signs the public key with a validity window (e.g. 8 hours) and returns a signed certificate
4. Admin uses the signed certificate to SSH to any instance that trusts the CA
5. Certificate expires — no revocation needed, access is automatically time-limited

This is the V2 target for STAR ELZ V1. OCI Certificate Authorities (`ca_r_elz_sec`) can serve as the signing CA.

### 4.4 HashiCorp Vault (Alternative — Not in Sprint 3)

For organisations already running HashiCorp Vault, it can be deployed on OCI compute in the SEC compartment and used for:
- Dynamic SSH secrets (short-lived signed SSH certificates per session)
- Dynamic database credentials (issue/revoke credentials on demand)
- Secret zero problem solved via AppRole or OCI auth method

HashiCorp Vault OCI Auth Method uses Instance Principal as the trust anchor — the instance proves its identity to Vault using its OCI OCID, Vault issues a time-limited token.

### 4.5 FIDO2 / WebAuthn for Console Access

For OCI Console access in the isolated region:
- OCI supports FIDO2 hardware security keys (YubiKey) as MFA for local IAM users
- This covers Console logins, ORM runs, and OCI CLI sessions using security-token auth
- Recommended for all admin-level groups in production: `UG_ELZ_NW`, `UG_ELZ_SEC`, `UG_ELZ_OPS`

---

## 5. Key Hygiene — Production Rules

| Rule | Why |
|---|---|
| One key pair per admin, not one shared key | Revocation of one admin does not affect others |
| Minimum 4096-bit RSA or ED25519 | ED25519 is preferred — shorter, faster, equally secure |
| SSH private key protected with passphrase | If the laptop is lost, the key is still unusable |
| Use `ssh-agent` for passphrase convenience | Passphrase entered once per session, not per connection |
| Session TTL minimum needed | Limit blast radius of a compromised Bastion session |
| Rotate SSH keys annually | Or immediately after any suspected compromise |
| Audit Vault secret access | Every read of `ssh-public-key` in Vault is logged in OCI Audit |
| Remove public key from instances on admin departure | Ansible playbook removes key from `~/.ssh/authorized_keys` on all instances |

---

## 6. Access Path Summary

```
ISOLATED REGION BOUNDARY
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  Admin workstation (inside boundary)                           │
│       │                                                        │
│       │ SSH + private key                                      │
│       ▼                                                        │
│  OCI Bastion (bas_r_elz_nw_hub)                                │
│  Hub MGMT subnet 10.0.1.0/24 — private                         │
│  PORT_FORWARDING — TCP tunnel to port 22                       │
│       │                                                        │
│       ├──→ Hub Sim FW (fw_r_elz_nw_hub_sim) 10.0.0.x           │
│       ├──→ OS Sim FW  (fw_os_elz_nw_sim)    10.1.0.x           │
│       ├──→ TS Sim FW  (fw_ts_elz_nw_sim)    10.3.0.x           │
│       └──→ SS Sim FW  (fw_ss_elz_nw_sim)    10.2.0.x           │
│                                                                │
│  For automation (no SSH):                                      │
│  Instance → OCI APIs via Instance Principal (no keys)          │
│  Instance → OCI Vault → retrieve secrets at runtime            │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 7. V2 Hardening Backlog

| Item | Description |
|---|---|
| SSH certificate authentication | `ca_r_elz_sec` signs short-lived SSH certs — removes per-instance key management |
| Per-admin unique SSH keys | Sprint 3 uses shared key for workshop — production needs individual keys per admin |
| Privileged Access Workstation (PAW) | Dedicated hardened workstation for admin SSH sessions — no general-purpose browsing |
| Session recording | OCI Bastion supports session recording to Object Storage — audit all SSH commands |
| IP-restricted Bastion access | Tighten `client_cidr_block_allow_list` from `10.0.0.0/8` to specific admin VLAN CIDR |
| MFA for OCI Console | FIDO2 YubiKey for all `UG_ELZ_*` admin groups |

---

## References

- OCI Bastion documentation: https://docs.oracle.com/en-us/iaas/Content/Bastion/home.htm
- OCI Vault documentation: https://docs.oracle.com/en-us/iaas/Content/KeyManagement/home.htm
- OCI Certificates documentation: https://docs.oracle.com/en-us/iaas/Content/certificates/home.htm
- OCI Instance Principal: https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm
- OCI Bastion session recording: https://docs.oracle.com/en-us/iaas/Content/Bastion/Tasks/record-bastion-sessions.htm
- SSH certificate authentication best practice: https://smallstep.com/blog/use-ssh-certificates/
- Oracle A-Team: OCI Bastion patterns: https://www.ateam-oracle.com/post/oci-bastion-service
