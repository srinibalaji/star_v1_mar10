# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# NETWORK ORCHESTRATOR  (nw_main.tf)
# Standardised filename: nw_main.tf — consistent with nw_teamX.tf convention.
# This file documents the overall network architecture and defines the shared
# tag merge locals used by all team files.
#
# It does NOT define VCN, subnet, or routing resources — each team owns theirs.
#
# TEAM FILES:
#   nw_team1.tf — T1: C1_OS_ELZ_NW   — OS spoke VCN, subnet, RT, Sim FW
#   nw_team2.tf — T2: C1_TS_ELZ_NW   — TS spoke VCN, subnet, RT, Sim FW
#   nw_team3.tf — T3: C1_SS_ELZ_NW + C1_DEVT_ELZ_NW — VCNs, subnets, RTs, Sim FW (SS only)
#   nw_team4.tf — T4: C1_R_ELZ_NW    — Hub VCN, FW+MGMT subnets, DRG, RTs, Sim FW, Bastion
#
# V1 ARCHITECTURE — Hub and Spoke via DRG (ISOLATED — no internet gateway):
#
#   C0 Tenancy Root
#   │
#   ├── C1_R_ELZ_NW (T4 — Hub)
#   │     VCN: 10.0.0.0/16   (Hub — kept /16 for Sprint 3+ subnet expansion)
#   │     ├── SUB-FW   10.0.0.0/24  — Sim FW (private, no public IP, skip_source_dest_check)
#   │     ├── SUB-MGMT 10.0.1.0/24  — Bastion (private)
#   │     └── DRG-HUB ──────────────── attached to Hub VCN + all 4 spoke VCNs (Phase 2)
#   │
#   ├── C1_OS_ELZ_NW (T1)     VCN: 10.1.0.0/24
#   │     └── SUB-APP  10.1.0.0/24  — Sim FW | RT: 0.0.0.0/0 → DRG
#   │
#   ├── C1_TS_ELZ_NW (T2)     VCN: 10.3.0.0/24
#   │     └── SUB-APP  10.3.0.0/24  — Sim FW | RT: 0.0.0.0/0 → DRG
#   │
#   ├── C1_SS_ELZ_NW (T3)     VCN: 10.2.0.0/24
#   │     └── SUB-APP  10.2.0.0/24  — Sim FW | RT: 0.0.0.0/0 → DRG
#   │
#   └── C1_DEVT_ELZ_NW (T3)   VCN: 10.4.0.0/24
#         └── SUB-APP  10.4.0.0/24  — network only (no Sim FW in V1)
#               RT: 0.0.0.0/0 → DRG
#
# SPRINT 3 BACKLOG (logged here for visibility — do NOT implement in sprint2):
#   1. DRG Transit Routing: OCI DRG v2 defaults to full-mesh. Spoke-to-spoke traffic
#      currently bypasses Hub Sim FW. Sprint 3 must add oci_core_drg_route_table
#      and oci_core_drg_route_distribution to force all traffic via Hub VCN attachment.
#
# TWO-PHASE APPLY:
#   Phase 1 (simultaneous): VCNs + subnets + T4's DRG
#   Phase 2 (after T4 outputs hub_drg_id): DRG attachments + route tables + Sim FW + Bastion
#
# IAM CARRY-FORWARD (READ ONLY):
#   Compartments, groups, tags from Sprint 1 referenced via variables_iam.tf only.
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # NETWORK RESOURCE TAG MERGE — consistent override pattern across all teams
  # Override custom_net_defined_tags or custom_net_freeform_tags in a local
  # _override.tf file if a specific environment needs different tags.
  # ---------------------------------------------------------------------------
  custom_net_defined_tags  = null
  custom_net_freeform_tags = null

  default_net_defined_tags  = local.lz_defined_tags
  default_net_freeform_tags = local.landing_zone_tags

  net_defined_tags  = local.custom_net_defined_tags != null ? merge(local.custom_net_defined_tags, local.default_net_defined_tags) : local.default_net_defined_tags
  net_freeform_tags = local.custom_net_freeform_tags != null ? merge(local.custom_net_freeform_tags, local.default_net_freeform_tags) : local.default_net_freeform_tags

  # ---------------------------------------------------------------------------
  # COMPUTE RESOURCE TAG MERGE — for Sim FW instances and Bastion
  # ---------------------------------------------------------------------------
  custom_cmp_defined_tags  = null
  custom_cmp_freeform_tags = null

  default_cmp_defined_tags  = merge(local.lz_defined_tags, { "${local.tag_namespace_name}.CostCenter" = "STAR-ELZ-SIMFW" })
  default_cmp_freeform_tags = merge(local.landing_zone_tags, { "resource-type" = "sim-firewall" })

  cmp_defined_tags  = local.custom_cmp_defined_tags != null ? merge(local.custom_cmp_defined_tags, local.default_cmp_defined_tags) : local.default_cmp_defined_tags
  cmp_freeform_tags = local.custom_cmp_freeform_tags != null ? merge(local.custom_cmp_freeform_tags, local.default_cmp_freeform_tags) : local.default_cmp_freeform_tags
}
