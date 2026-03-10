# Sprint 1 → Sprint 2 Handoff

**Document:** `docs/HANDOFF.md`
**Owner:** Principal Architect
**Status:** Sprint 1 complete — Sprint 2 gate open

---

## Purpose

This file is the single handoff protocol between the Sprint 1 IAM team and the Sprint 2 Networking team. Follow it in order. Do not proceed to Sprint 2 until every row in [Step 2](#step-2--capture-sprint-1-outputs) has a real OCID value.

---

## Step 1 — Confirm Sprint 1 Apply Is Clean

Run this in the Sprint 1 directory (local CLI or ORM Job logs):

```bash
cd sprint1/
terraform show | grep -E "id\s+="
```

Expected: **no plan changes** after the most recent apply. If `terraform plan` shows a diff, resolve it before handing off.

Also confirm state ledger is up to date:

```bash
cat sprint_state_ledger.json | jq '.sprint1.status'
# Expected: "complete"
```

---

## Step 2 — Capture Sprint 1 Outputs

Run the following command **once** immediately after a clean Sprint 1 apply. Save the JSON file into the repo under `docs/` (never commit `terraform.tfvars`).

```bash
cd sprint1/
terraform output -json > ../docs/sprint1_outputs.json
cat ../docs/sprint1_outputs.json
```

The table below maps every Sprint 1 output to its Sprint 2 variable. The output key and variable key are **not identical** for spoke compartments — follow the mapping exactly.

| Sprint 1 `terraform output` key | Compartment Name | Sprint 2 `terraform.tfvars` variable | Used by |
|---|---|---|---|
| `nw_compartment_id` | `C1_R_ELZ_NW` | `nw_compartment_id` | Hub VCN, DRG-HUB, DRG-EW, Bastion |
| `os_nw_compartment_id` | `C1_OS_ELZ_NW` | `os_compartment_id` | OS spoke VCN + subnet |
| `ts_nw_compartment_id` | `C1_TS_ELZ_NW` | `ts_compartment_id` | TS spoke VCN + subnet |
| `ss_nw_compartment_id` | `C1_SS_ELZ_NW` | `ss_compartment_id` | SS spoke VCN + subnet |
| `devt_nw_compartment_id` | `C1_DEVT_ELZ_NW` | `devt_compartment_id` | DEVT spoke VCN + subnet |
| `sec_compartment_id` | `C1_R_ELZ_SEC` | `sec_compartment_id` | Sprint 3 (declare now) |
| `soc_compartment_id` | `C1_R_ELZ_SOC` | `soc_compartment_id` | Sprint 3 (declare now) |
| `ops_compartment_id` | `C1_R_ELZ_OPS` | `ops_compartment_id` | Sprint 3 (declare now) |
| `csvcs_compartment_id` | `C1_R_ELZ_CSVCS` | `csvcs_compartment_id` | Sprint 3 (declare now) |
| `devt_csvcs_compartment_id` | `C1_R_ELZ_DEVT_CSVCS` | `devt_csvcs_compartment_id` | Sprint 3 (declare now) |

> **Why the key rename?** Sprint 1 appends `_nw` to spoke compartment output keys to clarify they are network compartments. Sprint 2 drops the `_nw` suffix because it already lives inside the networking module context. This is intentional and documented in `sprint2/terraform.tfvars.template`.

---

## Step 3 — Populate Sprint 2 `terraform.tfvars`

Copy the template and fill in the OCIDs from Step 2:

```bash
cd sprint2/
cp terraform.tfvars.template terraform.tfvars
```

Then edit `terraform.tfvars`. The section that requires Sprint 1 OCIDs looks like this — replace every placeholder with the real OCID from `sprint1_outputs.json`:

```hcl
# =============================================================================
# SECTION 3 — Sprint 1 Compartment OCIDs (paste from: terraform output -json)
# =============================================================================

# Hub / Regional networking compartment
# Source: terraform output nw_compartment_id
nw_compartment_id           = "ocid1.compartment.oc1..REPLACE"

# Spoke networking compartments
# Source: terraform output os_nw_compartment_id   ← note _nw suffix in S1 output
os_compartment_id           = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output ts_nw_compartment_id
ts_compartment_id           = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output ss_nw_compartment_id
ss_compartment_id           = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output devt_nw_compartment_id
devt_compartment_id         = "ocid1.compartment.oc1..REPLACE"

# Management compartments (Sprint 3 scope — declare now, no S2 resources use them)
# Source: terraform output sec_compartment_id
sec_compartment_id          = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output soc_compartment_id
soc_compartment_id          = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output ops_compartment_id
ops_compartment_id          = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output csvcs_compartment_id
csvcs_compartment_id        = "ocid1.compartment.oc1..REPLACE"

# Source: terraform output devt_csvcs_compartment_id
devt_csvcs_compartment_id   = "ocid1.compartment.oc1..REPLACE"

# =============================================================================
# SECTION 4 — Phase 2 DRG Gate
# Leave EMPTY for Phase 1. Populate after T4 applies and outputs hub_drg_id.
# =============================================================================
hub_drg_id = ""
```

> ⚠️ **Do not** commit `terraform.tfvars`. It is in `.gitignore`. Share OCIDs via the secure channel (1Password / OCI Vault) or by running `terraform output` directly from the Sprint 1 ORM Job.

---

## Step 4 — Phase 1 Apply (All Teams Simultaneously)

With `hub_drg_id = ""`, all four teams apply at the same time. Phase 1 creates VCNs and subnets only. DRG attachments, Route Table rules, Sim FWs, and Bastion are **not** created yet (`count = 0`).

```bash
cd sprint2/
terraform init
terraform plan -out=phase1.tfplan
terraform apply phase1.tfplan
```

After T4 apply completes, T4 captures the DRG OCID:

```bash
terraform output hub_drg_id
# ocid1.drg.oc1.ap-singapore-2.xxxxxxx
```

Share this OCID with T1, T2, T3.

---

## Step 5 — Phase 2 Apply (All Teams)

Each team sets `hub_drg_id` in their `terraform.tfvars` (or ORM Variables UI) to the OCID from Step 4, then re-applies:

```hcl
hub_drg_id = "ocid1.drg.oc1.ap-singapore-2.xxxxxxx"
```

```bash
terraform apply   # applies DRG attachments, route rules, Sim FWs, Bastion
```

Phase 2 is complete when `terraform plan` shows **0 changes**.

---

## Step 6 — Verify Handoff Complete

```bash
# Sprint 2 Phase 2 outputs to confirm
terraform output hub_drg_id          # must be non-empty
terraform output ew_hub_drg_id       # must be non-empty  
terraform output hub_bastion_id      # must not be "not-provisioned-..."
terraform output sprint2_network_summary
```

Update `sprint_state_ledger.json`:

```bash
# Set sprint2.status = "complete" and record DRG OCIDs
```

---

## Spoke Addition Protocol (Sprint 3+)

Adding a 5th spoke requires changes in exactly four places — no other files need touching:

1. `sprint1/iam_cmps_team<N>.tf` — add new `C1_<AGENCY>_ELZ_NW` compartment
2. `sprint1/iam_groups_team<N>.tf` — add `UG_<AGENCY>_ELZ_NW` group
3. `sprint1/iam_policies_team<N>.tf` — grant spoke-level VCN management
4. `sprint2/nw_team<N>.tf` — add VCN, subnet, DRG attachment, RT, Sim FW (copy from `nw_team1.tf` pattern)

The Hub DRG (`drg_r_hub`) supports additional attachments without modification. No existing spoke is affected.
