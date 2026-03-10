# STAR ELZ V1 — Architect's Runbook

**File:** `docs/ARCHITECT_RUNBOOK.md`
**Owner:** Principal Architect (Amit)
**Last Updated:** 2026-02-28
**Purpose:** Exact script for the Sprint 1 + Sprint 2 deployment day. Follow this top-to-bottom. Do not skip steps.

---

## Pre-flight Checklist (Do This the Night Before)

- [ ] `sprint_state_ledger.json` committed and merged — `sprint1.status = "complete"` pending apply
- [ ] ORM Stack for Sprint 1 created in ap-singapore-2, configured, pointing at correct git branch
- [ ] ORM Stack for Sprint 2 created, `hub_drg_id` variable left blank (Phase 1 mode)
- [ ] All team leads have ORM Stack URLs and their compartment OCID row from the handoff table
- [ ] `.gitignore` confirmed on both sprint dirs — no `terraform.tfvars` or `.tfstate` in repo
- [ ] You have `jq` available (`brew install jq` or `sudo apt install jq`)
- [ ] Confirm Cloud Guard is enabled in the tenancy (done manually — no Terraform action needed today)

---

## Morning — Sprint 1: IAM Foundation (09:00–11:30)

### 09:00 — Kickoff Sync (15 min)

Stand up with all four teams. Confirm:

1. Everyone has ORM access.
2. Remind teams that Sprint 1 creates IAM objects only — no network resources today.
3. Call out that `.tfvars` files must **not** be pushed to Git. Share OCIDs via secure channel after apply.

### 09:15 — Sprint 1 Apply

**T1 (NW + SEC), T2 (SOC + OPS), T3 (CSVCS), T4 (Spoke NW cmps) — apply in parallel.**

Each team goes to their ORM Stack → Plan → Review → Apply.

What gets created per team:

| Team | Compartments Created | Groups Created |
|---|---|---|
| T1 | `C1_R_ELZ_NW`, `C1_R_ELZ_SEC` | `UG_ELZ_NW`, `UG_ELZ_SEC` |
| T2 | `C1_R_ELZ_SOC`, `C1_R_ELZ_OPS` | `UG_ELZ_SOC`, `UG_ELZ_OPS` |
| T3 | `C1_R_ELZ_CSVCS`, `C1_R_ELZ_DEVT_CSVCS` | `UG_ELZ_CSVCS`, `UG_DEVT_CSVCS` |
| T4 | `C1_OS_ELZ_NW`, `C1_SS_ELZ_NW`, `C1_TS_ELZ_NW`, `C1_DEVT_ELZ_NW` | `UG_OS_ELZ_NW`, `UG_SS_ELZ_NW`, `UG_TS_ELZ_NW`, `UG_DEVT_ELZ_NW` |

Each team applies their own ORM Stack once. Terraform automatically creates compartments → groups → policies in the correct order via `depends_on` — no manual sequencing needed. All 4 teams apply simultaneously.

> ⚠️ **If tag namespace apply fails with "resource in conflicted state":** This was caused by the old `tag_default` reusing `oci_identity_tag.owner.id`. It is fixed in today's code. The fix adds `DataClassification` as a dedicated tag and applies `lifecycle { prevent_destroy = true }` on the namespace. If ORM still errors, import the existing namespace: `terraform import oci_identity_tag_namespace.elz_v1 <ocid>` then re-apply.

### 10:00 — Validate Sprint 1 (CLI)

Run from any terminal with OCI CLI configured:

```bash
# Confirm 10 compartments exist under the tenancy root
oci iam compartment list --compartment-id <tenancy_ocid> \
  --all --query "data[?contains(name,'ELZ')].name" --output table

# Confirm 10 groups exist
oci iam group list --compartment-id <tenancy_ocid> \
  --all --query "data[?contains(name,'UG')].name" --output table

# Confirm tag namespace
oci iam tag-namespace list --compartment-id <tenancy_ocid> \
  --all --query "data[?name=='C0-star-elz-v1'].{Name:name,State:\"lifecycle-state\"}" \
  --output table

# Confirm DataClassification tag exists
oci iam tag list --tag-namespace-id <tag_namespace_ocid> \
  --all --query "data[].name" --output table
# Expected: ["CostCenter","DataClassification","Environment","ManagedBy","Owner"]

# Confirm CostCenter is cost-tracking
oci iam tag get --tag-namespace-id <tag_namespace_ocid> --tag-name CostCenter \
  --query "data.\"is-cost-tracking\""
# Expected: true
```

**TC-03 (SoD validation):**

```bash
# UG_ELZ_NW must have only READ (not manage) in spoke compartments
# Check 1: confirm no manage verb appears for any spoke compartment
oci iam policy list --compartment-id <tenancy_ocid> --all \
  --query "data[?name=='UG_ELZ_NW-Policy'].statements" --output json | \
  jq '.[][] | select(
    (contains("C1_OS_ELZ_NW") or contains("C1_TS_ELZ_NW") or
     contains("C1_SS_ELZ_NW") or contains("C1_DEVT_ELZ_NW"))
    and contains("manage")
  )'
# Expected: no output (empty = PASS)
# If any output appears: NW admin has manage rights on a spoke — SoD violation

# Check 2: confirm READ verb IS present for spokes (positive confirmation)
oci iam policy list --compartment-id <tenancy_ocid> --all \
  --query "data[?name=='UG_ELZ_NW-Policy'].statements" --output json | \
  jq '[.[][] | select(contains("C1_OS_ELZ_NW") and contains("read"))] | length'
# Expected: 1 (one read statement per spoke — confirms policy is correctly set)
```

**TC-04 (SOC read-only):**

```bash
oci iam policy list --compartment-id <tenancy_ocid> --all \
  --query "data[?name=='UG_ELZ_SOC-Policy'].statements" --output json | \
  jq '.[][] | select(contains("manage") or contains("use") or contains("create"))'
# Expected: no output — only "read" verbs allowed
```

### 10:30 — Capture Sprint 1 Outputs

```bash
cd sprint1/
terraform output -json > ../docs/sprint1_outputs.json
cat ../docs/sprint1_outputs.json | jq 'keys'
```

Expected keys:

```
["csvcs_compartment_id","devt_csvcs_compartment_id","devt_nw_compartment_id",
 "enclosing_compartment_id","group_names","home_region","nw_compartment_id",
 "ops_compartment_id","os_nw_compartment_id","parent_compartment_id",
 "sec_compartment_id","sim_child_compartment_id","sim_ext_compartment_id",
 "soc_compartment_id","ss_nw_compartment_id","tag_namespace_id",
 "tag_namespace_name","tenancy_id","ts_nw_compartment_id"]
```

Use this one-liner to pre-fill the Sprint 2 handoff values for your teams:

```bash
cat ../docs/sprint1_outputs.json | jq -r '
"nw_compartment_id         = \"" + .nw_compartment_id.value + "\"",
"os_compartment_id         = \"" + .os_nw_compartment_id.value + "\"",
"ts_compartment_id         = \"" + .ts_nw_compartment_id.value + "\"",
"ss_compartment_id         = \"" + .ss_nw_compartment_id.value + "\"",
"devt_compartment_id       = \"" + .devt_nw_compartment_id.value + "\"",
"sec_compartment_id        = \"" + .sec_compartment_id.value + "\"",
"soc_compartment_id        = \"" + .soc_compartment_id.value + "\"",
"ops_compartment_id        = \"" + .ops_compartment_id.value + "\"",
"csvcs_compartment_id      = \"" + .csvcs_compartment_id.value + "\"",
"devt_csvcs_compartment_id = \"" + .devt_csvcs_compartment_id.value + "\""'
```

Copy the output directly into `sprint2/terraform.tfvars` Section 3. Paste this output into the team's secure Slack channel — not email, not a public channel.

### 11:00 — Sprint 1 Gate Review

Before calling Sprint 1 done, you should be able to answer YES to all of these:

- [ ] `terraform plan` on Sprint 1 stack shows **0 changes**
- [ ] 10 compartments visible in OCI Console under the correct parent
- [ ] 10 groups visible in Identity → Groups
- [ ] Tag namespace `C0-star-elz-v1` active with 5 tags
- [ ] `DataClassification` tag default active at tenancy root
- [ ] `CostCenter` has `is_cost_tracking = true`
- [ ] 11 policies visible under the tenancy — no SoD violations
- [ ] `sprint_state_ledger.json` updated: `sprint1.status = "complete"`

---

## Afternoon — Sprint 2: Hub-and-Spoke Networking (13:00–17:00)

### 13:00 — Phase 1 Apply (All Teams Simultaneously)

Each team populates their `sprint2/terraform.tfvars` with the OCIDs from the morning and sets `hub_drg_id = ""` (empty = Phase 1 mode). Then:

```bash
cd sprint2/
terraform init
terraform plan -out=phase1.tfplan 2>&1 | tee plan_phase1.log
# Review plan: expect VCN + subnets only. No DRG attachments. No compute.
terraform apply phase1.tfplan
```

Phase 1 resources per team:

| Team | Resources Created |
|---|---|
| T1 | `vcn_os_elz_nw` (10.1.0.0/24), `sub_os_elz_nw_app`, `rt_os_elz_nw_app` (empty) |
| T2 | `vcn_ts_elz_nw` (10.3.0.0/24), `sub_ts_elz_nw_app`, `rt_ts_elz_nw_app` (empty) |
| T3 | `vcn_ss_elz_nw` (10.2.0.0/24) + `vcn_devt_elz_nw` (10.4.0.0/24), subnets, RTs (empty) |
| T4 | `vcn_r_elz_nw` (10.0.0.0/16), `sub_r_elz_nw_fw`, `sub_r_elz_nw_mgmt`, `drg_r_hub`, `drg_r_ew_hub`, RTs |

> ✅ **drg_r_ew_hub is provisioned with zero attachments in V1.** It is a V2 placeholder for East-West segmentation. TC-12b validates its existence.

### 14:00 — T4 Captures and Shares DRG OCID

**T4 only:**

```bash
terraform output hub_drg_id
# Copy the full OCID: ocid1.drg.oc1.ap-singapore-2.xxxxxxxxxxxxxxx
```

Distribute to T1, T2, T3 via secure channel. All four teams update `hub_drg_id` in their `terraform.tfvars`.

### 14:15 — Phase 2 Apply (All Teams Simultaneously)

```bash
# Each team sets hub_drg_id in their tfvars then:
terraform apply 2>&1 | tee apply_phase2.log
```

Phase 2 resources added per team:

| Team | Resources Added |
|---|---|
| T1 | `drga_os_elz_nw` (DRG attachment), `rt_os_elz_nw_app` (0.0.0.0/0 → DRG), `fw_os_elz_nw_sim` |
| T2 | `drga_ts_elz_nw`, `rt_ts_elz_nw_app` (0.0.0.0/0 → DRG), `fw_ts_elz_nw_sim` |
| T3 | `drga_ss_elz_nw`, `drga_devt_elz_nw`, RTs updated, `fw_ss_elz_nw_sim` |
| T4 | `drga_r_elz_nw_hub`, Hub RTs updated, `fw_r_elz_nw_hub_sim`, `bas_r_elz_nw_hub` |

> **4 Sim FW instances total**: hub, OS, TS, SS. DEVT has no Sim FW in V1 (network-only spoke).

### 15:00 — Sprint 2 Validation (TC-07 to TC-12b)

```bash
# TC-07: 5 VCNs exist
oci network vcn list --compartment-id <tenancy_ocid> --all \
  --query "data[?contains(\"display-name\",'ELZ-NW')].\"display-name\"" --output table

# TC-08: 6 subnets exist (2 hub + 4 spoke app subnets)
# Must query each compartment separately — subnets live in their own spoke compartments
for CMP in <nw_compartment_id> <os_compartment_id> <ts_compartment_id> <ss_compartment_id> <devt_compartment_id>; do
  oci network subnet list --compartment-id $CMP --all \
    --query "data[].\"display-name\"" --output table
done
# Expected total: 6 subnets across all 5 compartments
# Hub (nw): sub_r_elz_nw_fw, sub_r_elz_nw_mgmt
# OS:   sub_os_elz_nw_app
# TS:   sub_ts_elz_nw_app
# SS:   sub_ss_elz_nw_app
# DEVT: sub_devt_elz_nw_app

# TC-09: Hub DRG has 5 attachments (1 hub VCN + 4 spoke VCNs)
oci network drg-attachment list --drg-id <hub_drg_id> --all \
  --query "data[].\"display-name\"" --output table
# Expected: drga_r_elz_nw_hub, drga_os_elz_nw, drga_ts_elz_nw,
#           drga_ss_elz_nw, drga_devt_elz_nw

# TC-10: 4 Sim FW instances in RUNNING state
# Set these from terraform output -json > sprint2_outputs.json before running
NW_CMP=<paste nw_compartment_id>
OS_CMP=<paste os_compartment_id>
TS_CMP=<paste ts_compartment_id>
SS_CMP=<paste ss_compartment_id>

for CMP in $NW_CMP $OS_CMP $TS_CMP $SS_CMP; do
  oci compute instance list --compartment-id $CMP --all \
    --query "data[?contains(\"display-name\",'SIM')].{Name:\"display-name\",State:\"lifecycle-state\"}" \
    --output table
done
# Expected: 4 rows total, all State = RUNNING
# Hub SIM in NW_CMP, OS/TS/SS SIMs in their respective compartments

# TC-11: Hub Bastion is ACTIVE
oci bastion bastion list --compartment-id <nw_compartment_id> --all \
  --query "data[?contains(name,'BAS')].{Name:name,State:\"lifecycle-state\"}" --output table

# TC-12: Terraform plan shows zero drift
terraform plan   # must show: No changes. Your infrastructure matches the configuration.

# TC-12b: E-W DRG exists in C1_R_ELZ_NW
oci network drg list --compartment-id <nw_compartment_id> --all \
  --query "data[?\"display-name\"=='drg_r_ew_hub'].{Name:\"display-name\",State:\"lifecycle-state\"}" \
  --output table
# Expected: drg_r_ew_hub  AVAILABLE

# TC-13/14: Route table validation — each spoke RT has 0.0.0.0/0 → DRG
oci network route-table list --compartment-id <os_cmp_id> --all \
  --query "data[].{Name:\"display-name\",Rules:\"route-rules\"}" --output json | \
  jq '.[] | {name: .Name, default_route: [.Rules[] | select(.destination=="0.0.0.0/0")] }'
```

### 15:30 — Tag Verification on Network Resources

Confirm Sprint 2 resources carry Sprint 1 defined tags and Sprint 2 freeform tags.

> **Note on DataClassification:** This tag is applied via a Tag Default at tenancy root — OCI
> auto-stamps it on new resources but it appears under `system-tags`, not `defined-tags`.
> You will NOT see it in the defined-tags query below. That is correct behaviour, not a bug.
> To verify it is stamping, check the OCI Console: open the OS VCN → Tags tab → look for
> `C0-star-elz-v1.DataClassification = Official-Closed` under Default Tags.
```bash
oci network vcn get --vcn-id <os_vcn_id> \
  --query "data.{freeform: \"freeform-tags\", defined: \"defined-tags\"}" --output json
# Expect defined-tags: C0-star-elz-v1.{Environment, Owner, ManagedBy, CostCenter}
# Expect freeform-tags: {sprint: "sprint2-networking", ...}
# DataClassification = Official-Closed visible in OCI Console Tags tab (tag default — not in API defined-tags)
```

### 16:00 — Update State Ledger and Close Sprint 2

```bash
# Update sprint_state_ledger.json fields:
#   sprint2.status              = "complete"
#   sprint2.hub_drg_ocid        = <value from terraform output hub_drg_id>
#   sprint2.ew_drg_ocid         = <value from terraform output ew_hub_drg_id>
#   sprint2.sim_fw_count        = 4
#   sprint2.bastion_active      = true

git add sprint_state_ledger.json docs/sprint1_outputs.json
git commit -m "chore: Sprint 2 complete — state ledger and S1 output snapshot"
git push
```

---

## Architect's Guardrails — Troubleshooting During the Day

### "My DRG attachment failed with a dependency error"

**Cause:** Route table update ran before the DRG attachment was ready.
**Fix:** The `depends_on = [oci_core_drg_attachment.*]` block in each spoke RT prevents this. If it still happens, run `terraform apply` again — it is idempotent. The dynamic `route_rules` block does an in-place update; no subnet recreation occurs.

### "The Sim FW instance didn't come up / is PROVISIONING"

**Cause:** OL8 platform image data source may take 30–60 seconds to resolve on first apply in a new region.
**What to say:** "Give it 2 minutes and run `terraform apply` again. The count gate (`count = local.phase2_enabled ? 1 : 0`) is already set correctly — it's just image resolution lag."

**Verify FW is routing:**

```bash
# SSH via Bastion to the Sim FW, then:
sysctl net.ipv4.ip_forward
# Must return: net.ipv4.ip_forward = 1
iptables -t nat -L POSTROUTING
# Must show MASQUERADE rule on eth0
```

### "Spoke route table isn't pointing to DRG"

**Cause:** Team forgot to set `hub_drg_id` or Phase 2 apply hasn't run yet.
**Checklist:**
1. `cat terraform.tfvars | grep hub_drg_id` — must be non-empty.
2. `terraform output hub_drg_id` from T4's directory — must return an OCID.
3. Run `terraform plan` — if it shows route rule additions, `hub_drg_id` is now set and apply will fix it.
4. Confirm DRG attachment status: `oci network drg-attachment list --drg-id <id> --all`.

**What to say:** "Your route table is empty because `hub_drg_id` was blank during Phase 1. Set it now and apply — the dynamic `route_rules` block adds the default route in-place. No subnet deletion."

### "TC-03 SoD test fails — NW admin can modify spoke resources"

**Cause:** Old code had `manage virtual-network-family` in spoke compartments. Today's push changed it to `read`. If anyone is running from an old branch, they will fail this test.
**Fix:** Confirm the policy statement on `UG_ELZ_NW-Policy` says `read` not `manage` for spoke compartments.

```bash
oci iam policy list --compartment-id <tenancy_ocid> --all \
  --query "data[?name=='UG_ELZ_NW-Policy'].statements" --output json | \
  jq '.[][] | select(contains("spoke") or contains("OS") or contains("TS") or contains("SS") or contains("DEVT"))'
```

### "ORM shows drift on next plan after apply"

**Cause:** Likely a `terraform.tfstate` file was committed or ORM is reading a different state backend.
**Fix:**
1. Confirm `.gitignore` excludes `*.tfstate` — should be in today's push.
2. Go to ORM Stack → Jobs → the failing plan → Download logs. Look for `state file` references.
3. If state is genuinely drifted (someone ran CLI apply against ORM's state), contact TCE team with the Job OCID.
**What to say:** "Do not run `terraform destroy` and `apply` to fix drift. Reach out first so we can import the drifted resource."

### "Tag default isn't appearing on new resources"

**Cause:** OCI tag service propagation takes up to 10 seconds. `is_required = false` on the `data_classification` tag default means creation is not blocked, but tagging may lag.
**Fix:** Wait 30 seconds and check again. If tags are still missing, confirm the `tag_default` resource for `DataClassification` exists:

```bash
oci iam tag-default list --compartment-id <tenancy_ocid> \
  --query "data[?\"tag-definition-name\"=='DataClassification'].{Value:value,State:\"lifecycle-state\"}" \
  --output table
```

### Traffic Flow Reality — What Works Now vs Sprint 3

**DRG v2 full-mesh:** OCI DRG v2 with no custom `drg_route_table` on attachments defaults to full-mesh. Every attached VCN can reach every other attached VCN via the DRG fabric. This means **spoke-to-spoke ping works right now**.

**Works — testable in Sprint 2 (NPA + data plane):**

| Path | Method | TC |
|---|---|---|
| Spoke → Hub FW subnet (e.g. OS 10.1.0.x → Hub 10.0.0.x) | NPA + Bastion SSH | TC-13, TC-15 |
| Spoke → Spoke (e.g. OS 10.1.0.x → TS 10.3.0.x) | NPA + ping/traceroute | TC-14, TC-18, TC-19 |
| Hub MGMT → any spoke (Bastion reachability) | NPA + Bastion SSH | TC-18, TC-15 |
| Hub Sim FW → all spoke Sim FWs | ping/traceroute/tcpdump/TCP:22 | TC-19 |

**Does NOT work yet — Sprint 3 (S3-BACKLOG-01):**

Forced inspection through Hub FW. Currently OS → TS traffic goes DRG-direct, it does not hairpin through the Hub Sim FW VNIC. The Hub FW route table (`rt_r_elz_nw_fw`) is intentionally empty in V1. Sprint 3 adds `oci_core_drg_route_table` + `oci_core_drg_route_distribution` + VCN ingress route table to force all spoke traffic via the Hub FW.

**What to say:** "Spoke-to-spoke ping works — the DRG v2 full-mesh routes it directly. What we don't have yet is forced inspection through the Hub Firewall. That's the DRG transit routing in Sprint 3. Sprint 2 proves the fabric is connected; Sprint 3 adds the security enforcement point."

---

## End of Day — Close Out

- [ ] All 4 teams: `terraform plan` shows 0 changes
- [ ] `sprint_state_ledger.json` committed with `sprint2.status = "complete"`
- [ ] GitHub Issues TC-07 to TC-12b on StarPrj board updated as DONE
- [ ] Sprint 3 backlog items confirmed: Service Gateways, DRG transit routing, Cloud Guard TF import
- [ ] Open items escalated: Clean Tenancy Script (Amit/Inderpal), Multi-Tenancy strategy (TCE/Paxton)
- [ ] ORM drift anomaly (Feb 26) — TCE team log review still pending
