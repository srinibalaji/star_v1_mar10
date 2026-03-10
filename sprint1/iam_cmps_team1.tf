# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# IAM COMPARTMENTS — TEAM 1 OWNED FILE
# Team 1 domain: Hub Network + Security
# Sprint 1, Week 1 | SPRINT1-ISSUE-#1
# Branch: sprint1/iam-compartments-team1
# =============================================================================
#
# COMPARTMENTS IN THIS FILE (2 of 10 TF-managed):
#   1. C1_R_ELZ_NW  — Root hub network: DRGs, Hub VCN, route tables, Sim FW, Bastion
#   2. C1_R_ELZ_SEC — Security services: Vault, Cloud Guard, Security Zones
#
# HOW THIS FITS:
#   Defines local.team1_compartments — merged in iam_compartments.tf with
#   team2, team3, team4 maps before passing to lz_compartments module.
#   Each team owns their map. Zero key conflicts between teams.
#
# NAMES: local.provided_nw_compartment_name → "C1_R_ELZ_NW"
#         local.provided_sec_compartment_name → "C1_R_ELZ_SEC"
#   Canonical constants from locals.tf. Override via ORM UI (Section 2)
#   or variables_iam.tf custom_nw_compartment_name only if STAR name changes.
#
# C2 SUB-COMPARTMENTS (FUTURE — disabled by default):
#   To add Level 2 compartments under NW or SEC, populate children : {} below.
#   Enable via: enable_c2_compartments = true in ORM UI (Section 3).
#   Example for NW:
#     children : {
#       "NW-MGMT-CMP" : {
#         name        : "C2_NW_MGMT"
#         description : "NW management plane sub-compartment"
#       }
#     }
#
# SPRINT1-FIX (SPRINT1-ISSUE-#1, naming-drift):
#   description now uses local.lz_description instead of var.lz_provenant_label.
#   Removes a variable that served only as a description prefix.
# =============================================================================

locals {
  team1_compartments = {

    # -------------------------------------------------------------------------
    # NW — Root Hub Network Compartment  [C1_R_ELZ_NW]
    # Contains: drg_r_hub, drg_r_ew_hub, Hub VCN, all subnets, Sim FW, Bastion
    # Group:    UG_ELZ_NW
    # Policies: UG_ELZ_NW-Policy (manage virtual-network-family, drgs)
    # C2 hook:  children : {} — populate to add C2_NW_* sub-compartments
    # -------------------------------------------------------------------------
    (local.nw_compartment_key) : {
      name : local.provided_nw_compartment_name,
      description : "${local.lz_description} — Hub network compartment. DRGs, Hub VCN, route tables, Sim FW, Bastion.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {} # C2 hook — see header for expansion pattern
    },

    # -------------------------------------------------------------------------
    # SEC — Security Services Compartment  [C1_R_ELZ_SEC]
    # Contains: Vault, Cloud Guard target, Security Zones
    # Group:    UG_ELZ_SEC
    # Policies: UG_ELZ_SEC-Policy (manage vaults, keys, bastion-family, security-zone)
    # C2 hook:  children : {} — populate to add C2_SEC_* sub-compartments
    # -------------------------------------------------------------------------
    (local.sec_compartment_key) : {
      name : local.provided_sec_compartment_name,
      description : "${local.lz_description} — Security compartment. Vault, Cloud Guard, Security Zones.",
      defined_tags : local.cmps_defined_tags,
      freeform_tags : local.cmps_freeform_tags,
      children : {} # C2 hook — see header for expansion pattern
    }
  }
}
