# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM POLICIES — TEAM 4 OWNED FILE
# Team 4 domain: Agency Spoke Networks
# Sprint 1, Week 2 | SPRINT1-ISSUE-#14
# Branch: sprint1/iam-policies-team4
# =============================================================================
#
# POLICY OBJECTS IN THIS FILE (4 of 11):
#   8.  UG_OS_ELZ_NW-Policy   — OS spoke: manage all-resources in C1_OS_ELZ_NW
#   9.  UG_SS_ELZ_NW-Policy   — SS spoke: manage all-resources in C1_SS_ELZ_NW
#   10. UG_TS_ELZ_NW-Policy   — TS spoke: manage all-resources in C1_TS_ELZ_NW
#   11. UG_DEVT_ELZ_NW-Policy — DEVT spoke: manage all-resources in C1_DEVT_ELZ_NW
#
# DESIGN: 1 group → 1 compartment → 1 policy (matches architecture diagram).
# Each policy is a separate OCI policy object for clear Console visibility
# and per-compartment audit trail.
#
# CRITICAL SoD RULES (TC-03):
#   Each spoke group is scoped to its own compartment ONLY.
#   No spoke group appears in any statement granting access to:
#     - C1_R_ELZ_SEC  (Security)
#     - C1_R_ELZ_NW   (Hub Network)
#     - C1_R_ELZ_OPS  (Operations)
#     - C1_R_ELZ_SOC  (SOC)
#     - Another spoke's compartment
#   TC-03 negative test: UG_DEVT_ELZ_NW attempting to create a resource in
#   C1_R_ELZ_SEC must receive HTTP 403 Authorization failed.
# =============================================================================

locals {
  team4_policies = {

    # -------------------------------------------------------------------------
    # UG_OS_ELZ_NW-Policy — OS Spoke Network Administrator
    # -------------------------------------------------------------------------
    "OS-NW-POLICY" : {
      name : local.os_nw_policy_name
      description : "${local.lz_description} — OS Spoke Network policy. UG_OS_ELZ_NW manages C1_OS_ELZ_NW only."
      compartment_id : local.tenancy_id
      statements : [
        "allow group ${join(",", local.os_nw_admin_group_name)} to manage all-resources in compartment ${local.provided_os_nw_compartment_name}"
      ]
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_SS_ELZ_NW-Policy — SS Spoke Network Administrator
    # -------------------------------------------------------------------------
    "SS-NW-POLICY" : {
      name : local.ss_nw_policy_name
      description : "${local.lz_description} — SS Spoke Network policy. UG_SS_ELZ_NW manages C1_SS_ELZ_NW only."
      compartment_id : local.tenancy_id
      statements : [
        "allow group ${join(",", local.ss_nw_admin_group_name)} to manage all-resources in compartment ${local.provided_ss_nw_compartment_name}"
      ]
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_TS_ELZ_NW-Policy — TS Spoke Network Administrator
    # -------------------------------------------------------------------------
    "TS-NW-POLICY" : {
      name : local.ts_nw_policy_name
      description : "${local.lz_description} — TS Spoke Network policy. UG_TS_ELZ_NW manages C1_TS_ELZ_NW only."
      compartment_id : local.tenancy_id
      statements : [
        "allow group ${join(",", local.ts_nw_admin_group_name)} to manage all-resources in compartment ${local.provided_ts_nw_compartment_name}"
      ]
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_DEVT_ELZ_NW-Policy — DEVT Spoke Network Administrator
    # -------------------------------------------------------------------------
    "DEVT-NW-POLICY" : {
      name : local.devt_nw_policy_name
      description : "${local.lz_description} — DEVT Spoke Network policy. UG_DEVT_ELZ_NW manages C1_DEVT_ELZ_NW only."
      compartment_id : local.tenancy_id
      statements : [
        "allow group ${join(",", local.devt_nw_admin_group_name)} to manage all-resources in compartment ${local.provided_devt_nw_compartment_name}"
      ]
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    }
  }
}
