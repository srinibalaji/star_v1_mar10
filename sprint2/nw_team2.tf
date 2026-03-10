# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# NETWORK — TEAM 2 OWNED FILE
# Team 2 domain: Trusted Services (TS) Spoke
# Sprint 2 | Issues: S2-T2 (VCN+Subnet), S2-T2 (Route Table), S2-T2 (Sim FW)
# Branch: sprint2/nw-team2
# =============================================================================
#
# RESOURCES IN THIS FILE:
#   PHASE 1:
#     oci_core_vcn.ts               — TS spoke VCN  10.3.0.0/24
#     oci_core_route_table.ts_app   — RT created now (empty rules). Rule added Phase 2.
#     oci_core_subnet.ts_app        — App subnet 10.3.0.0/24, private, RT assigned.
#
#   PHASE 2:
#     oci_core_drg_attachment.ts    — Attaches TS VCN to Hub DRG
#     Route table updated in-place: DRG rule added via dynamic block
#     oci_core_instance.sim_fw_ts   — Sim Firewall (Oracle Linux 8, E4.Flex)
#
# COMPARTMENT: C1_TS_ELZ_NW — var.ts_compartment_id
# =============================================================================

# =============================================================================
# PHASE 1 — VCN + ROUTE TABLE + SUBNET
# [S2-T2] VCN + Subnet for TS compartment
# =============================================================================

resource "oci_core_vcn" "ts" {
  compartment_id = var.ts_compartment_id
  cidr_blocks    = [local.ts_vcn_cidr]
  display_name   = local.ts_vcn_name
  dns_label      = local.ts_vcn_dns_label

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

# [S2-T2] Route Table for TS compartment
# DRG rule added Phase 2.
resource "oci_core_route_table" "ts_app" {
  compartment_id = var.ts_compartment_id
  vcn_id         = oci_core_vcn.ts.id
  display_name   = local.ts_app_rt_name

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

  depends_on = [oci_core_drg_attachment.ts]
}


resource "oci_core_subnet" "ts_app" {
  compartment_id             = var.ts_compartment_id
  vcn_id                     = oci_core_vcn.ts.id
  cidr_block                 = local.ts_app_subnet_cidr
  display_name               = local.ts_app_subnet_name
  dns_label                  = local.ts_app_subnet_dns_label
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.ts_app.id
  security_list_ids          = [oci_core_security_list.ts_app.id]

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

resource "oci_core_security_list" "ts_app" {
  compartment_id = var.ts_compartment_id
  vcn_id         = oci_core_vcn.ts.id
  display_name   = local.ts_app_seclist_name

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
# PHASE 2 — DRG ATTACHMENT + SIM FIREWALL
# =============================================================================

resource "oci_core_drg_attachment" "ts" {
  count        = local.phase2_enabled ? 1 : 0
  drg_id       = var.hub_drg_id
  display_name = local.ts_drg_attachment_name

  network_details {
    id   = oci_core_vcn.ts.id
    type = "VCN"
  }
}

# [S2-T2] Sim Firewall for TS compartment
resource "oci_core_instance" "sim_fw_ts" {
  count               = local.phase2_enabled ? 1 : 0
  compartment_id      = var.ts_compartment_id
  availability_domain = local.ad_name
  display_name        = local.ts_fw_instance_name
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
    subnet_id              = oci_core_subnet.ts_app.id
    display_name           = "vnic_${local.ts_fw_instance_name}"
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
