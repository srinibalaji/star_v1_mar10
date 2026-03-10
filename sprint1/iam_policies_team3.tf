# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM POLICIES — TEAM 3 OWNED FILE
# Team 3 domain: Common Shared Services + Governance
# Sprint 1, Week 2 | SPRINT1-ISSUE-#13
# Branch: sprint1/iam-policies-team3
# =============================================================================
#
# POLICY OBJECTS IN THIS FILE (3 of 11):
#   5. UG_ELZ_CSVCS-Policy  — CSVCS compartment grants (manage + tenancy read)
#   6. UG_DEVT_CSVCS-Policy — DEVT CSVCS compartment grants (manage + tenancy read)
#   7. OCI-SERVICES-Policy  — CIS required OCI service principal grants (no group)
#
# OCI-SERVICES-Policy NOTE:
#   Uses "allow service <name>" — no IAM group. Required for Cloud Guard,
#   Object Storage, and Vulnerability Scanning to function tenancy-wide.
#   Team 3 owns this because they own the governance/tagging layer (mon_tags.tf).
#   TC-05 and OCI-SERVICES-Policy together = Sprint 1 governance deliverable.
#
# SPRINT1-FIX (SPRINT1-ISSUE-#13, policy-naming):
#   name changed from "${var.service_label}-csvcs-policy" to local.csvcs_policy_name.
# =============================================================================

locals {
  team3_policies = {

    # -------------------------------------------------------------------------
    # UG_ELZ_CSVCS-Policy — Common Shared Services Policy
    # CSVCS cmp: manage all-resources (APM, File Transfer, ServiceNow, Jira).
    # Tenancy root: read all-resources for cross-compartment visibility.
    # -------------------------------------------------------------------------
    "CSVCS-POLICY" : {
      name : local.csvcs_policy_name
      description : "${local.lz_description} — Common Services policy. UG_ELZ_CSVCS manages C1_R_ELZ_CSVCS only."
      compartment_id : local.tenancy_id
      statements : concat(
        local.csvcs_admin_grants
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # UG_DEVT_CSVCS-Policy — Dev Common Shared Services Policy
    # DEVT_CSVCS cmp: manage all-resources (dev toolchain services).
    # Tenancy root: read all-resources for cross-compartment visibility.
    # -------------------------------------------------------------------------
    "DEVT-CSVCS-POLICY" : {
      name : local.devt_csvcs_policy_name
      description : "${local.lz_description} — Dev CSVCS policy. UG_DEVT_CSVCS manages C1_R_ELZ_DEVT_CSVCS only."
      compartment_id : local.tenancy_id
      statements : concat(
        local.devt_csvcs_admin_grants
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    },

    # -------------------------------------------------------------------------
    # OCI-SERVICES-Policy — CIS Benchmark Level 1 Service Principal Grants
    # Required for Cloud Guard, Object Storage replication, and VSS to operate.
    # "allow service <svc>" grants are tenancy-wide and use service principals.
    # Cloud Guard cannot inspect resources without these read grants.
    # -------------------------------------------------------------------------
    "OCI-SERVICES-POLICY" : {
      name : local.oci_services_policy_name
      description : "${local.lz_description} — CIS Level 1 required OCI service grants. Cloud Guard, Object Storage, VSS."
      compartment_id : local.tenancy_id
      statements : concat(
        local.oci_services_grants
      )
      defined_tags : local.policies_defined_tags
      freeform_tags : local.policies_freeform_tags
    }
  }

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — Common Services Administrator (UG_ELZ_CSVCS)
  # ---------------------------------------------------------------------------
  csvcs_admin_grants = [
    "allow group ${join(",", local.csvcs_admin_group_name)} to manage all-resources in compartment ${local.provided_csvcs_compartment_name}",
    "allow group ${join(",", local.csvcs_admin_group_name)} to read all-resources in tenancy"
  ]

  devt_csvcs_admin_grants = [
    "allow group ${join(",", local.devt_csvcs_admin_group_name)} to manage all-resources in compartment ${local.provided_devt_csvcs_compartment_name}",
    "allow group ${join(",", local.devt_csvcs_admin_group_name)} to read all-resources in tenancy"
  ]

  # ---------------------------------------------------------------------------
  # STATEMENT LISTS — OCI Service Principals (CIS Level 1 required)
  # Cloud Guard needs 14 read grants to inspect every resource type.
  # Object Storage needs manage object-family for cross-region replication.
  # VSS needs 4 grants to scan running instances for CVEs.
  # ---------------------------------------------------------------------------
  oci_services_grants = [
    "allow service cloudguard to read keys in tenancy",
    "allow service cloudguard to read compartments in tenancy",
    "allow service cloudguard to read tenancies in tenancy",
    "allow service cloudguard to read audit-events in tenancy",
    "allow service cloudguard to read compute-management-family in tenancy",
    "allow service cloudguard to read instance-family in tenancy",
    "allow service cloudguard to read virtual-network-family in tenancy",
    "allow service cloudguard to read volume-family in tenancy",
    "allow service cloudguard to read database-family in tenancy",
    "allow service cloudguard to read object-family in tenancy",
    "allow service cloudguard to read load-balancers in tenancy",
    "allow service cloudguard to read users in tenancy",
    "allow service cloudguard to read groups in tenancy",
    "allow service cloudguard to read policies in tenancy",
    "allow service objectstorage-${var.region} to manage object-family in tenancy",
    "allow service vulnerability-scanning-service to manage instances in tenancy",
    "allow service vulnerability-scanning-service to read compartments in tenancy",
    "allow service vulnerability-scanning-service to read vnics in tenancy",
    "allow service vulnerability-scanning-service to read vnic-attachments in tenancy"
  ]
}
