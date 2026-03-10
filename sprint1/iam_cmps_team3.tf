# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM COMPARTMENTS — TEAM 3 OWNED FILE
# Team 3 domain: Common Shared Services + Governance
# Sprint 1, Week 1 | SPRINT1-ISSUE-#3
# Branch: sprint1/iam-compartments-team3
# =============================================================================
#
# COMPARTMENTS IN THIS FILE (2 of 10 TF-managed):
#   5. C1_R_ELZ_CSVCS      — Common Shared Services: APM, File Transfer, ServiceNow, Jira
#   6. C1_R_ELZ_DEVT_CSVCS — Dev Common Services: development toolchain shared services
#
# Team 3 also owns: mon_tags.tf (tag namespace C0-star-elz-v1 + 5 tags)
# =============================================================================

locals {
  team3_compartments = {

    # -------------------------------------------------------------------------
    # CSVCS — Common Shared Services  [C1_R_ELZ_CSVCS]
    # Contains: Data Exchange, File Transfer, File Storage, APM, ServiceNow, Jira
    # Group:    UG_ELZ_CSVCS
    # Policies: UG_ELZ_CSVCS-Policy (manage all-resources in compartment)
    # C2 hook:  children : {} — populate to add C2_CSVCS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.csvcs_compartment_key) : {
      name : local.provided_csvcs_compartment_name,
      description : "${local.lz_description} — Common shared services. APM, File Transfer, Data Exchange, ServiceNow, Jira.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {}
    },

    # -------------------------------------------------------------------------
    # DEVT_CSVCS — Development Common Services  [C1_R_ELZ_DEVT_CSVCS]
    # Contains: development toolchain shared services (non-production tier)
    # Group:    UG_DEVT_CSVCS
    # Policies: UG_ELZ_CSVCS-Policy (manage all-resources in compartment)
    # TC-03:    UG_DEVT_ELZ_NW must NOT appear in any policy granting access
    #           to this compartment — enforced by its absence from per-spoke policies
    # C2 hook:  children : {} — populate to add C2_DEVT_CSVCS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.devt_csvcs_compartment_key) : {
      name : local.provided_devt_csvcs_compartment_name,
      description : "${local.lz_description} — Dev common services. Development toolchain and shared non-production services.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : merge(local.cmps_freeform_tags, { "lz-tier" = "development" }),
      children : {}
    }
  }
}
