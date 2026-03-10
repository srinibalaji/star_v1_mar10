# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM GROUPS — TEAM 1 OWNED FILE
# Team 1 domain: Hub Network + Security
# Sprint 1, Week 2 | SPRINT1-ISSUE-#6
# Branch: sprint1/iam-groups-team1
# =============================================================================
#
# GROUPS IN THIS FILE (2 of 10 TF-managed):
#   1. UG_ELZ_NW  — Global Network Administrators
#      Scope: Hub VCN, both DRGs, route tables, Sim FW (NW cmp)
#             + virtual-network-family in all 4 spoke compartments
#   2. UG_ELZ_SEC — Security Administrators
#      Scope: Vault, Cloud Guard, Security Zones, Bastion (SEC cmp)
#             + cloud-guard-family, tag-namespaces at tenancy root
#
# POLICY ALIGNMENT (iam_policies_team1.tf):
#   UG_ELZ_NW-Policy  — manage virtual-network-family + drgs in NW cmp
#                        manage virtual-network-family in all 4 spoke cmps
#                        read all-resources + use cloud-shell in tenancy
#   UG_ELZ_SEC-Policy — manage vaults, keys, bastion-family, security-zone in SEC cmp
#                        manage cloud-guard-family, tag-namespaces in tenancy
#
# SPRINT1-FIX (SPRINT1-ISSUE-#6, naming-drift):
#   Group name and description now use local.lz_description and constants.
# =============================================================================

locals {
  team1_groups = {

    # -------------------------------------------------------------------------
    # UG_ELZ_NW — Global Network Administrators
    # -------------------------------------------------------------------------
    (local.nw_admin_group_key) : {
      name : local.provided_nw_admin_group_name,
      description : "${local.lz_description} — Network Administrators. Hub VCN, DRGs, route tables, Sim FW, spoke VCNs.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_ELZ_SEC — Security Administrators
    # -------------------------------------------------------------------------
    (local.sec_admin_group_key) : {
      name : local.provided_sec_admin_group_name,
      description : "${local.lz_description} — Security Administrators. Vault, Cloud Guard, Security Zones, Bastion.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    }
  }
}
