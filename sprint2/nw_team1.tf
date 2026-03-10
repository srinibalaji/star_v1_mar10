# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# NETWORK — TEAM 1 OWNED FILE
# Team 1 domain: Operational Systems (OS) Spoke
# Sprint 2 | Issues: S2-T1 (VCN+Subnet), S2-T1 (Route Table), S2-T1 (Sim FW)
# Branch: sprint2/nw-team1
# =============================================================================
#
# RESOURCES IN THIS FILE:
#   PHASE 1 (no hub_drg_id needed — apply immediately):
#     oci_core_vcn.os               — OS spoke VCN  10.1.0.0/24
#     oci_core_route_table.os_app   — RT created now (empty rules). Rule added Phase 2.
#     oci_core_subnet.os_app        — App subnet 10.1.0.0/24, private, RT assigned.
#
#   PHASE 2 (requires hub_drg_id from T4 Phase 1 output):
#     oci_core_drg_attachment.os    — Attaches OS VCN to Hub DRG
#     Route table updated in-place: DRG rule added via dynamic block
#     oci_core_instance.sim_fw_os   — Sim Firewall (Oracle Linux 8, E4.Flex)
#
# OCI ROUTE TABLE PATTERN:
#   route_table_id is set directly on oci_core_subnet (OCI native pattern).
#   There is no separate attachment resource — that is an AWS concept.
#   Phase 1: route table created with 0 rules. Subnet references it immediately.
#   Phase 2: dynamic route_rules block adds DRG rule when hub_drg_id is set.
#            Terraform updates route table in-place — subnet is NOT recreated.
#
# COMPARTMENT: C1_OS_ELZ_NW — var.os_compartment_id
# =============================================================================

# =============================================================================
# PHASE 1 — VCN + ROUTE TABLE + SUBNET
# [S2-T1] VCN + Subnet for OS compartment
# =============================================================================

resource "oci_core_vcn" "os" {
  compartment_id = var.os_compartment_id
  cidr_blocks    = [local.os_vcn_cidr]
  display_name   = local.os_vcn_name
  dns_label      = local.os_vcn_dns_label

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

# [S2-T1] Route Table for OS compartment
# DRG rule added Phase 2.
resource "oci_core_route_table" "os_app" {
  compartment_id = var.os_compartment_id
  vcn_id         = oci_core_vcn.os.id
  display_name   = local.os_app_rt_name

  # DRG route — Phase 2 only
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

  depends_on = [oci_core_drg_attachment.os]
}


# Subnet references route table directly — OCI native pattern (no separate attachment resource)
resource "oci_core_subnet" "os_app" {
  compartment_id             = var.os_compartment_id
  vcn_id                     = oci_core_vcn.os.id
  cidr_block                 = local.os_app_subnet_cidr
  display_name               = local.os_app_subnet_name
  dns_label                  = local.os_app_subnet_dns_label
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.os_app.id
  security_list_ids          = [oci_core_security_list.os_app.id]

  freeform_tags = local.net_freeform_tags
  defined_tags  = local.net_defined_tags
}

# Security list — allow all internal for Sprint 2 validation (ping, SSH, NPA)
# Sprint 3 replaces with NSGs
resource "oci_core_security_list" "os_app" {
  compartment_id = var.os_compartment_id
  vcn_id         = oci_core_vcn.os.id
  display_name   = local.os_app_seclist_name

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
# count = 0 Phase 1, count = 1 Phase 2
# =============================================================================

resource "oci_core_drg_attachment" "os" {
  count        = local.phase2_enabled ? 1 : 0
  drg_id       = var.hub_drg_id
  display_name = local.os_drg_attachment_name

  network_details {
    id   = oci_core_vcn.os.id
    type = "VCN"
  }
}

# [S2-T1] Sim Firewall for OS compartment
resource "oci_core_instance" "sim_fw_os" {
  count               = local.phase2_enabled ? 1 : 0
  compartment_id      = var.os_compartment_id
  availability_domain = local.ad_name
  display_name        = local.os_fw_instance_name
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
    subnet_id              = oci_core_subnet.os_app.id
    display_name           = "vnic_${local.os_fw_instance_name}"
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
