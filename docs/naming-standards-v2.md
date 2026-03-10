# STAR ELZ V1 — Naming Standards & Code Changes

All Terraform code must produce exactly these resource names.
No deviations. No prefixes. No suffixes. No deployment_identifier on sub-resources.

> **Destroy current state before applying** — see the Destroy section at the bottom.

---

## Compartments

| Name | Purpose |
|------|---------|
| `C1_OS_ELZ_NW` | Operational Systems spoke — VCN, subnets, workloads |
| `C1_SS_ELZ_NW` | Shared Services spoke — VCN, subnets, workloads |
| `C1_TS_ELZ_NW` | Trusted Services spoke — VCN, subnets, workloads |
| `C1_DEVT_ELZ_NW` | Development/Test spoke — VCN, subnets |
| `C1_R_ELZ_NW` | Hub network — DRG, Hub VCN, route tables, Sim FW, Bastion |
| `C1_R_ELZ_SEC` | Security services — Cloud Guard, Vaults |
| `C1_R_ELZ_SOC` | SOC — read-only monitoring, log review, incident response |
| `C1_R_ELZ_OPS` | Operations — monitoring, logging, alarms |
| `C1_R_ELZ_CSVCS` | Common shared services — APM, File Transfer, ServiceNow |
| `C1_R_ELZ_DEVT_CSVCS` | Development common services — dev toolchain |
| `C1_SIM_EXT` | **Temporary V1** — Dummy AD, DNS Bridge |
| `C1_SIM_CHILD` | **Temporary V1** — Hello World workload |


---

## IAM User Groups

| Name | Owns |
|------|------|
| `UG_OS_ELZ_NW` | `C1_OS_ELZ_NW` |
| `UG_SS_ELZ_NW` | `C1_SS_ELZ_NW` |
| `UG_TS_ELZ_NW` | `C1_TS_ELZ_NW` |
| `UG_DEVT_ELZ_NW` | `C1_DEVT_ELZ_NW` |
| `UG_ELZ_NW` | `C1_R_ELZ_NW` — hub network, DRG, all spoke VCNs |
| `UG_ELZ_SEC` | `C1_R_ELZ_SEC` — Vault, Cloud Guard, Security Zones |
| `UG_ELZ_SOC` | Read-only across tenancy — monitoring only |
| `UG_ELZ_OPS` | `C1_R_ELZ_OPS` — logging, monitoring, alarms |
| `UG_ELZ_CSVCS` | `C1_R_ELZ_CSVCS` |
| `UG_DEVT_CSVCS` | `C1_R_ELZ_DEVT_CSVCS` |
| `UG_SIM_EXT` | **Temporary V1** — `C1_SIM_EXT` |
| `UG_SIM_CHILD` | **Temporary V1** — `C1_SIM_CHILD` |

---

## IAM Policies

| Name | Scope |
|------|-------|
| `UG_ELZ_NW-Policy` | Hub and spoke network grants + root read |
| `UG_ELZ_NW-Policy-Root` | Network admin root-level grants |
| `UG_ELZ_SEC-Policy` | Security compartment grants |
| `UG_ELZ_SEC-Policy-Root` | Security admin root-level grants |
| `UG_ELZ_SOC-Policy` | Read-only tenancy grants |
| `UG_ELZ_OPS-Policy` | Operations compartment grants |
| `UG_ELZ_CSVCS-Policy` | Common services compartment grants |
| `UG_DEVT_CSVCS-Policy` | Dev common services compartment grants |
| `UG_OS_ELZ_NW-Policy` | OS spoke grants |
| `UG_SS_ELZ_NW-Policy` | SS spoke grants |
| `UG_TS_ELZ_NW-Policy` | TS spoke grants |
| `UG_DEVT_ELZ_NW-Policy` | DEVT spoke grants |
| `OCI-Services-Policy` | OCI service principals — Cloud Guard, Object Storage, VSS |

---

## Naming Rules

| Rule | Detail |
|------|--------|
| **Prefix** | Always `C1_` for compartments, `UG_` for groups |
| **Separator** | Underscore `_` throughout — no hyphens in compartment or group names |
| **Case** | All uppercase for compartments and groups |
| **Policy suffix** | `-Policy` with hyphen, title case |
| **No deployment_identifier** | Sub-compartments and groups are never prefixed with participant names |
| **Tag namespace** | `c1-elz-v1` — lowercase, hyphens |
| **Temporary resources** | `_SIM_EXT` / `_SIM_CHILD` — removed in V2 |

---

## Terraform Variable Mapping

```hcl
service_label              = "C1"
deployment_identifier      = ""   # empty — no prefix on any resource
```

---

## Code Changes Required — 6 Files

### File 1 — `iam_compartments.tf`

Replace the `provided_*` compartment name locals block with:

```hcl
provided_nw_compartment_name         = coalesce(var.custom_nw_compartment_name,         upper("${var.service_label}_R_ELZ_NW"))
provided_sec_compartment_name        = coalesce(var.custom_sec_compartment_name,        upper("${var.service_label}_R_ELZ_SEC"))
provided_soc_compartment_name        = coalesce(var.custom_soc_compartment_name,        upper("${var.service_label}_R_ELZ_SOC"))
provided_ops_compartment_name        = coalesce(var.custom_ops_compartment_name,        upper("${var.service_label}_R_ELZ_OPS"))
provided_csvcs_compartment_name      = coalesce(var.custom_csvcs_compartment_name,      upper("${var.service_label}_R_ELZ_CSVCS"))
provided_devt_csvcs_compartment_name = coalesce(var.custom_devt_csvcs_compartment_name, upper("${var.service_label}_R_ELZ_DEVT_CSVCS"))
provided_os_nw_compartment_name      = coalesce(var.custom_os_nw_compartment_name,      upper("${var.service_label}_OS_ELZ_NW"))
provided_ss_nw_compartment_name      = coalesce(var.custom_ss_nw_compartment_name,      upper("${var.service_label}_SS_ELZ_NW"))
provided_ts_nw_compartment_name      = coalesce(var.custom_ts_nw_compartment_name,      upper("${var.service_label}_TS_ELZ_NW"))
provided_devt_nw_compartment_name    = coalesce(var.custom_devt_nw_compartment_name,    upper("${var.service_label}_DEVT_ELZ_NW"))
```

With `service_label = "C1"` this produces `C1_R_ELZ_NW`, `C1_R_ELZ_SEC` etc.

---

### File 2 — `iam_groups.tf`

Remove `${local.id_prefix}` from all group name defaults — names are already correct:

```hcl
provided_nw_admin_group_name         = coalesce(local.custom_nw_admin_group_name,        "UG_ELZ_NW")
provided_sec_admin_group_name        = coalesce(local.custom_sec_admin_group_name,        "UG_ELZ_SEC")
provided_soc_group_name              = coalesce(local.custom_soc_group_name,              "UG_ELZ_SOC")
provided_ops_admin_group_name        = coalesce(local.custom_ops_admin_group_name,        "UG_ELZ_OPS")
provided_csvcs_admin_group_name      = coalesce(local.custom_csvcs_admin_group_name,      "UG_ELZ_CSVCS")
provided_devt_csvcs_admin_group_name = coalesce(local.custom_devt_csvcs_admin_group_name, "UG_DEVT_CSVCS")
provided_os_nw_admin_group_name      = coalesce(local.custom_os_nw_admin_group_name,      "UG_OS_ELZ_NW")
provided_ss_nw_admin_group_name      = coalesce(local.custom_ss_nw_admin_group_name,      "UG_SS_ELZ_NW")
provided_ts_nw_admin_group_name      = coalesce(local.custom_ts_nw_admin_group_name,      "UG_TS_ELZ_NW")
provided_devt_nw_admin_group_name    = coalesce(local.custom_devt_nw_admin_group_name,    "UG_DEVT_ELZ_NW")
```

---

### File 3 — `iam_policies_team1.tf`

Remove `${local.id_prefix}` from all 4 policy names:

```hcl
name : "UG_ELZ_NW-Policy-Root"
name : "UG_ELZ_NW-Policy"
name : "UG_ELZ_SEC-Policy-Root"
name : "UG_ELZ_SEC-Policy"
```

---

### File 4 — `iam_policies_team2.tf`

```hcl
name : "UG_ELZ_SOC-Policy"
name : "UG_ELZ_OPS-Policy"
```

---

### File 5 — `iam_policies_team3.tf`

```hcl
name : "UG_ELZ_CSVCS-Policy"
name : "OCI-Services-Policy"
```

---

### File 6 — `iam_policies_team4.tf`

```hcl
name : "UG_OS_ELZ_NW-Policy"
name : "UG_SS_ELZ_NW-Policy"
name : "UG_TS_ELZ_NW-Policy"
name : "UG_DEVT_ELZ_NW-Policy"
```

---

## Change Summary

| File | What changes |
|------|-------------|
| `iam_compartments.tf` | Add `upper()` + change `-` to `_` + remove `-cmp` suffix |
| `iam_groups.tf` | Remove `${local.id_prefix}` — names already correct |
| `iam_policies_team1.tf` | Remove `${local.id_prefix}` |
| `iam_policies_team2.tf` | Remove `${local.id_prefix}` |
| `iam_policies_team3.tf` | Remove `${local.id_prefix}` |
| `iam_policies_team4.tf` | Remove `${local.id_prefix}` |

---

## Destroy and Redeploy

**Step 1 — Destroy existing state**

Via ORM:
```
ORM Stack → Terraform Actions → Destroy → Automatically Approve
```

Via Cloud Shell:
```bash
cd elz
terraform destroy -auto-approve
```

Wait for full completion. Compartments with `enable_delete = false` enter a
90-second soft-delete — do not re-apply until the destroy job shows succeeded.

**Step 2 — Verify clean**

```bash
oci iam compartment list \
  --compartment-id <tenancy-ocid> \
  --query "data[?contains(name,'ELZ')].name" \
  --output table
# Expected: empty list
```

**Step 3 — Update the 6 files above, push to GitHub**

```bash
git add iam_compartments.tf iam_groups.tf \
        iam_policies_team1.tf iam_policies_team2.tf \
        iam_policies_team3.tf iam_policies_team4.tf
git commit -m "Standardise resource names — uppercase underscore, remove id_prefix"
git push
```

**Step 4 — Apply clean**

```
ORM Stack → Edit Stack → set deployment_identifier = "" → Save
Terraform Actions → Plan → confirm all names match standards above → Apply
```

Expected plan: `38 to add, 0 to change, 0 to destroy`
