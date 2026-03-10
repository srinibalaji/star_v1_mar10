# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM GROUPS — TEAM 3 OWNED FILE
# Team 3 domain: Common Shared Services
# Sprint 1, Week 2 | SPRINT1-ISSUE-#8
# Branch: sprint1/iam-groups-team3
# =============================================================================
#
# GROUPS IN THIS FILE (2 of 10 TF-managed):
#   5. UG_ELZ_CSVCS      — Common Services Administrators
#   6. UG_DEVT_CSVCS — Development Common Services Administrators
#
# Team 3 also owns: mon_tags.tf (tag namespace C0-star-elz-v1 + CIS tag defaults)
# =============================================================================

locals {
  team3_groups = {

    # -------------------------------------------------------------------------
    # UG_ELZ_CSVCS — Common Shared Services Administrators
    # -------------------------------------------------------------------------
    (local.csvcs_admin_group_key) : {
      name : local.provided_csvcs_admin_group_name,
      description : "${local.lz_description} — Common Services Administrators. APM, File Transfer, Data Exchange, ServiceNow, Jira.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_DEVT_CSVCS — Development Common Services Administrators
    # -------------------------------------------------------------------------
    (local.devt_csvcs_admin_group_key) : {
      name : local.provided_devt_csvcs_admin_group_name,
      description : "${local.lz_description} — Dev Common Services Administrators. Development toolchain and non-production shared services.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    }
  }
}
