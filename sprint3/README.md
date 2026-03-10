# STAR ELZ V1 — Sprint 3: Security, Forced Inspection, Observability

**Branch:** sprint3 · **Dates:** 9–11 Mar 2026 · **Terraform ≥ 1.5.0** · **OCI Provider ≥ 6.0.0**

**Coming from Sprint 2?** You need `sprint2_outputs.json` for DRG, VCN, subnet, Bastion, and Sim FW OCIDs. Paste them into Sprint 3 ORM Variables. Run the Sprint 1 IAM patch FIRST — see `SPRINT1_IAM_PATCH_FOR_S3.md` it should already be in Sprint1 code sprint1/iam_policies_team1.tf and yesterday we ran apply.

Sprint 3 adds the security enforcement layer on top of Sprint 2's hub-and-spoke network. The main goal: **forced inspection** — all spoke-to-spoke traffic now flows through the Hub Sim FW instead of bypassing it via DRG full-mesh.

Also added: Vault/KMS, Cloud Guard, Security Zones, NSGs, VCN flow logs, Service Connector Hub, VSS, Certificate Authority, events/alarms, and SGW (Hub VCN only).

---

## Network Topology

```
SPRINT 2 INFRASTRUCTURE (referenced via variables, not modified):
  1 Bastion · 5 VCNs · 6 subnets · 2 DRGs · 5 DRG attachments
  4 Sim FWs (firewalld + ssh_authorized_keys) · 6 RTs · 6 SLs

SPRINT 3 ADDS (57 resources):

C1_R_ELZ_NW (Hub)
├── vcn_r_elz_nw (10.0.0.0/16)
│   ├── sub_r_elz_nw_fw
│   │   ├── nsg_r_elz_nw_fw (T1) · fl_r_elz_nw_fw (T1)
│   │   └── rt_r_elz_nw_fw — spoke CIDRs → DRG + SGW → OSN
│   ├── sub_r_elz_nw_mgmt
│   │   ├── bas_r_elz_nw_hub (Sprint 2) — Hub FW access only
│   │   └── nsg_r_elz_nw_mgmt (T2) · fl_r_elz_nw_mgmt (T2)
│   ├── sgw_r_elz_nw_hub (T4) — Hub only, centralised
│   ├── rt_r_elz_nw_hub_ingress (T4) → Hub FW private IP
│   └── drg_r_hub — FORCED INSPECTION (T4):
│       ├── drgrt_r_hub_spoke_mesh (import distribution)
│       ├── drgrt_spoke_to_hub (static 0/0 → Hub)
│       └── 5 attachments imported + reassigned to custom RTs

Spokes: nsg + flow log per subnet (T1/T2)
SEC compartment: Vault, Cloud Guard, Security Zones, logging, SCH (T3)

FORCED INSPECTION:
  Sprint 2: OS → DRG(full-mesh) → TS           [bypassed]
  Sprint 3: OS → DRG(spoke_to_hub) → Hub FW → DRG → TS [inspected]

VALIDATION: Bastion → Hub FW (same VCN) → ssh opc@spoke_ip
```

---

## Sprint 2 → Sprint 3 Handover

Sprint 3 is a separate ORM stack. It does NOT modify Sprint 2 state.

| Sprint 2 Output | Sprint 3 Variable | Purpose |
|---|---|---|
| `hub_drg_id` | `hub_drg_id` | DRG route tables |
| `hub_drg_attachment_id` | `hub_drg_attachment_id` | Import + assign hub_spoke_mesh RT |
| `os/ts/ss/devt_drg_attachment_id` | `*_drg_attachment_id` | Import + assign spoke_to_hub RT |
| `hub/os/ts/ss/devt_vcn_id` | `*_vcn_id` | NSGs + DRG attachment import |
| `hub_fw/mgmt_subnet_id` + spokes | `*_subnet_id` | Flow logs + ingress RT |
| `bastion_id` | `bastion_id` | Console sessions (Hub FW only) |
| `hub_fw_rt_id` | `hub_fw_rt_id` | Import Hub FW RT |
| ⚠️ `hub_fw_private_ip_id` | `hub_fw_private_ip_id` | See below |

**Private IP OCID — extra step:**

Sprint 2 outputs the IP address. Sprint 3 needs the OCID. Run:

```bash
oci network private-ip list \
  --subnet-id $(terraform output -raw hub_fw_subnet_id) \
  --ip-address $(terraform output -raw hub_fw_private_ip_address) \
  --query 'data[0].id' --raw-output
```

**Key handover facts:**
- **DRG attachments:** Sprint 3 imports them via `import {}` blocks and assigns custom DRG RTs. `oci_core_drg_attachment_management` does NOT support VCN — Sprint 3 uses `oci_core_drg_attachment`.
- **SGW:** Sprint 2 has zero SGWs. Sprint 3 creates 1 in Hub VCN only.
- **Cloud-init:** Sprint 2 Sim FWs have `ip_forward=1` + firewalld. No changes needed.

---

## Pre-Apply Steps — Operator Checklist

### Step 0a — Confirm Sprint 1 IAM patch

```bash
oci iam policy list --compartment-id $TENANCY_ID --all \
  --query "data[?name=='UG_ELZ_NW-Policy'].statements[0]" --output table | grep bastion
# If found → skip. If not → Sprint 1 ORM Apply first.
```

### Step 0b — Verify SSH key (required for TC-22, TC-26, TC-27)

The same SSH key pair is used across Sprint 2 (instance metadata), Sprint 3 (Vault secret), and Bastion sessions (session auth). All three must match. Verify BEFORE testing.

**Check 1 — Do you have the private key on your laptop?**

```bash
ls -la ~/.ssh/id_rsa
# If this file exists → you have a private key. Continue to Check 2.
# If not → see "No key exists" below.
```

**Check 2 — Is the matching public key in Sprint 2 instance metadata?**

```bash
# Get the public key from your laptop
cat ~/.ssh/id_rsa.pub | head -c 80

# Get the public key from instance metadata
oci compute instance get --instance-id <sim_fw_hub_id> \
  --query 'data.metadata."ssh_authorized_keys"' --raw-output | head -c 80

# If both start with the same "ssh-rsa AAAA..." → keys match. You're good.
# If they differ → see "Key mismatch" below.
```

**Scenario A — Keys match.** You're ready. Use this key for:
- Bastion session creation (paste `~/.ssh/id_rsa.pub`)
- SSH tunnel (`ssh -i ~/.ssh/id_rsa ...`)
- Sprint 3 ORM Variable `ssh_public_key` (paste `~/.ssh/id_rsa.pub`)

**Scenario B — Key mismatch (someone else set up Sprint 2, or key was regenerated).**

Fix WITHOUT rerunning Sprint 2 — update instance metadata via CLI:

```bash
# Read your current public key
PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# Update each Sim FW instance (4 instances)
for INSTANCE_ID in <sim_fw_hub_id> <sim_fw_os_id> <sim_fw_ts_id> <sim_fw_ss_id>; do
  oci compute instance update --instance-id $INSTANCE_ID \
    --metadata "{\"ssh_authorized_keys\": \"$PUB_KEY\"}" --force
  echo "Updated: $INSTANCE_ID"
done
```

This updates running instances in-place. No Terraform, no Sprint 2 rerun, no state changes. Wait 30 seconds for metadata propagation, then test SSH.

**Scenario C — No key exists at all.**

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub
```

Then update instance metadata using the CLI commands in Scenario B above. Paste the same public key into Sprint 3 ORM Variable `ssh_public_key`.

**Scenario D — SSH key exists but PORT_FORWARDING Bastion sessions don't work (old Sprint 2 code, Managed SSH setup).**

PORT_FORWARDING does not need Cloud Agent or the Bastion plugin. It only needs:
1. Bastion service is ACTIVE (check: Console → Bastion → `bas_r_elz_nw_hub` → lifecycle state)
2. Target IP is in the same VCN (Hub FW is in Hub VCN — same as Bastion — this works)
3. The SSH key on your laptop matches the key in instance metadata

If PORT_FORWARDING still fails, use **Console Connection** (TC-22 Option B) — it bypasses networking entirely.

**Scenario E — Cannot get SSH access at all.**

OCI Instance Console Connection gives you a text console to the instance via the OCI control plane — no VCN networking, no Bastion, no Cloud Agent needed to establish the connection. However, once connected you still see a login prompt and need `opc` credentials.

If `ssh_authorized_keys` is already in instance metadata (Sprint 2 set it), Console Connection works — OCI injects the key and `opc` can log in. If metadata is empty, you're stuck at the login prompt with no password.

**The real fix for "no SSH access":** Use Scenario B or C first (CLI metadata update to inject a key), THEN use either Bastion or Console Connection to log in.

Console → Compute → `fw_r_elz_nw_hub_sim` → Console Connection tab → Create Local Connection → copy the SSH command → run it.

> **Do NOT rerun Sprint 2 just to fix SSH keys.** The CLI metadata update (Scenario B) is faster, safer, and has zero impact on Terraform state. Rerunning Sprint 2 risks destroying SGWs and conflicting with Sprint 3's partial apply state.

### Step 1 — Get 8 OCIDs for sec_team4.tf

Sprint 3 `sec_team4.tf` has 8 `PASTE_*_HERE` placeholders. Replace them:

```bash
# 1a. Hub FW Route Table (Sprint 2 — always exists)
oci network route-table list \
  --compartment-id <nw_compartment_id> --vcn-id <hub_vcn_id> \
  --query 'data[?"display-name"==`rt_r_elz_nw_fw`].id | [0]' --raw-output

# 1b. DRG Route Distribution (may exist from partial apply)
oci network drg-route-distribution list \
  --drg-id <hub_drg_id> --all \
  --query 'data[?"display-name"==`drgrd_r_hub_vcn_import`].id | [0]' --raw-output
# If empty → REMOVE that import block from sec_team4.tf

# 1c. Service Gateway (may exist from partial apply)
oci network service-gateway list \
  --compartment-id <nw_compartment_id> --vcn-id <hub_vcn_id> --all \
  --query 'data[0].id' --raw-output
# If empty → REMOVE that import block from sec_team4.tf

# 1d. All 5 DRG attachment OCIDs (Sprint 2 — always exist)
oci network drg-attachment list --drg-id <hub_drg_id> --all \
  --query 'data[].{"name":"display-name","id":id}' --output table
```

| Placeholder | Source |
|---|---|
| `PASTE_HUB_FW_RT_OCID_HERE` | 1a |
| `PASTE_DRG_ROUTE_DIST_OCID_HERE` | 1b (or remove import block) |
| `PASTE_SGW_OCID_HERE` | 1c (or remove import block) |
| `PASTE_HUB_DRG_ATTACHMENT_OCID_HERE` | 1d: `drga_r_elz_nw_hub` |
| `PASTE_OS_DRG_ATTACHMENT_OCID_HERE` | 1d: `drga_os_elz_nw` |
| `PASTE_TS_DRG_ATTACHMENT_OCID_HERE` | 1d: `drga_ts_elz_nw` |
| `PASTE_SS_DRG_ATTACHMENT_OCID_HERE` | 1d: `drga_ss_elz_nw` |
| `PASTE_DEVT_DRG_ATTACHMENT_OCID_HERE` | 1d: `drga_devt_elz_nw` |

> **Why hardcoded?** Terraform `import {}` blocks require literal strings, not variables.

### Step 2 — Verify hub_drg_id

```bash
oci network drg list --compartment-id <nw_compartment_id> --all \
  --query 'data[?"display-name"==`drg_r_hub`].id | [0]' --raw-output
```

### Step 3 — Get private IP values

```bash
# Hub FW private IP OCID
oci network private-ip list --subnet-id <hub_fw_subnet_id> \
  --query 'data[0].id' --raw-output

# OS + TS Sim FW private IP addresses (optional — for future bastion use)
oci compute instance list-vnics --instance-id <os_fw_instance_id> \
  --query 'data[0]."private-ip"' --raw-output
oci compute instance list-vnics --instance-id <ts_fw_instance_id> \
  --query 'data[0]."private-ip"' --raw-output
```

### Step 4 — Verify Cloud Guard enabled

Console → Security → Cloud Guard. Enable if off.

### Step 5 — Commit and apply

```bash
git add sprint3/sec_team4.tf
git commit -m "fix: paste import block OCIDs"
git push origin main
```

**ORM → Plan → 0 errors → Apply.**

---

## Team Assignments

| Team | File(s) | Resources | Count |
|---|---|---|---|
| T1 | `sec_team1.tf` | Hub FW + OS NSGs, flow logs, VSS, SCH | 11 |
| T2 | `sec_team2.tf` | MGMT + TS + SS + DEVT NSGs, flow logs, Cert Authority | 17 |
| T3 | `sec_team3.tf` + `sec_team3_security.tf` | Log group, bucket, notifications, events, alarm, Vault/KMS, SSH secret, Cloud Guard, Security Zones | 16 |
| T4 | `sec_team4.tf` | DRG RTs, import distribution, forced inspection, ingress RT, Hub FW RT, SGW, 5 DRG attachment imports | 13 |
| **Total** | | | **57** |

---

## Test Cases

### Shell Variables (paste from `sprint2_outputs.json` + Sprint 3 outputs)

```bash
HUB_DRG_ID="<paste>"
HUB_VCN_ID="<paste>"
HUB_FW_SUBNET="<paste>"
OS_APP_SUBNET="<paste>"
TS_APP_SUBNET="<paste>"
NW_CMP_ID="<paste>"
SEC_CMP_ID="<paste>"
SIM_FW_HUB_ID="<paste>"
TENANCY_ID=$(oci iam tenancy get --query 'data.id' --raw-output)
```

### Forced Inspection (T4) — The Main Event

**TC-20 — DRG route tables created.**

Console → Networking → DRGs → `drg_r_hub` → DRG Route Tables tab.

```bash
oci network drg-route-table list --drg-id $HUB_DRG_ID \
  --query 'data[].{name:"display-name",id:id}' --output table
```

Expected: `drgrt_r_hub_spoke_mesh` + `drgrt_spoke_to_hub` (2 custom RTs alongside the auto-generated defaults).

**TC-21 — Spoke attachments use spoke_to_hub RT.**

Console → DRGs → `drg_r_hub` → DRG Attachments tab → click each → verify DRG Route Table.

```bash
oci network drg-attachment list --drg-id $HUB_DRG_ID --all \
  --query 'data[].{name:"display-name","drg-rt":"drg-route-table-id"}' --output table
```

Expected: OS/TS/SS/DEVT attachments point to `drgrt_spoke_to_hub`. Hub attachment points to `drgrt_r_hub_spoke_mesh`.

**TC-22 — Forced inspection proof (THE key test).**

**Option A — Bastion → Hub FW → SSH-hop:**

Console → Identity & Security → Bastion → `bas_r_elz_nw_hub` → Create Session:
- Session type: SSH port forwarding session
- Target IP: Hub FW private IP (10.0.0.x — same VCN as Bastion)
- Port: 22
- SSH key: paste your `~/.ssh/id_rsa.pub`
- Click Create. Wait for ACTIVE. Copy the SSH command.

```bash
# Terminal 1: run the tunnel (paste the command from Bastion session details)
ssh -i ~/.ssh/id_rsa -N -L 2222:<hub_fw_ip>:22 -p 22 \
  <session_ocid>@host.bastion.<region>.oci.oraclecloud.com

# Terminal 2: connect to Hub FW through the tunnel
ssh -i ~/.ssh/id_rsa -p 2222 opc@localhost
```

**Option B — Instance Console Connection (no networking needed):**

Console → Compute → Instances → `fw_r_elz_nw_hub_sim` → Console Connection tab → Create Local Connection → copy the SSH command → run it. This connects via the OCI control plane to the instance's virtual serial console — no Bastion, no VCN routing, no Cloud Agent. You still need `opc` login credentials (SSH key must be in instance metadata — see Step 0b).

**From Hub FW (either option), SSH-hop to OS spoke and traceroute to TS:**

```bash
# From Hub FW shell — hop to OS spoke via DRG routing
ssh opc@10.1.0.x

# Now from OS Sim FW shell — traceroute to TS
traceroute -n 10.3.0.x
```

**Sprint 2 showed:** OS → DRG → TS (2-3 hops, direct path).
**Sprint 3 must show:** OS → DRG → Hub FW (10.0.0.x) → DRG → TS (4-5 hops, Hub FW in the path).

If the Hub FW IP appears in the traceroute output — **forced inspection is working.**

Also verify with Network Path Analyzer:

Console → Networking → Network Path Analyzer → Create Path Analysis:
- Source: OS app subnet
- Destination: TS app subnet
- Protocol: ICMP

Or via CLI:

```bash
oci network path-analyzer-test create --protocol 1 \
  --source-endpoint "{\"type\":\"SUBNET\",\"subnetId\":\"$OS_APP_SUBNET\"}" \
  --destination-endpoint "{\"type\":\"SUBNET\",\"subnetId\":\"$TS_APP_SUBNET\"}" \
  --compartment-id $TENANCY_ID
```

Sprint 2 NPA: OS → DRG → TS (direct). Sprint 3 NPA must show: OS → DRG → Hub VCN → Hub FW → DRG → TS.

**TC-23 — VCN Ingress RT.**

Console → Networking → Hub VCN → Route Tables → `rt_r_elz_nw_hub_ingress`.

Expected: 1 rule — `10.0.0.0/8` → Hub FW private IP OCID (next hop is a private IP, not a gateway).

**TC-24 — Hub FW RT has spoke return routes + SGW.**

Console → Hub VCN → Route Tables → `rt_r_elz_nw_fw`.

Expected: 4 spoke CIDR rules → DRG + 1 SGW rule → Oracle Services Network. Total 5 rules.

```bash
oci network route-table get --rt-id <hub_fw_rt_id> \
  --query 'data."route-rules"[].{destination:destination,"target":"network-entity-id"}' --output table
```

### NSGs (T1/T2)

**TC-25 — 6 NSGs created.**

Console → Networking → each VCN → Network Security Groups.

```bash
oci network nsg list --compartment-id $NW_CMP_ID --all \
  --query 'data[].{name:"display-name",vcn:"vcn-id"}' --output table
```

Expected: `nsg_r_elz_nw_fw`, `nsg_r_elz_nw_mgmt`, `nsg_os_elz_nw_app`, `nsg_ts_elz_nw_app`, `nsg_ss_elz_nw_app`, `nsg_devt_elz_nw_app`.

### Bastion + SSH Validation (T1/T2)

**TC-26 — Bastion to Hub FW, then SSH-hop to OS.**

OCI Bastion cannot reach cross-VCN targets. The Hub Sim FW is the jump point.

Console → Bastion → `bas_r_elz_nw_hub` → Create Session → PORT_FORWARDING → Target IP: Hub FW private IP (10.0.0.x) → Port: 22. Copy the SSH tunnel command.

```bash
# Terminal 1: tunnel
ssh -i ~/.ssh/id_rsa -N -L 2222:<hub_fw_ip>:22 -p 22 \
  <session_ocid>@host.bastion.<region>.oci.oraclecloud.com

# Terminal 2: connect to Hub FW
ssh -i ~/.ssh/id_rsa -p 2222 opc@localhost

# From Hub FW: hop to OS spoke
ssh opc@10.1.0.x
# Expected: connected. Run: hostname, ip addr — confirms OS Sim FW
```

**TC-27 — SSH-hop to TS Sim FW.** From the same Hub FW session:

```bash
ssh opc@10.3.0.x
# Expected: connected to TS Sim FW
```

**TC-27b — SSH-hop to SS Sim FW.** `ssh opc@10.2.0.x`

> Why this works: Hub FW has `ip_forward=1` + DRG routing to all spokes. Spoke instances have `ssh_authorized_keys` in metadata (Sprint 2). The SSH hop uses normal TCP over the DRG fabric — no Bastion involvement after the first hop.

### Observability (T1/T2/T3)

**TC-28 — Flow logs active.**

Console → Observability & Management → Logging → Log Groups → `lg_r_elz_nw_flow`. Click any flow log → verify state is ACTIVE. Data should appear within 5 minutes.

```bash
oci logging log list --log-group-id <log_group_id> \
  --query 'data[].{name:"display-name",state:"lifecycle-state"}' --output table
```

**TC-29 — Log bucket exists and has objects.**

Console → Storage → Object Storage → Buckets → `bkt_r_elz_sec_logs`. Should have objects after SCH starts delivering.

```bash
oci os object list --bucket-name bkt_r_elz_sec_logs --compartment-id $SEC_CMP_ID \
  --query 'data[].name' --limit 5
```

**TC-30 — Service Connector Hub running.**

Console → Observability → Connector Hub → `sch_r_elz_sec_flow_logs`. State: ACTIVE. Check "Last run" timestamp.

**TC-31 — Notification topic.**

Console → Developer Services → Application Integration → Notifications → `nt_r_elz_sec_alerts`. Add an email subscription to test delivery.

**TC-32 — Events rule fires.**

Console → Observability → Events Service → `ev_r_elz_sec_nw_changes`. State: ACTIVE. Make a minor change to any networking resource (e.g. add a freeform tag to a subnet) → verify the event fires and notification is delivered.

**TC-33 — Monitoring alarm.**

Console → Observability → Monitoring → Alarms → `al_r_elz_sec_drg_change`. State: OK (no alarm condition yet — this is correct).

### Security Services (T3)

**TC-34 — Vault + Master Key.**

Console → Identity & Security → Vault → `vlt_r_elz_sec`. Click → Keys tab → `key_r_elz_sec_master` → ENABLED.

```bash
oci kms management key list --compartment-id $SEC_CMP_ID \
  --service-endpoint $(oci kms vault get --vault-id <vault_id> --query 'data."management-endpoint"' --raw-output) \
  --query 'data[].{name:"display-name",state:"lifecycle-state"}' --output table
```

**TC-35 — Cloud Guard target active.**

Console → Identity & Security → Cloud Guard → Targets → `cgt_r_elz_root`. Status: ACTIVE. Check the Problems tab for any findings.

**TC-36 — Security Zone blocks public bucket.**

Console → Identity & Security → Security Zones → `sz_r_elz_sec`. Verify it's ACTIVE, then test:

```bash
# This MUST fail with HTTP 409
oci os bucket create --compartment-id $SEC_CMP_ID \
  --name "test-public-bucket" --public-access-type ObjectRead
# Expected: 409 Conflict — Security Zone blocks public access
```

**TC-37 — Security Zone blocks public subnet.**

```bash
oci network subnet create --compartment-id $NW_CMP_ID \
  --vcn-id $HUB_VCN_ID --cidr-block "10.0.99.0/24" \
  --prohibit-public-ip-on-vnic false
# Expected: 409 Conflict — Security Zone blocks public subnets
```

### Vulnerability Scanning (T1)

**TC-38 — VSS recipe created.**

Console → Identity & Security → Scanning → Host Scan Recipes → `vssr_r_elz_sec`.

> Note: VSS is behind `enable_vss` flag (default false). Set `enable_vss = true` in ORM Variables to test. If VSS is not available in the region, leave it false.

**TC-39 — VSS target scanning.**

Console → Scanning → Host Scan Targets → `vsst_r_elz_nw`. Check "Scanned instances" after the first scan cycle (weekly schedule, or trigger manual).

### Certificate Authority (T2)

**TC-40 — CA created.**

Console → Identity & Security → Certificates → Certificate Authorities → `ca_r_elz_sec`. Status: ACTIVE.

```bash
oci certs-mgmt certificate-authority list --compartment-id $SEC_CMP_ID \
  --query 'data.items[].{name:name,state:"lifecycle-state"}' --output table
```

### Final

**TC-41 — Zero drift.**

ORM → Sprint 3 Stack → Plan. Expected: `0 to add, 0 to change, 0 to destroy`.

**TC-42 — SSH key in Vault + instance metadata.**

Console → Vault → `vlt_r_elz_sec` → Secrets → `ssh-public-key` → verify ACTIVE.

```bash
# Vault secret exists
oci vault secret list --compartment-id $SEC_CMP_ID \
  --query "data[?\"secret-name\"=='ssh-public-key'].{name:\"secret-name\",state:\"lifecycle-state\"}" --output table

# Instance metadata has the key (set by Sprint 2)
oci compute instance get --instance-id $SIM_FW_HUB_ID \
  --query 'data.metadata."ssh_authorized_keys"' --raw-output | head -c 50
# Expected: ssh-rsa AAAA...
```

From Hub FW (via TC-26 Bastion session or Console Connection):

```bash
# Verify key on Hub FW
cat ~/.ssh/authorized_keys | head -c 50
# Expected: same ssh-rsa AAAA... as your public key

# Verify key on spoke (SSH-hop from Hub FW)
ssh opc@10.1.0.x 'cat ~/.ssh/authorized_keys | head -c 50'
# Expected: same key on spoke instances
```

---

## Design Decisions

| Decision | Detail |
|---|---|
| Forced inspection | Custom DRG RTs replace full-mesh. `spoke_to_hub` → Hub. Hub ingress RT → Hub FW. Hub FW RT → spokes via DRG. |
| DRG attachments | `oci_core_drg_attachment` with `import {}` blocks. `oci_core_drg_attachment_management` does NOT support VCN (auto-created types only: IPSec, RPC, FastConnect). |
| SGW (Sprint 3) | Sprint 2 has zero SGWs. Sprint 3 creates 1 Hub-only SGW. Centralised and inspectable. |
| Hub FW RT import | Sprint 2 created empty RT. Sprint 3 imports and adds spoke CIDRs + SGW route. |
| Bastion | 1 service in Hub VCN. Cross-VCN NOT supported. Validate via Hub FW → SSH-hop, or Console Connection. |
| Import blocks | 8 in sec_team4.tf. Hardcoded OCIDs (Terraform constraint). One-time operator step. |
| SSH key | Instance metadata (Sprint 2) + Vault secret (Sprint 3). Enables SSH-hop from Hub FW to spokes. |

---

## Handoff Checklist

- [ ] Sprint 1 IAM patch applied
- [ ] 8 import block OCIDs pasted
- [ ] TC-20 to TC-42 all PASS
- [ ] `sprint3_outputs.json` exported
- [ ] Git tag `sprint3-complete` pushed
