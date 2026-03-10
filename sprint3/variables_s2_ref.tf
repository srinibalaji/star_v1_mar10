# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — Sprint 2 Reference Variables
# These OCIDs come from Sprint 2 ORM stack outputs.
# Paste them into terraform.tfvars or ORM variable panel.
# ─────────────────────────────────────────────────────────────

# ── DRG ──
variable "hub_drg_id" {
  description = "OCID of drg_r_hub"
  type        = string
}

# ── DRG Attachments ──
variable "hub_drg_attachment_id" {
  description = "OCID of drga_r_elz_nw_hub (Hub VCN attachment)"
  type        = string
}

variable "os_drg_attachment_id" {
  description = "OCID of drga_os_elz_nw"
  type        = string
}

variable "ts_drg_attachment_id" {
  description = "OCID of drga_ts_elz_nw"
  type        = string
}

variable "ss_drg_attachment_id" {
  description = "OCID of drga_ss_elz_nw"
  type        = string
}

variable "devt_drg_attachment_id" {
  description = "OCID of drga_devt_elz_nw"
  type        = string
}

# ── VCNs ──
variable "hub_vcn_id" {
  description = "OCID of vcn_r_elz_nw"
  type        = string
}

variable "os_vcn_id" {
  description = "OCID of vcn_os_elz_nw"
  type        = string
}

variable "ts_vcn_id" {
  description = "OCID of vcn_ts_elz_nw"
  type        = string
}

variable "ss_vcn_id" {
  description = "OCID of vcn_ss_elz_nw"
  type        = string
}

variable "devt_vcn_id" {
  description = "OCID of vcn_devt_elz_nw"
  type        = string
}

# ── Subnets ──
variable "hub_fw_subnet_id" {
  description = "OCID of sub_r_elz_nw_fw"
  type        = string
}

variable "hub_mgmt_subnet_id" {
  description = "OCID of sub_r_elz_nw_mgmt"
  type        = string
}

variable "os_app_subnet_id" {
  description = "OCID of sub_os_elz_nw_app"
  type        = string
}

variable "ts_app_subnet_id" {
  description = "OCID of sub_ts_elz_nw_app"
  type        = string
}

variable "ss_app_subnet_id" {
  description = "OCID of sub_ss_elz_nw_app"
  type        = string
}

variable "devt_app_subnet_id" {
  description = "OCID of sub_devt_elz_nw_app"
  type        = string
}

# ── Bastion ──
variable "bastion_id" {
  description = "OCID of bas_r_elz_nw_hub Bastion service (created in Sprint 2 T4)"
  type        = string
}

# ── Sim FW Instances (for Bastion sessions) ──
variable "os_fw_private_ip" {
  default     = ""
  description = "OCID of fw_os_elz_nw_sim compute instance"
  type        = string
}

variable "ts_fw_private_ip" {
  default     = ""
  description = "OCID of fw_ts_elz_nw_sim compute instance"
  type        = string
}

variable "hub_fw_private_ip_id" {
  description = "OCID of fw_r_elz_nw_hub_sim VNIC private IP — next-hop for VCN ingress RT. Get from: oci network private-ip list --subnet-id $HUB_FW_SUBNET_ID"
  type        = string
}

# ── Route Table (for import into Sprint 3) ──
variable "hub_fw_rt_id" {
  description = "OCID of rt_r_elz_nw_fw — imported from Sprint 2 state to add spoke CIDRs and SG route"
  type        = string
}

