# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM COMPARTMENTS — TEAM 2 OWNED FILE
# Team 2 domain: SOC + Operations
# Sprint 1, Week 1 | SPRINT1-ISSUE-#2
# Branch: sprint1/iam-compartments-team2
# =============================================================================
#
# COMPARTMENTS IN THIS FILE (2 of 10 TF-managed):
#   3. C1_R_ELZ_SOC — SOC operations: monitoring, audit log review, incident response
#   4. C1_R_ELZ_OPS — Operations: logging, alarms, monitoring, deployment pipeline
#
# C2 SUB-COMPARTMENTS (FUTURE — disabled by default):
#   Example for SOC — add log archive sub-compartment:
#     children : {
#       "SOC-LOGS-CMP" : {
#         name        : var.c2_soc_logs_name   # default: "C2_SOC_LOGS"
#         description : "SOC log archive sub-compartment"
#       }
#     }
#   Enable via: enable_c2_compartments = true in ORM UI (Section 3).
# =============================================================================

locals {
  team2_compartments = {

    # -------------------------------------------------------------------------
    # SOC — Security Operations Centre  [C1_R_ELZ_SOC]
    # Contains: SIEM analytics, log review tooling, incident response resources
    # Group:    UG_ELZ_SOC
    # Policies: UG_ELZ_SOC-Policy (read-only tenancy grants — cloud-guard, audit, all-resources)
    # TC-04:    SOC group must NOT be able to manage/delete any resource (negative test)
    # C2 hook:  children : {} — populate to add C2_SOC_* sub-compartments
    # -------------------------------------------------------------------------
    (local.soc_compartment_key) : {
      name : local.provided_soc_compartment_name,
      description : "${local.lz_description} — SOC compartment. Read-only monitoring, log review, incident response.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {} # C2 hook — see header for expansion pattern
    },

    # -------------------------------------------------------------------------
    # OPS — Operations Compartment  [C1_R_ELZ_OPS]
    # Contains: VCN Flow Log groups (all 5 VCNs), Service Connector Hub,
    #           bkt_elz_central_logs, Deployment Pipeline, Linux instances
    # Group:    UG_ELZ_OPS
    # Policies: UG_ELZ_OPS-Policy (manage logging-family, ons, alarms, metrics, object-family)
    # C2 hook:  children : {} — populate to add C2_OPS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.ops_compartment_key) : {
      name : local.provided_ops_compartment_name,
      description : "${local.lz_description} — Operations compartment. Logging, monitoring, alarms, deployment pipeline.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {} # C2 hook — see header for expansion pattern
    }
  }
}
