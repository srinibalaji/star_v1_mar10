# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM GROUPS — TEAM 4 OWNED FILE
# Team 4 domain: Agency Spoke Networks
# Sprint 1, Week 2 | SPRINT1-ISSUE-#9
# Branch: sprint1/iam-groups-team4
# =============================================================================
#
# GROUPS IN THIS FILE (4 of 10 TF-managed):
#   7.  UG_OS_ELZ_NW   — Operational Systems Network Administrators
#   8.  UG_SS_ELZ_NW   — Shared Services Network Administrators
#   9.  UG_TS_ELZ_NW   — Trusted Services Network Administrators
#   10. UG_DEVT_ELZ_NW — Development/Test Network Administrators
#
# TEAM 4 ALSO OWNS (OCI Console — NOT Terraform):
#   UG_SIM_EXT   — TEMP V1 ONLY. Create in Console on Sprint 1 Day 1.
#   UG_SIM_CHILD — TEMP V1 ONLY. Create in Console on Sprint 1 Day 1.
#   Record in State Book: V1_Manual_Resources tab.
#
# CRITICAL TC-03:
#   UG_DEVT_ELZ_NW must NOT appear in any policy granting write to SEC cmp.
#   Its policy (per-spoke UG_*_ELZ_NW-Policy in iam_policies_team4.tf) grants manage
#   all-resources ONLY within C1_DEVT_ELZ_NW — not in C1_R_ELZ_SEC.
# =============================================================================

locals {
  team4_groups = {

    # -------------------------------------------------------------------------
    # UG_OS_ELZ_NW — Operational Systems Network Administrators
    # -------------------------------------------------------------------------
    (local.os_nw_admin_group_key) : {
      name : local.provided_os_nw_admin_group_name,
      description : "${local.lz_description} — OS Network Administrators. Operational Systems spoke VCN, subnets, NSGs.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_SS_ELZ_NW — Shared Services Network Administrators
    # -------------------------------------------------------------------------
    (local.ss_nw_admin_group_key) : {
      name : local.provided_ss_nw_admin_group_name,
      description : "${local.lz_description} — SS Network Administrators. Shared Services spoke VCN, subnets, NSGs.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_TS_ELZ_NW — Trusted Services Network Administrators
    # -------------------------------------------------------------------------
    (local.ts_nw_admin_group_key) : {
      name : local.provided_ts_nw_admin_group_name,
      description : "${local.lz_description} — TS Network Administrators. Trusted Services spoke VCN, subnets, NSGs.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_DEVT_ELZ_NW — Development/Test Network Administrators
    # CRITICAL TC-03: NO grants in SEC cmp — enforced in iam_policies_team4.tf
    # -------------------------------------------------------------------------
    (local.devt_nw_admin_group_key) : {
      name : local.provided_devt_nw_admin_group_name,
      description : "${local.lz_description} — DEVT Network Administrators. Dev/Test spoke VCN, subnets, NSGs. Network-only in V1.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    }
  }
}
