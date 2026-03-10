# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# NETWORK — TEAM 3 OWNED FILE
# Team 3 domain: Shared Services (SS) + Development (DEVT) Spokes
# Sprint 2 | Issues: S2-T3 (VCN+Subnet), S2-T3 (Route Table), S2-T3 (Sim FW)
# Branch: sprint2/nw-team3
# =============================================================================
#
# RESOURCES IN THIS FILE (2 VCNs — 2 compartments):
#   PHASE 1:
#     oci_core_vcn.ss                — SS spoke VCN    10.2.0.0/24
#     oci_core_route_table.ss_app    — RT (empty Phase 1, DRG rule added Phase 2)
#     oci_core_subnet.ss_app         — SS app subnet   10.2.0.0/24, private
#     oci_core_vcn.devt              — DEVT spoke VCN  10.4.0.0/24
#     oci_core_route_table.devt_app  — RT (empty Phase 1, DRG rule added Phase 2)
#     oci_core_subnet.devt_app       — DEVT app subnet 10.4.0.0/24, private
#
#   PHASE 2:
#     oci_core_drg_attachment.ss     — Attaches SS VCN to Hub DRG
#     oci_core_drg_attachment.devt   — Attaches DEVT VCN to Hub DRG
#     Route tables updated in-place with DRG rule
#     oci_core_instance.sim_fw_ss    — Sim FW (SS compartment ONLY — not DEVT)
#
# COMPARTMENTS:
#   SS:   C1_SS_ELZ_NW   — var.ss_compartment_id
#   DEVT: C1_DEVT_ELZ_NW — var.devt_compartment_id
#
# DEVT NOTE: No Sim FW in DEVT — network-only in V1. Compute workloads Sprint 4+.
# TC-03: UG_DEVT_ELZ_NW has no grants in C1_R_ELZ_SEC (enforced in sprint1 policies).
# =============================================================================

# =============================================================================
# PHASE 1 — SS VCN + ROUTE TABLE + SUBNET
# [S2-T3] VCN + Subnet for SS compartment
# =============================================================================

resource "oci_core_vcn" "ss" {
  compartment_id = var.ss_compartment_id
  cidr_blocks    = [local.ss_vcn_cidr]
  display_name   = local.ss_vcn_name
  dns_label      = local.ss_vcn_dns_label

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

# [S2-T3] Route Table for SS compartment
resource "oci_core_route_table" "ss_app" {
  compartment_id = var.ss_compartment_id
  vcn_id         = oci_core_vcn.ss.id
  display_name   = local.ss_app_rt_name

  dynamic "route_rules" {
    for_each = local.phase2_enabled ? [1] : []
    content {
      description       = "Default route to Hub DRG — all traffic via hub firewall"
      destination       = local.anywhere
      destination_type  = "CIDR_BLOCK"
      network_entity_id = var.hub_drg_id
    }
  }

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags

  depends_on = [oci_core_drg_attachment.ss]
}


resource "oci_core_subnet" "ss_app" {
  compartment_id             = var.ss_compartment_id
  vcn_id                     = oci_core_vcn.ss.id
  cidr_block                 = local.ss_app_subnet_cidr
  display_name               = local.ss_app_subnet_name
  dns_label                  = local.ss_app_subnet_dns_label
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.ss_app.id
  security_list_ids          = [oci_core_security_list.ss_app.id]

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

resource "oci_core_security_list" "ss_app" {
  compartment_id = var.ss_compartment_id
  vcn_id         = oci_core_vcn.ss.id
  display_name   = local.ss_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

# =============================================================================
# PHASE 1 — DEVT VCN + ROUTE TABLE + SUBNET
# [S2-T3] VCN + Subnet for DEVT compartment
# =============================================================================

resource "oci_core_vcn" "devt" {
  compartment_id = var.devt_compartment_id
  cidr_blocks    = [local.devt_vcn_cidr]
  display_name   = local.devt_vcn_name
  dns_label      = local.devt_vcn_dns_label

  freeform_tags = merge(local.net_freeform_tags, { "lz-tier" = "development" })
  defined_tags  = local.net_defined_tags
}

# [S2-T3] Route Table for DEVT compartment
resource "oci_core_route_table" "devt_app" {
  compartment_id = var.devt_compartment_id
  vcn_id         = oci_core_vcn.devt.id
  display_name   = local.devt_app_rt_name

  dynamic "route_rules" {
    for_each = local.phase2_enabled ? [1] : []
    content {
      description       = "Default route to Hub DRG — all traffic via hub firewall"
      destination       = local.anywhere
      destination_type  = "CIDR_BLOCK"
      network_entity_id = var.hub_drg_id
    }
  }

  freeform_tags = merge(local.net_freeform_tags, { "lz-tier" = "development" })
  defined_tags  = local.net_defined_tags

  depends_on = [oci_core_drg_attachment.devt]
}


resource "oci_core_subnet" "devt_app" {
  compartment_id             = var.devt_compartment_id
  vcn_id                     = oci_core_vcn.devt.id
  cidr_block                 = local.devt_app_subnet_cidr
  display_name               = local.devt_app_subnet_name
  dns_label                  = local.devt_app_subnet_dns_label
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.devt_app.id
  security_list_ids          = [oci_core_security_list.devt_app.id]

  freeform_tags = merge(local.net_freeform_tags, { "lz-tier" = "development" })
  defined_tags  = local.net_defined_tags
}

resource "oci_core_security_list" "devt_app" {
  compartment_id = var.devt_compartment_id
  vcn_id         = oci_core_vcn.devt.id
  display_name   = local.devt_app_seclist_name

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/8"
    stateless = false
  }

  freeform_tags = merge(local.net_freeform_tags, { "lz-tier" = "development" })
  defined_tags  = local.net_defined_tags
}

# =============================================================================
# PHASE 2 — SS DRG ATTACHMENT + SIM FW
# =============================================================================

resource "oci_core_drg_attachment" "ss" {
  count        = local.phase2_enabled ? 1 : 0
  drg_id       = var.hub_drg_id
  display_name = local.ss_drg_attachment_name

  network_details {
    id   = oci_core_vcn.ss.id
    type = "VCN"
  }
}

# [S2-T3] Sim Firewall for SS compartment (SS only — not DEVT)
resource "oci_core_instance" "sim_fw_ss" {
  count               = local.phase2_enabled ? 1 : 0
  compartment_id      = var.ss_compartment_id
  availability_domain = local.ad_name
  display_name        = local.ss_fw_instance_name
  shape               = var.sim_fw_shape

  shape_config {
    ocpus         = var.sim_fw_ocpus
    memory_in_gbs = var.sim_fw_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.sim_fw_image_id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.ss_app.id
    display_name           = "vnic_${local.ss_fw_instance_name}"
    assign_public_ip       = false
    skip_source_dest_check = true
    freeform_tags          = local.cmp_freeform_tags
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = local.sim_fw_userdata
  }

  freeform_tags = local.cmp_freeform_tags
  defined_tags  = local.cmp_defined_tags
}

# =============================================================================
# PHASE 2 — DEVT DRG ATTACHMENT (no Sim FW in DEVT)
# =============================================================================

resource "oci_core_drg_attachment" "devt" {
  count        = local.phase2_enabled ? 1 : 0
  drg_id       = var.hub_drg_id
  display_name = local.devt_drg_attachment_name

  network_details {
    id   = oci_core_vcn.devt.id
    type = "VCN"
  }
}
