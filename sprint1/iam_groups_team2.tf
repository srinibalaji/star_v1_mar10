# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM GROUPS — TEAM 2 OWNED FILE
# Team 2 domain: SOC + Operations
# Sprint 1, Week 2 | SPRINT1-ISSUE-#7
# Branch: sprint1/iam-groups-team2
# =============================================================================
#
# GROUPS IN THIS FILE (2 of 10 TF-managed):
#   3. UG_ELZ_SOC — SOC Analysts (read-only across tenancy)
#      CRITICAL: TC-04 — must use ONLY read/inspect verbs in all policies
#   4. UG_ELZ_OPS — Operations Administrators
#      Scope: manage logging, monitoring, alarms in OPS cmp + read tenancy
#
# SPRINT1-FIX (SPRINT1-ISSUE-#7, naming-drift):
#   Group names now reference local.provided_*_group_name constants.
#   Replaced "${var.service_label}-ug-elz-soc" (lowercase, service_label-prefixed).
# =============================================================================

locals {
  team2_groups = {

    # -------------------------------------------------------------------------
    # UG_ELZ_SOC — Security Operations Centre Analysts
    # CRITICAL TC-04: read-only. Policy may NEVER use manage/use verbs.
    # -------------------------------------------------------------------------
    (local.soc_group_key) : {
      name : local.provided_soc_group_name,
      description : "${local.lz_description} — SOC Analysts. Read-only security monitoring, log review, incident response.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_ELZ_OPS — Operations Administrators
    # -------------------------------------------------------------------------
    (local.ops_admin_group_key) : {
      name : local.provided_ops_admin_group_name,
      description : "${local.lz_description} — Operations Administrators. Logging, monitoring, alarms, deployment pipeline.",
      defined_tags : local.groups_defined_tags,
      freeform_tags : local.groups_freeform_tags
    }
  }
}
