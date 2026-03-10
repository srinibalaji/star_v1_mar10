# Sprint 2 — Security Lists for Validation

**Date:** 3 March 2026 | **Purpose:** Enable ICMP ping + SSH between Sim FWs for TC-15, TC-18, TC-19
**Scope:** 6 security lists (one per subnet), 6 name constants in locals.tf
**Sprint 3:** These security lists are replaced with NSGs and tightened rules

---

## Step 1 — locals.tf (Principal Architect — before session)

Add these 6 name constants to the existing `locals` block:

```hcl
  # Security Lists — Sprint 2 validation (Sprint 3 replaces with NSGs)
  hub_fw_seclist_name   = "sl_r_elz_nw_fw"
  hub_mgmt_seclist_name = "sl_r_elz_nw_mgmt"
  os_app_seclist_name   = "sl_os_elz_nw_app"
  ts_app_seclist_name   = "sl_ts_elz_nw_app"
  ss_app_seclist_name   = "sl_ss_elz_nw_app"
  devt_app_seclist_name = "sl_devt_elz_nw_app"
```

---

## Step 2 — Team Files (each team adds during session)

Every security list uses the same pattern: egress all to `0.0.0.0/0`, ingress all from `10.0.0.0/8`. The only differences are compartment, VCN, and display name.

### T1 — nw_team1.tf (OS spoke)

Add after the `oci_core_subnet.os_app` block:

```hcl
resource "oci_core_security_list" "os_app" {
  compartment_id = var.os_compartment_id
  vcn_id         = oci_core_vcn.os.id
  display_name   = local.os_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}
```

Add one line to the existing `oci_core_subnet.os_app` resource:

```hcl
  security_list_ids = [oci_core_security_list.os_app.id]
```

---

### T2 — nw_team2.tf (TS spoke)

Add after the `oci_core_subnet.ts_app` block:

```hcl
resource "oci_core_security_list" "ts_app" {
  compartment_id = var.ts_compartment_id
  vcn_id         = oci_core_vcn.ts.id
  display_name   = local.ts_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}
```

Add one line to the existing `oci_core_subnet.ts_app` resource:

```hcl
  security_list_ids = [oci_core_security_list.ts_app.id]
```

---

### T3 — nw_team3.tf (SS + DEVT spokes — two security lists)

Add after the subnet blocks:

```hcl
resource "oci_core_security_list" "ss_app" {
  compartment_id = var.ss_compartment_id
  vcn_id         = oci_core_vcn.ss.id
  display_name   = local.ss_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}

resource "oci_core_security_list" "devt_app" {
  compartment_id = var.devt_compartment_id
  vcn_id         = oci_core_vcn.devt.id
  display_name   = local.devt_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}
```

Add one line to each existing subnet resource:

```hcl
# In oci_core_subnet.ss_app:
  security_list_ids = [oci_core_security_list.ss_app.id]

# In oci_core_subnet.devt_app:
  security_list_ids = [oci_core_security_list.devt_app.id]
```

---

### T4 — nw_team4.tf (Hub FW + Hub MGMT — two security lists)

Add after the subnet blocks:

```hcl
resource "oci_core_security_list" "hub_fw" {
  compartment_id = var.nw_compartment_id
  vcn_id         = oci_core_vcn.hub.id
  display_name   = local.hub_fw_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}

resource "oci_core_security_list" "hub_mgmt" {
  compartment_id = var.nw_compartment_id
  vcn_id         = oci_core_vcn.hub.id
  display_name   = local.hub_mgmt_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }
}
```

Add one line to each existing subnet resource:

```hcl
# In oci_core_subnet.hub_fw:
  security_list_ids = [oci_core_security_list.hub_fw.id]

# In oci_core_subnet.hub_mgmt:
  security_list_ids = [oci_core_security_list.hub_mgmt.id]
```

---

## Summary

| Team | File | Security Lists | Subnet Lines Added |
|---|---|---|---|
| Architect | locals.tf | 6 name constants | — |
| T1 | nw_team1.tf | `os_app` (1 resource) | 1 line on `oci_core_subnet.os_app` |
| T2 | nw_team2.tf | `ts_app` (1 resource) | 1 line on `oci_core_subnet.ts_app` |
| T3 | nw_team3.tf | `ss_app` + `devt_app` (2 resources) | 1 line each on `ss_app` and `devt_app` subnets |
| T4 | nw_team4.tf | `hub_fw` + `hub_mgmt` (2 resources) | 1 line each on `hub_fw` and `hub_mgmt` subnets |

**Total:** 6 new `oci_core_security_list` resources, 6 `security_list_ids` lines added to existing subnets.

**After apply:** Sprint 2 resource count goes from 32 to 38. All subnets allow ICMP + SSH from `10.0.0.0/8`. Ping validation (TC-15, TC-18, TC-19) works.
