# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM COMPARTMENTS — TEAM 4 OWNED FILE
# Team 4 domain: Agency Spoke Networks
# Sprint 1, Week 1 | SPRINT1-ISSUE-#4
# Branch: sprint1/iam-compartments-team4
# =============================================================================
#
# COMPARTMENTS IN THIS FILE (4 of 10 TF-managed):
#   7.  C1_OS_ELZ_NW   — Operational Systems spoke: VCN, subnets, NSGs
#   8.  C1_SS_ELZ_NW   — Shared Services spoke: VCN, subnets, NSGs
#   9.  C1_TS_ELZ_NW   — Trusted Services spoke: VCN, subnets, NSGs
#   10. C1_DEVT_ELZ_NW — Development/Test spoke: VCN, subnets, NSGs
#
# TEAM 4 ALSO OWNS (OCI Console — NOT Terraform) | SPRINT1-ISSUE-#5:
#   C1_SIM_EXT   — Manual creation. OCID → var.sim_ext_compartment_id
#   C1_SIM_CHILD — Manual creation. OCID → var.sim_child_compartment_id
#   UG_SIM_EXT         — Manual group creation (Sprint 1 Day 1)
#   UG_SIM_CHILD       — Manual group creation (Sprint 1 Day 1)
#   TC-01b: Validate 2 manual compartments + OCIDs in tfvars (SPRINT1-ISSUE-#18)
#
# C2 SUB-COMPARTMENTS (FUTURE — disabled by default):
#   Example for OS spoke — add app and DB sub-compartments:
#     children : {
#       "OS-APP-CMP" : {
#         name        : var.c2_os_app_name   # default: "C2_OS_APP"
#         description : "OS app tier sub-compartment"
#       }
#     }
#   Enable via: enable_c2_compartments = true in ORM UI (Section 3).
# =============================================================================

locals {
  team4_compartments = {

    # -------------------------------------------------------------------------
    # OS-NW — Operational Systems Spoke  [C1_OS_ELZ_NW]
    # Contains: OS VCN (10.1.0.0/24), subnets, route tables, NSGs, OS workload
    # Group:    UG_OS_ELZ_NW
    # Policies: per-spoke policy (manage all-resources in this compartment only)
    # SoD:      UG_OS_ELZ_NW has NO access to SEC, NW hub, OPS, or other spokes
    # C2 hook:  children : {} — populate to add C2_OS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.os_nw_compartment_key) : {
      name : local.provided_os_nw_compartment_name,
      description : "${local.lz_description} — Operational Systems spoke. VCN, subnets, NSGs, workload instances.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {}
    },

    # -------------------------------------------------------------------------
    # SS-NW — Shared Services Spoke  [C1_SS_ELZ_NW]
    # Contains: SS VCN (10.2.0.0/24), subnets, route tables, NSGs, SS workload
    # Group:    UG_SS_ELZ_NW
    # Policies: per-spoke policy (manage all-resources in this compartment only)
    # C2 hook:  children : {} — populate to add C2_SS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.ss_nw_compartment_key) : {
      name : local.provided_ss_nw_compartment_name,
      description : "${local.lz_description} — Shared Services spoke. VCN, subnets, NSGs, workload instances.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {}
    },

    # -------------------------------------------------------------------------
    # TS-NW — Trusted Services Spoke  [C1_TS_ELZ_NW]
    # Contains: TS VCN (10.3.0.0/24), subnets, route tables, NSGs, TS workload
    # Group:    UG_TS_ELZ_NW
    # Policies: per-spoke policy (manage all-resources in this compartment only)
    # C2 hook:  children : {} — populate to add C2_TS_* sub-compartments
    # -------------------------------------------------------------------------
    (local.ts_nw_compartment_key) : {
      name : local.provided_ts_nw_compartment_name,
      description : "${local.lz_description} — Trusted Services spoke. VCN, subnets, NSGs, workload instances.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {}
    },

    # -------------------------------------------------------------------------
    # DEVT-NW — Development/Test Spoke  [C1_DEVT_ELZ_NW]
    # Contains: DEVT VCN (10.4.0.0/24), subnets, route tables, NSGs
    #           Network-only in V1 — no compute instance deployed here
    # Group:    UG_DEVT_ELZ_NW
    # Policies: per-spoke policy (manage all-resources in this compartment only)
    # TC-03:    DEVT group must NOT be able to write to SEC compartment.
    #           Enforced by absence of SEC from per-spoke policy statements.
    # C2 hook:  children : {} — populate to add C2_DEVT_* sub-compartments
    # -------------------------------------------------------------------------
    (local.devt_nw_compartment_key) : {
      name : local.provided_devt_nw_compartment_name,
      description : "${local.lz_description} — Development/Test spoke. VCN, subnets, NSGs. Network-only in V1.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : merge(local.cmps_freeform_tags, { "lz-tier" = "development" }),
      children : {}
    }
  }
}
