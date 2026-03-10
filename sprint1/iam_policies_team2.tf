# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM POLICIES — TEAM 2 OWNED FILE
# Team 2 domain: SOC + Operations
# Sprint 1, Week 2 | SPRINT1-ISSUE-#12
# Branch: sprint1/iam-policies-team2
# =============================================================================
#
# POLICY OBJECTS IN THIS FILE (2 of 9):
#   3. UG_ELZ_SOC-Policy — SOC read-only grants across tenancy
#   4. UG_ELZ_OPS-Policy — Operations admin grants on OPS compartment
#
# TEST CASES VALIDATED BY THIS FILE:
#   TC-03 (SoD): DEVT group must NOT appear anywhere in this file.
#   TC-04 (SOC read-only): NEGATIVE test — member of UG_ELZ_SOC attempting
#     any write operation (e.g. oci logging log-group delete) must get HTTP 403.
#     Every statement for soc_group_name uses "read" verb only.
#     "use cloud-shell" is a UI convenience grant, not data plane access.
#
# SPRINT1-FIX (SPRINT1-ISSUE-#12, policy-naming + OCI-syntax):
#   name changed from "${var.service_label}-soc-policy" to local.soc_policy_name.
#   OCI policy resource-type syntax already correct in solutions (hyphenated):
#     cloud-guard-family, audit-events, all-resources, cloud-shell ✓
# =============================================================================

locals {
  team2_policies = {

    # -------------------------------------------------------------------------
    # UG_ELZ_SOC-Policy — SOC Analyst Policy (read-only)
    # Tenancy root: read cloud-guard-family, read audit-events, read all-resources.
    # CRITICAL TC-04: every verb for soc_group_name is "read".
    #   "use cloud-shell" is intentional — shells have no implicit write grants.
    # -------------------------------------------------------------------------
    "SOC-POLICY" : {
      name : local.soc_policy_name
      description : "${local.lz_description} — SOC Analyst policy. Read-only security monitoring, audit, incident response."
      compartment_id : local.tenancy_id
      statements : concat(
        local.soc_grants_on_root
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_ELZ_OPS-Policy — Operations Administrator Policy
    # OPS compartment: manage logging, monitoring, alarms, object-family (log buckets).
    # Tenancy root: read all-resources (service metrics, cross-cmp dashboards).
    # No grants in SEC, NW hub, or spoke compartments.
    # -------------------------------------------------------------------------
    "OPS-POLICY" : {
      name : local.ops_policy_name
      description : "${local.lz_description} — Operations Administrator policy. Logging, monitoring, alarms, deployment pipeline."
      compartment_id : local.tenancy_id
      statements : concat(
        local.ops_admin_grants_on_ops_cmp
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    }
  }

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — SOC Analyst (UG_ELZ_SOC)
  # All verbs are "read" — TC-04 compliance
  # ---------------------------------------------------------------------------
  soc_grants_on_root = [
    "allow group ${join(",", local.soc_group_name)} to read cloud-guard-family in tenancy",
    "allow group ${join(",", local.soc_group_name)} to read audit-events in tenancy",
    "allow group ${join(",", local.soc_group_name)} to read all-resources in tenancy",
    "allow group ${join(",", local.soc_group_name)} to use cloud-shell in tenancy"
  ]

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — Operations Administrator (UG_ELZ_OPS)
  # ---------------------------------------------------------------------------
  ops_admin_grants_on_ops_cmp = [
    "allow group ${join(",", local.ops_admin_group_name)} to manage logging-family in compartment ${local.provided_ops_compartment_name}",
    "allow group ${join(",", local.ops_admin_group_name)} to manage ons-family in compartment ${local.provided_ops_compartment_name}",
    "allow group ${join(",", local.ops_admin_group_name)} to manage alarms in compartment ${local.provided_ops_compartment_name}",
    "allow group ${join(",", local.ops_admin_group_name)} to manage metrics in compartment ${local.provided_ops_compartment_name}",
    "allow group ${join(",", local.ops_admin_group_name)} to manage object-family in compartment ${local.provided_ops_compartment_name}",
    "allow group ${join(",", local.ops_admin_group_name)} to read all-resources in tenancy"
  ]
}
