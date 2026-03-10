# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM COMPARTMENTS — MODULE ORCHESTRATOR
# This file orchestrates the lz_compartments module.
# It does NOT define individual compartments — each team owns their file.
#
# TEAM FILES:
#   iam_cmps_team1.tf  — Team 1:  C1_R_ELZ_NW, C1_R_ELZ_SEC       (2 cmps)
#   iam_cmps_team2.tf  — Team 2:  C1_R_ELZ_SOC, C1_R_ELZ_OPS      (2 cmps)
#   iam_cmps_team3.tf  — Team 3:  C1_R_ELZ_CSVCS, C1_R_ELZ_DEVT_CSVCS (2 cmps)
#   iam_cmps_team4.tf  — Team 4:  C1_OS_ELZ_NW, C1_SS_ELZ_NW,
#                                  C1_TS_ELZ_NW, C1_DEVT_ELZ_NW     (4 cmps)
#   Total TF-managed: 10 compartments at C1 level
#
# MANUAL COMPARTMENTS (2) — Team 4, OCI Console, Sprint 1 Day 1:
#   C1_SIM_EXT   — TEMP V1 ONLY (Simulated external agency, DNS Bridge)
#   C1_SIM_CHILD — TEMP V1 ONLY (Hello World workload)
#   Paste OCIDs into terraform.tfvars: sim_ext_compartment_id, sim_child_compartment_id
#
# HIERARCHY (default):
#   C0 Tenancy Root
#   └── C1_R_ELZ_NW, C1_R_ELZ_SEC, C1_R_ELZ_SOC ... (10 compartments)
#
# WITH ENCLOSING COMPARTMENT (enable_enclosing_compartment = true):
#   C0 Tenancy Root
#   └── AD_LZ_DEV  (enclosing — defined in iam_opt_in_enclosing.tf)
#       └── C1_R_ELZ_NW, C1_R_ELZ_SEC ... (10 compartments)
#
# C2 SUB-COMPARTMENTS (enable_c2_compartments = true):
#   Populate children : {} in the relevant team file.
#   Name pattern: C2_<AGENCY>_<FUNCTION>  e.g. C2_SOC_LOGS, C2_OS_APP
#   See variables_iam.tf Section: C2 LEVEL SUB-COMPARTMENTS for variables.
#
# SPRINT1-FIX (naming-drift):
#   provided_* locals now reference local.nw_compartment_name etc from locals.tf
#   constants block. Replaced coalesce(var.custom_*, "${var.service_label}-r-elz-nw-cmp")
#   which produced lowercase hyphenated names inconsistent with STAR standard.
#
# SPRINT1-FIX (enclosing-compartment):
#   Removed hard dependency on iam_enclosing_compartment.tf.
#   parent_compartment_id = local.tenancy_id by default (tenancy root).
#   Set enable_enclosing_compartment = true in ORM UI for test isolation.
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # TAG MERGING — same override pattern across all resource types
  # ---------------------------------------------------------------------------
  custom_cmps_defined_tags  = null # Override in _override.tf if needed
  custom_cmps_freeform_tags = null # Override in _override.tf if needed

  default_cmps_defined_tags  = local.lz_defined_tags
  default_cmps_freeform_tags = local.landing_zone_tags

  cmps_defined_tags  = local.custom_cmps_defined_tags != null ? merge(local.custom_cmps_defined_tags, local.default_cmps_defined_tags) : local.default_cmps_defined_tags
  cmps_freeform_tags = local.custom_cmps_freeform_tags != null ? merge(local.custom_cmps_freeform_tags, local.default_cmps_freeform_tags) : local.default_cmps_freeform_tags

  # ---------------------------------------------------------------------------
  # COMPARTMENT MAP KEYS — immutable identifiers used by all downstream modules
  # These keys are Terraform-internal only. OCI sees the name, not the key.
  # Do NOT change keys after first apply — it causes compartment destroy/recreate.
  # ---------------------------------------------------------------------------
  nw_compartment_key         = "NW-CMP"
  sec_compartment_key        = "SEC-CMP"
  soc_compartment_key        = "SOC-CMP"
  ops_compartment_key        = "OPS-CMP"
  csvcs_compartment_key      = "CSVCS-CMP"
  devt_csvcs_compartment_key = "DEVT-CSVCS-CMP"
  os_nw_compartment_key      = "OS-NW-CMP"
  ss_nw_compartment_key      = "SS-NW-CMP"
  ts_nw_compartment_key      = "TS-NW-CMP"
  devt_nw_compartment_key    = "DEVT-NW-CMP"

  # ---------------------------------------------------------------------------
  # COMPARTMENTS CONFIGURATION — input to lz_compartments module
  # parent_compartment_id = tenancy root OR enclosing compartment (opt-in)
  # ---------------------------------------------------------------------------
  compartments_configuration = {
    default_parent_id : local.parent_compartment_id
    enable_delete : local.enable_cmp_delete
    compartments : merge(
      local.team1_compartments, # C1_R_ELZ_NW, C1_R_ELZ_SEC
      local.team2_compartments, # C1_R_ELZ_SOC, C1_R_ELZ_OPS
      local.team3_compartments, # C1_R_ELZ_CSVCS, C1_R_ELZ_DEVT_CSVCS
      local.team4_compartments  # C1_OS_ELZ_NW, C1_SS_ELZ_NW, C1_TS_ELZ_NW, C1_DEVT_ELZ_NW
    )
  }

  # ---------------------------------------------------------------------------
  # COMPARTMENT IDs — from module output, used by all downstream resources
  # ---------------------------------------------------------------------------
  nw_compartment_id         = module.lz_compartments.compartments[local.nw_compartment_key].id
  sec_compartment_id        = module.lz_compartments.compartments[local.sec_compartment_key].id
  soc_compartment_id        = module.lz_compartments.compartments[local.soc_compartment_key].id
  ops_compartment_id        = module.lz_compartments.compartments[local.ops_compartment_key].id
  csvcs_compartment_id      = module.lz_compartments.compartments[local.csvcs_compartment_key].id
  devt_csvcs_compartment_id = module.lz_compartments.compartments[local.devt_csvcs_compartment_key].id
  os_nw_compartment_id      = module.lz_compartments.compartments[local.os_nw_compartment_key].id
  ss_nw_compartment_id      = module.lz_compartments.compartments[local.ss_nw_compartment_key].id
  ts_nw_compartment_id      = module.lz_compartments.compartments[local.ts_nw_compartment_key].id
  devt_nw_compartment_id    = module.lz_compartments.compartments[local.devt_nw_compartment_key].id

  # Manual compartment IDs — OCIDs pasted from OCI Console by Team 4
  sim_ext_compartment_id   = var.sim_ext_compartment_id
  sim_child_compartment_id = var.sim_child_compartment_id
}

module "lz_compartments" {
  source                     = "github.com/oci-landing-zones/terraform-oci-modules-iam//compartments?ref=v0.3.1"
  providers                  = { oci = oci.home }
  tenancy_ocid               = local.tenancy_id
  compartments_configuration = local.compartments_configuration
  depends_on                 = [oci_identity_compartment.enclosing,
                                oci_identity_tag_namespace.elz_v1]
}
