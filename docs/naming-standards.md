# STAR ELZ V1 — Naming Standards

All Terraform code must produce exactly these resource names.
No deviations. No prefixes. No suffixes. No deployment_identifier on sub-resources.

> **Destroy current state before applying** if you have existing resources with
> AMIT_ or other prefixed names — see the Destroy section at the bottom.

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

All 12 compartments are children of the enclosing compartment `AD_LZ_Dev`.

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
| `UG_ELZ_SEC-Policy` | Security compartment grants |
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
| **Enclosing compartment** | `AD_LZ_Dev` — no `C1_` prefix, this is the wrapper not a spoke |
| **Tag namespace** | `c1-elz-v1` — lowercase, hyphens |
| **Temporary resources** | Suffix `_SIM_EXT` / `_SIM_CHILD` — removed in V2 |

---

## Destroy Current State First

If your tenancy has resources from a prior run with `deployment_identifier = "AMIT"`
or any other prefix, destroy before applying the corrected names.

**Via ORM:**
```
ORM Stack → Terraform Actions → Destroy → Automatically Approve
```

**Via Cloud Shell:**
```bash
cd elz
terraform destroy -auto-approve
```

Compartments with `enable_delete = true` are deleted immediately.
Compartments with `enable_delete = false` enter a 90-second soft-delete —
wait for completion before re-applying.

**Verify clean:**
```bash
# Should return empty list
oci iam compartment list \
  --compartment-id <tenancy-ocid> \
  --query "data[?contains(name,'ELZ')].name" \
  --output table
```

Then apply fresh with `deployment_identifier = ""`.
