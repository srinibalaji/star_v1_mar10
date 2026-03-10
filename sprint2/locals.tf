# STAR ELZ V1 — Sprint 2 Locals

locals {

  # Region and tenancy
  regions_map         = { for r in data.oci_identity_regions.these.regions : r.key => r.name }
  regions_map_reverse = { for r in data.oci_identity_regions.these.regions : r.name => r.key }
  home_region_key     = data.oci_identity_tenancy.this.home_region_key
  region_key          = lower(local.regions_map_reverse[var.region])
  tenancy_id          = data.oci_identity_tenancy.this.id

  # Availability domain
  ad_name = data.oci_identity_availability_domains.these.availability_domains[0].name

  # Tagging — aligned with Sprint 1 tag namespace
  tag_namespace_name = "C0-star-elz-v1"
  lz_description     = "STAR ELZ V1 [${var.service_label}]"

  landing_zone_tags = {
    "oci-elz-landing-zone" = "${var.service_label}/v1"
    "managed-by"           = "terraform"
    "sprint"               = "sprint2-networking"
  }

  lz_defined_tags = {
    "${local.tag_namespace_name}.Environment" = var.lz_environment
    "${local.tag_namespace_name}.Owner"       = var.service_label
    "${local.tag_namespace_name}.ManagedBy"   = "terraform"
    "${local.tag_namespace_name}.CostCenter"  = var.lz_cost_center
  }

  # ── VCN Names ──
  hub_vcn_name  = "vcn_r_elz_nw"
  os_vcn_name   = "vcn_os_elz_nw"
  ts_vcn_name   = "vcn_ts_elz_nw"
  ss_vcn_name   = "vcn_ss_elz_nw"
  devt_vcn_name = "vcn_devt_elz_nw"

  # ── Subnet Names ──
  hub_fw_subnet_name   = "sub_r_elz_nw_fw"
  hub_mgmt_subnet_name = "sub_r_elz_nw_mgmt"
  os_app_subnet_name   = "sub_os_elz_nw_app"
  ts_app_subnet_name   = "sub_ts_elz_nw_app"
  ss_app_subnet_name   = "sub_ss_elz_nw_app"
  devt_app_subnet_name = "sub_devt_elz_nw_app"

  # ── DRG Names ──
  hub_drg_name    = "drg_r_hub"
  ew_hub_drg_name = "drg_r_ew_hub"

  # ── Route Table Names ──
  hub_fw_rt_name   = "rt_r_elz_nw_fw"
  hub_mgmt_rt_name = "rt_r_elz_nw_mgmt"
  os_app_rt_name   = "rt_os_elz_nw_app"
  ts_app_rt_name   = "rt_ts_elz_nw_app"
  ss_app_rt_name   = "rt_ss_elz_nw_app"
  devt_app_rt_name = "rt_devt_elz_nw_app"

  # ── Security List Names ──
  hub_fw_seclist_name   = "sl_r_elz_nw_fw"
  hub_mgmt_seclist_name = "sl_r_elz_nw_mgmt"
  os_app_seclist_name   = "sl_os_elz_nw_app"
  ts_app_seclist_name   = "sl_ts_elz_nw_app"
  ss_app_seclist_name   = "sl_ss_elz_nw_app"
  devt_app_seclist_name = "sl_devt_elz_nw_app"

  # ── Instance Names ──
  hub_fw_instance_name = "fw_r_elz_nw_hub_sim"
  os_fw_instance_name  = "fw_os_elz_nw_sim"
  ts_fw_instance_name  = "fw_ts_elz_nw_sim"
  ss_fw_instance_name  = "fw_ss_elz_nw_sim"

  # ── Bastion ──
  hub_bastion_name = "bas_r_elz_nw_hub"

  # ── DRG Attachment Names ──
  hub_drg_attachment_name  = "drga_r_elz_nw_hub"
  os_drg_attachment_name   = "drga_os_elz_nw"
  ts_drg_attachment_name   = "drga_ts_elz_nw"
  ss_drg_attachment_name   = "drga_ss_elz_nw"
  devt_drg_attachment_name = "drga_devt_elz_nw"

  # ── DNS Labels ──
  hub_vcn_dns_label         = "hubelznw"
  os_vcn_dns_label          = "oselznw"
  ts_vcn_dns_label          = "tselznw"
  ss_vcn_dns_label          = "sselznw"
  devt_vcn_dns_label        = "devtelznw"
  hub_fw_subnet_dns_label   = "hubfw"
  hub_mgmt_subnet_dns_label = "hubmgmt"
  os_app_subnet_dns_label   = "osapp"
  ts_app_subnet_dns_label   = "tsapp"
  ss_app_subnet_dns_label   = "ssapp"
  devt_app_subnet_dns_label = "devtapp"

  # ── CIDR Plan ──
  hub_vcn_cidr         = var.hub_vcn_cidr
  hub_fw_subnet_cidr   = var.hub_fw_subnet_cidr
  hub_mgmt_subnet_cidr = var.hub_mgmt_subnet_cidr
  os_vcn_cidr          = var.os_vcn_cidr
  os_app_subnet_cidr   = var.os_app_subnet_cidr
  ts_vcn_cidr          = var.ts_vcn_cidr
  ts_app_subnet_cidr   = var.ts_app_subnet_cidr
  ss_vcn_cidr          = var.ss_vcn_cidr
  ss_app_subnet_cidr   = var.ss_app_subnet_cidr
  devt_vcn_cidr        = var.devt_vcn_cidr
  devt_app_subnet_cidr = var.devt_app_subnet_cidr
  anywhere             = "0.0.0.0/0"

  # ── Phase 2 Gate ──
  phase2_enabled = var.hub_drg_id != ""

  # ── Sim FW Compute ──
  sim_fw_image_id = data.oci_core_images.platform_oel8.images[0].id

  # Cloud-init: firewalld masquerade (native to OL8, zero package installs)
  sim_fw_userdata = base64encode(<<-EOT
    #!/bin/bash
    set -e
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipforward.conf
    sysctl --system
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-protocol=icmp
    firewall-cmd --reload
    echo "Sim FW bootstrap complete $(date)" >> /var/log/star-elz-simfw-init.log
  EOT
  )
}

# locals {
#   # Tag merge — network resources
#   net_defined_tags  = local.lz_defined_tags
#   net_freeform_tags = local.landing_zone_tags

#   # Tag merge — compute resources
#   cmp_defined_tags  = merge(local.lz_defined_tags, { "${local.tag_namespace_name}.CostCenter" = "STAR-ELZ-SIMFW" })
#   cmp_freeform_tags = merge(local.landing_zone_tags, { "resource-type" = "sim-firewall" })
# }
