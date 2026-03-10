# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM GROUPS — MODULE ORCHESTRATOR
# This file orchestrates the lz_groups module.
# It does NOT define individual groups — each team owns their file.
#
# TEAM FILES:
#   iam_groups_team1.tf — Team 1: UG_ELZ_NW, UG_ELZ_SEC             (2 groups)
#   iam_groups_team2.tf — Team 2: UG_ELZ_SOC, UG_ELZ_OPS            (2 groups)
#   iam_groups_team3.tf — Team 3: UG_ELZ_CSVCS, UG_DEVT_CSVCS   (2 groups)
#   iam_groups_team4.tf — Team 4: UG_OS_ELZ_NW, UG_SS_ELZ_NW,
#                                  UG_TS_ELZ_NW, UG_DEVT_ELZ_NW      (4 groups)
#   Total TF-managed: 10 groups
#
# MANUAL GROUPS (2) — Team 4, OCI Console, Sprint 1 Day 1:
#   UG_SIM_EXT   — TEMP V1 ONLY (simulated external agency users)
#   UG_SIM_CHILD — TEMP V1 ONLY (simulated child tenancy users)
#   Record OCIDs in State Book: V1_Manual_Resources tab
#
# GROUP NAME CONVENTION:
#   UG_ELZ_<FUNCTION>          — root hub groups (NW, SEC, SOC, OPS, CSVCS)
#   UG_<AGENCY>_ELZ_<FUNCTION> — spoke groups (OS, SS, TS, DEVT)
#   All uppercase. No service_label prefix — groups are tenancy-wide singletons.
#
# SPRINT1-FIX (empty-collection-crash):
#   Group name output locals changed from module output lookup:
#     [module.lz_groups.groups[local.nw_admin_group_key].name]
#   to direct string references from locals.tf constants:
#     [local.nw_group_name]
#   This prevents plan failure when any team's group map is empty {} during
#   workshop incremental apply. Constants are the source of truth regardless
#   of module state. Module output and constants will always match because
#   provided_* locals in iam_groups_team*.tf reference the same constants.
#
# SPRINT1-FIX (naming-drift):
#   provided_* group names now reference local.nw_group_name etc from locals.tf
#   constants block. Replaced "${var.service_label}-ug-elz-nw" interpolation
#   which produced lowercase hyphenated names inconsistent with STAR standard.
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # TAG MERGING — override pattern (same as all other orchestrators)
  # ---------------------------------------------------------------------------
  custom_groups_defined_tags  = null # Override in _override.tf if needed
  custom_groups_freeform_tags = null # Override in _override.tf if needed

  default_groups_defined_tags  = local.lz_defined_tags
  default_groups_freeform_tags = local.landing_zone_tags

  groups_defined_tags  = local.custom_groups_defined_tags != null ? merge(local.custom_groups_defined_tags, local.default_groups_defined_tags) : local.default_groups_defined_tags
  groups_freeform_tags = local.custom_groups_freeform_tags != null ? merge(local.custom_groups_freeform_tags, local.default_groups_freeform_tags) : local.default_groups_freeform_tags

  # ---------------------------------------------------------------------------
  # GROUP MAP KEYS — Terraform-internal, not visible in OCI Console
  # Do NOT change after first apply — causes group destroy/recreate.
  # ---------------------------------------------------------------------------
  nw_admin_group_key         = "NW-ADMIN-GROUP"
  sec_admin_group_key        = "SEC-ADMIN-GROUP"
  soc_group_key              = "SOC-GROUP"
  ops_admin_group_key        = "OPS-ADMIN-GROUP"
  csvcs_admin_group_key      = "CSVCS-ADMIN-GROUP"
  devt_csvcs_admin_group_key = "DEVT-CSVCS-ADMIN-GROUP"
  os_nw_admin_group_key      = "OS-NW-ADMIN-GROUP"
  ss_nw_admin_group_key      = "SS-NW-ADMIN-GROUP"
  ts_nw_admin_group_key      = "TS-NW-ADMIN-GROUP"
  devt_nw_admin_group_key    = "DEVT-NW-ADMIN-GROUP"

  # ---------------------------------------------------------------------------
  # PROVIDED GROUP NAMES — canonical constants (from locals.tf) or custom override
  # These are the actual OCI group names used in policy statements.
  # Override only if STAR names must change — default to canonical constants.
  # ---------------------------------------------------------------------------
  provided_nw_admin_group_name         = local.nw_group_name
  provided_sec_admin_group_name        = local.sec_group_name
  provided_soc_group_name              = local.soc_group_name_const
  provided_ops_admin_group_name        = local.ops_group_name
  provided_csvcs_admin_group_name      = local.csvcs_group_name
  provided_devt_csvcs_admin_group_name = local.devt_csvcs_group_name
  provided_os_nw_admin_group_name      = local.os_nw_group_name
  provided_ss_nw_admin_group_name      = local.ss_nw_group_name
  provided_ts_nw_admin_group_name      = local.ts_nw_group_name
  provided_devt_nw_admin_group_name    = local.devt_nw_group_name

  # ---------------------------------------------------------------------------
  # GROUPS CONFIGURATION — input to lz_groups module
  # ---------------------------------------------------------------------------
  groups_configuration = {
    default_defined_tags : local.groups_defined_tags
    default_freeform_tags : local.groups_freeform_tags

    groups : merge(
      local.team1_groups, # UG_ELZ_NW, UG_ELZ_SEC
      local.team2_groups, # UG_ELZ_SOC, UG_ELZ_OPS
      local.team3_groups, # UG_ELZ_CSVCS, UG_DEVT_CSVCS
      local.team4_groups  # UG_OS_ELZ_NW, UG_SS_ELZ_NW, UG_TS_ELZ_NW, UG_DEVT_ELZ_NW
    )
  }

  # ---------------------------------------------------------------------------
  # GROUP NAME LISTS — used in policy statement strings via join(",", local.*)
  # Direct string references — no module output lookup.
  # These match provided_* above exactly. If you override provided_*, update here too.
  # SPRINT1-FIX: replaces [module.lz_groups.groups[local.key].name] lookups
  #              which crashed when team group map was {} during incremental apply.
  # ---------------------------------------------------------------------------
  nw_admin_group_name         = [local.provided_nw_admin_group_name]
  sec_admin_group_name        = [local.provided_sec_admin_group_name]
  soc_group_name              = [local.provided_soc_group_name]
  ops_admin_group_name        = [local.provided_ops_admin_group_name]
  csvcs_admin_group_name      = [local.provided_csvcs_admin_group_name]
  devt_csvcs_admin_group_name = [local.provided_devt_csvcs_admin_group_name]
  os_nw_admin_group_name      = [local.provided_os_nw_admin_group_name]
  ss_nw_admin_group_name      = [local.provided_ss_nw_admin_group_name]
  ts_nw_admin_group_name      = [local.provided_ts_nw_admin_group_name]
  devt_nw_admin_group_name    = [local.provided_devt_nw_admin_group_name]
}

module "lz_groups" {
  source               = "github.com/oci-landing-zones/terraform-oci-modules-iam//groups?ref=v0.3.1"
  providers            = { oci = oci.home }
  tenancy_ocid         = local.tenancy_id
  groups_configuration = local.groups_configuration
}
