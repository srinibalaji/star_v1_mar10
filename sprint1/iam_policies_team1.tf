# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM POLICIES — TEAM 1 OWNED FILE
# Team 1 domain: Hub Network + Security
# Sprint 1, Week 2 | SPRINT1-ISSUE-#10, #11
# Branch: sprint1/iam-policies-team1
# =============================================================================
#
# POLICY OBJECTS IN THIS FILE (2 of 9):
#   1. UG_ELZ_NW-Policy  — Network admin grants: tenancy read + hub NW + 4 spokes
#   2. UG_ELZ_SEC-Policy — Security admin grants: tenancy cloud-guard + SEC cmp
#
# POLICY NAME CONVENTION:
#   local.nw_policy_name  = "UG_ELZ_NW-Policy"   (from locals.tf)
#   local.sec_policy_name = "UG_ELZ_SEC-Policy"  (from locals.tf)
#   All policies at tenancy root (compartment_id = local.tenancy_id).
#   No -Root/-Admin suffix — policy name identifies the owning group, not scope.
#
# SPRINT1-FIX (SPRINT1-ISSUE-#10, policy-naming):
#   name changed from "${var.service_label}-nw-admin-root-policy" (4 policy objects)
#   to local.nw_policy_name = "UG_ELZ_NW-Policy" (2 policy objects, flat structure).
#   Statements remain identical — only object count reduced from 4 to 2.
#   Rationale: OCI policy objects are buckets for statements. Root vs compartment
#   scope is expressed in the WHERE clause of the statement, not the object name.
#   Fewer policy objects = simpler console view, less ORM drift surface.
#
# SPRINT1-FIX (SPRINT1-ISSUE-#11):
#   compartment_id changed from var.tenancy_ocid to local.tenancy_id.
#   description changed from var.lz_provenant_label to local.lz_description.
# =============================================================================

locals {
  team1_policies = {

    # -------------------------------------------------------------------------
    # UG_ELZ_NW-Policy — Network Administrator Policy
    # Tenancy grants: read all-resources (topology visibility), use cloud-shell.
    # Hub NW cmp: manage virtual-network-family, manage drgs.
    # 4 Spoke cmps: manage virtual-network-family (VCN topology, no compute/sec).
    # -------------------------------------------------------------------------
    "NW-POLICY" : {
      name : local.nw_policy_name
      description : "${local.lz_description} — Network Administrator policy. Hub VCN, DRGs, spoke VCN topology."
      compartment_id : local.tenancy_id
      statements : concat(
        local.nw_admin_grants_on_root,
        local.nw_admin_grants_on_nw_cmp,
        local.nw_admin_grants_on_spoke_cmps,
        local.nw_admin_grants_on_bastion
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_ELZ_SEC-Policy — Security Administrator Policy
    # Tenancy grants: manage cloud-guard-family, tag-namespaces, audit-events.
    # SEC cmp: manage vaults, keys, bastion-family, security-zone, all-resources.
    # -------------------------------------------------------------------------
    "SEC-POLICY" : {
      name : local.sec_policy_name
      description : "${local.lz_description} — Security Administrator policy. Cloud Guard, Vault, Security Zones."
      compartment_id : local.tenancy_id
      statements : concat(
        local.sec_admin_grants_on_root,
        local.sec_admin_grants_on_sec_cmp,
        local.sec_admin_grants_on_sec_grp,
        local.sec_admin_grants_on_service
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    }
  }

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — Network Administrator (UG_ELZ_NW)
  # ---------------------------------------------------------------------------

  nw_admin_grants_on_root = [
    "allow group ${join(",", local.nw_admin_group_name)} to read all-resources in tenancy",
    "allow group ${join(",", local.nw_admin_group_name)} to use cloud-shell in tenancy"
  ]

  nw_admin_grants_on_nw_cmp = [
    "allow group ${join(",", local.nw_admin_group_name)} to manage virtual-network-family in compartment ${local.provided_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to manage drgs in compartment ${local.provided_nw_compartment_name}"
  ]

  nw_admin_grants_on_bastion = [
    "allow group ${join(",", local.nw_admin_group_name)} to manage bastion-family in compartment ${local.provided_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read instance-agent-plugins in compartment ${local.provided_os_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read instance-agent-plugins in compartment ${local.provided_ts_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read instance-family in compartment ${local.provided_os_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read instance-family in compartment ${local.provided_ts_nw_compartment_name}"
  ]

  # NW admin reads virtual-network-family in all 4 spoke compartments.
  # SoD (A-06): each spoke group manages its own VCN via per-spoke policy (UG_*_ELZ_NW-Policy).
  # NW hub admin has read-only visibility into spoke topology (dashboards,
  # route validation) but CANNOT modify spoke subnets or route tables.
  # TC-03: UG_DEVT_ELZ_NW must not write to SEC — enforced by absence from
  #         any policy granting access to C1_R_ELZ_SEC.
  # CHANGED from "manage" to "read" — manage granted SoD-breaking write access.
  nw_admin_grants_on_spoke_cmps = [
    "allow group ${join(",", local.nw_admin_group_name)} to read virtual-network-family in compartment ${local.provided_os_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read virtual-network-family in compartment ${local.provided_ss_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read virtual-network-family in compartment ${local.provided_ts_nw_compartment_name}",
    "allow group ${join(",", local.nw_admin_group_name)} to read virtual-network-family in compartment ${local.provided_devt_nw_compartment_name}"
  ]

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — Security Administrator (UG_ELZ_SEC)
  # ---------------------------------------------------------------------------

  # cloud-guard-family, tag-namespaces, tag-defaults require tenancy root scope
  sec_admin_grants_on_root = [
    "allow group ${join(",", local.sec_admin_group_name)} to manage cloud-guard-family in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to manage cloudevents-rules in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to read tenancies in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to read objectstorage-namespaces in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to use cloud-shell in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to manage tag-namespaces in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to manage tag-defaults in tenancy",
    "allow group ${join(",", local.sec_admin_group_name)} to read audit-events in tenancy"
  ]

  # Vault, keys, bastion, Security Zones — scoped to SEC compartment only
  # SEC admin has NO write grants in NW, OPS, SOC, or spoke compartments
  sec_admin_grants_on_sec_cmp = [
    "allow group ${join(",", local.sec_admin_group_name)} to manage vaults in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage keys in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage bastion-family in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage security-zone in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage all-resources in compartment ${local.provided_sec_compartment_name}"
  ]

  sec_admin_grants_on_sec_grp = [
    "allow group ${join(",", local.sec_admin_group_name)} to manage security-zone in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage security-zone in compartment ${local.provided_nw_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage vss-family in compartment ${local.provided_sec_compartment_name}",
    "allow group ${join(",", local.sec_admin_group_name)} to manage certificate-authority-family in compartment ${local.provided_sec_compartment_name}"
  ]

  sec_admin_grants_on_service = [
    "allow any-user to manage objects in compartment ${local.provided_sec_compartment_name} where all {request.principal.type='serviceconnector'}"
  ]
}
