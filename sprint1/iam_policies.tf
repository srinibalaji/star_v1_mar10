# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM POLICIES — MODULE ORCHESTRATOR
# This file orchestrates the lz_policies module.
# It does NOT define policy objects or statements — each team owns their file.
#
# TEAM FILES:
#   iam_policies_team1.tf — Team 1: UG_ELZ_NW-Policy, UG_ELZ_SEC-Policy  (2 objs)
#   iam_policies_team2.tf — Team 2: UG_ELZ_SOC-Policy, UG_ELZ_OPS-Policy (2 objs)
#   iam_policies_team3.tf — Team 3: UG_ELZ_CSVCS-Policy, UG_DEVT_CSVCS-Policy, OCI-SERVICES-Policy (3 objs)
#   iam_policies_team4.tf — Team 4: UG_OS/SS/TS/DEVT_ELZ_NW-Policy           (4 objs)
#   Total: 11 policy objects
#   Note: SIM policies (UG_SIM_EXT-Policy, UG_SIM_CHILD-Policy) are Sprint 4 scope.
#
# POLICY NAME CONVENTION:
#   <GROUP_NAME>-Policy      e.g. UG_ELZ_NW-Policy, UG_OS_ELZ_NW-Policy
#   OCI-SERVICES-Policy      (service principals, no group)
#
# ALL POLICIES LIVE AT TENANCY ROOT (C0):
#   compartment_id = local.tenancy_id  in every policy object.
#   No -Root or -Admin suffix needed — scope is indicated by statement verb,
#   not by policy name.
#
# SPRINT1-FIX (policy-naming):
#   Policy names changed from "${var.service_label}-nw-admin-root-policy"
#   (lowercase, 4-hop interpolation) to local.nw_policy_name = "UG_ELZ_NW-Policy"
#   (uppercase constant derived from group name in locals.tf). Consistent with
#   STAR ELZ naming standard and OCI console display requirements.
#
# SPRINT1-FIX (all-teams-active):
#   All 4 team policy blocks uncommented. Sprint 1 scaffold had all commented
#   out which prevented any policies from being created (SPRINT1-ISSUE-#10-13).
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # TAG MERGING
  # ---------------------------------------------------------------------------
  custom_policies_defined_tags  = null # Override in _override.tf if needed
  custom_policies_freeform_tags = null # Override in _override.tf if needed

  default_policies_defined_tags  = local.lz_defined_tags
  default_policies_freeform_tags = local.landing_zone_tags

  policies_defined_tags  = local.custom_policies_defined_tags != null ? merge(local.custom_policies_defined_tags, local.default_policies_defined_tags) : local.default_policies_defined_tags
  policies_freeform_tags = local.custom_policies_freeform_tags != null ? merge(local.custom_policies_freeform_tags, local.default_policies_freeform_tags) : local.default_policies_freeform_tags

  # ---------------------------------------------------------------------------
  # POLICIES CONFIGURATION — all 4 team maps merged
  # enable_cis_benchmark_checks: lz_policies module validates statements against
  # known CIS anti-patterns (e.g. overly broad allow any-user to manage).
  # ---------------------------------------------------------------------------
  policies_configuration = {
    enable_cis_benchmark_checks : true
    defined_tags : local.policies_defined_tags
    freeform_tags : local.policies_freeform_tags

    supplied_policies : merge(
      local.team1_policies, # UG_ELZ_NW-Policy, UG_ELZ_SEC-Policy
      local.team2_policies, # UG_ELZ_SOC-Policy, UG_ELZ_OPS-Policy
      local.team3_policies, # UG_ELZ_CSVCS-Policy, OCI-SERVICES-Policy
      local.team4_policies  # UG_OS/SS/TS/DEVT_ELZ_NW-Policy (4 per-spoke policies)
    )
  }
}

module "lz_policies" {
  source                 = "github.com/oci-landing-zones/terraform-oci-modules-iam//policies?ref=v0.3.1"
  providers              = { oci = oci.home }
  tenancy_ocid           = local.tenancy_id
  policies_configuration = local.policies_configuration
  # Policies reference compartment names and group names — both must exist first
  depends_on = [module.lz_compartments, module.lz_groups]
}
