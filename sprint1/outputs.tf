# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# OUTPUTS — SPRINT 1 → SPRINT 2 HANDOFF
#
# After apply, run:
#   terraform output -json > sprint1_outputs.json
#
# Sprint 2 lead pastes these OCIDs into sprint2/terraform.tfvars:
#   nw_compartment_id, sec_compartment_id, soc_compartment_id, ops_compartment_id,
#   csvcs_compartment_id, devt_csvcs_compartment_id,
#   os_nw_compartment_id, ss_nw_compartment_id, ts_nw_compartment_id, devt_nw_compartment_id
#
# TC-01 validation: Count must = 10 TF-managed compartments.
# TC-01b validation: sim_ext_compartment_id and sim_child_compartment_id not empty.
# TC-05 validation: tag_namespace_id is not empty.
# =============================================================================

# ---------------------------------------------------------------------------
# C1 COMPARTMENT OCIDs — 10 TF-managed compartments
# ---------------------------------------------------------------------------
output "nw_compartment_id" {
  description = "OCID of C1_R_ELZ_NW — Hub network compartment"
  value       = local.nw_compartment_id
}

output "sec_compartment_id" {
  description = "OCID of C1_R_ELZ_SEC — Security compartment"
  value       = local.sec_compartment_id
}

output "soc_compartment_id" {
  description = "OCID of C1_R_ELZ_SOC — SOC compartment"
  value       = local.soc_compartment_id
}

output "ops_compartment_id" {
  description = "OCID of C1_R_ELZ_OPS — Operations compartment"
  value       = local.ops_compartment_id
}

output "csvcs_compartment_id" {
  description = "OCID of C1_R_ELZ_CSVCS — Common shared services compartment"
  value       = local.csvcs_compartment_id
}

output "devt_csvcs_compartment_id" {
  description = "OCID of C1_R_ELZ_DEVT_CSVCS — Dev common services compartment"
  value       = local.devt_csvcs_compartment_id
}

output "os_nw_compartment_id" {
  description = "OCID of C1_OS_ELZ_NW — Operational Systems spoke compartment"
  value       = local.os_nw_compartment_id
}

output "ss_nw_compartment_id" {
  description = "OCID of C1_SS_ELZ_NW — Shared Services spoke compartment"
  value       = local.ss_nw_compartment_id
}

output "ts_nw_compartment_id" {
  description = "OCID of C1_TS_ELZ_NW — Trusted Services spoke compartment"
  value       = local.ts_nw_compartment_id
}

output "devt_nw_compartment_id" {
  description = "OCID of C1_DEVT_ELZ_NW — Development/Test spoke compartment"
  value       = local.devt_nw_compartment_id
}

# ---------------------------------------------------------------------------
# ENCLOSING COMPARTMENT OCID (only populated when enable_enclosing_compartment = true)
# ---------------------------------------------------------------------------
output "enclosing_compartment_id" {
  description = "OCID of enclosing parent compartment (null when enable_enclosing_compartment = false)"
  value       = var.enable_enclosing_compartment ? oci_identity_compartment.enclosing[0].id : null
}

output "parent_compartment_id" {
  description = "Effective parent for all C1 compartments — tenancy root or enclosing compartment"
  value       = local.parent_compartment_id
}

# ---------------------------------------------------------------------------
# MANUAL COMPARTMENT OCIDs (from tfvars — Team 4 Console-created)
# ---------------------------------------------------------------------------
output "sim_ext_compartment_id" {
  description = "OCID of C1_SIM_EXT (manual — Team 4 Sprint 1 Day 1)"
  value       = local.sim_ext_compartment_id
}

output "sim_child_compartment_id" {
  description = "OCID of C1_SIM_CHILD (manual — Team 4 Sprint 1 Day 1)"
  value       = local.sim_child_compartment_id
}

# ---------------------------------------------------------------------------
# GROUP NAMES — for policy and documentation validation
# ---------------------------------------------------------------------------
output "group_names" {
  description = "All 10 TF-managed group names"
  value = {
    nw         = local.provided_nw_admin_group_name
    sec        = local.provided_sec_admin_group_name
    soc        = local.provided_soc_group_name
    ops        = local.provided_ops_admin_group_name
    csvcs      = local.provided_csvcs_admin_group_name
    devt_csvcs = local.provided_devt_csvcs_admin_group_name
    os_nw      = local.provided_os_nw_admin_group_name
    ss_nw      = local.provided_ss_nw_admin_group_name
    ts_nw      = local.provided_ts_nw_admin_group_name
    devt_nw    = local.provided_devt_nw_admin_group_name
  }
}

# ---------------------------------------------------------------------------
# TAG NAMESPACE — TC-05 validation
# ---------------------------------------------------------------------------
output "tag_namespace_id" {
  description = "OCID of C0-star-elz-v1 tag namespace — TC-05: must not be empty"
  value       = oci_identity_tag_namespace.elz_v1.id
}

output "tag_namespace_name" {
  description = "Name of the landing zone tag namespace"
  value       = oci_identity_tag_namespace.elz_v1.name
}

# ---------------------------------------------------------------------------
# TENANCY INFO — informational
# ---------------------------------------------------------------------------
output "home_region" {
  description = "OCI home region name — IAM resources are deployed here"
  value       = local.regions_map[local.home_region_key]
}

output "tenancy_id" {
  description = "Tenancy OCID — used as root compartment in Sprint 2+"
  value       = local.tenancy_id
}
