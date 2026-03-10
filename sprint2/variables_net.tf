# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# NETWORK VARIABLES
# =============================================================================
# CIDR defaults follow the STAR ELZ IP plan:
#   10.0.0.0/16 — Hub (T4)
#   10.1.0.0/24 — OS spoke (T1)
#   10.2.0.0/24 — SS spoke (T3)
#   10.3.0.0/24 — TS spoke (T2)
#   10.4.0.0/24 — DEVT spoke (T3)
#
# Override only if your tenancy has conflicting address space.
# =============================================================================

# =============================================================================
# TWO-PHASE APPLY — HUB DRG OCID
# Phase 1: leave hub_drg_id = "" (default)
# Phase 2: paste T4's DRG OCID from: terraform output hub_drg_id
#          All teams update ORM Variables and re-apply.
# =============================================================================
variable "hub_drg_id" {
  description = <<-EOT
    OCID of the Hub DRG provisioned by Team 4 in Phase 1.
    Phase 1: leave empty — DRG attachments, route tables, and Sim FW are skipped.
    Phase 2: paste OCID from T4 output: terraform output hub_drg_id
             All teams re-apply. Phase 2 resources (route tables, DRG attachments,
             Sim FW, Bastion) are then created.
  EOT
  type        = string
  default     = ""
  validation {
    condition     = var.hub_drg_id == "" || can(regex("^ocid1\\.drg\\.", var.hub_drg_id))
    error_message = "hub_drg_id must be empty (Phase 1) or a valid OCI DRG OCID starting with ocid1.drg."
  }
}

# =============================================================================
# HUB VCN CIDRs — Team 4 (C1_R_ELZ_NW)
# =============================================================================
variable "hub_vcn_cidr" {
  description = "CIDR block for the Hub VCN. Must not overlap with spoke VCNs."
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.hub_vcn_cidr))
    error_message = "hub_vcn_cidr must be a valid CIDR block."
  }
}

variable "hub_fw_subnet_cidr" {
  description = "CIDR for Hub Firewall subnet (untrust/north-south). Must be within hub_vcn_cidr."
  type        = string
  default     = "10.0.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.hub_fw_subnet_cidr))
    error_message = "hub_fw_subnet_cidr must be a valid CIDR block."
  }
}

variable "hub_mgmt_subnet_cidr" {
  description = "CIDR for Hub Management subnet (Bastion, jump host). Must be within hub_vcn_cidr."
  type        = string
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrnetmask(var.hub_mgmt_subnet_cidr))
    error_message = "hub_mgmt_subnet_cidr must be a valid CIDR block."
  }
}

# =============================================================================
# OS VCN CIDRs — Team 1 (C1_OS_ELZ_NW)
# =============================================================================
variable "os_vcn_cidr" {
  description = "CIDR block for the OS spoke VCN."
  type        = string
  default     = "10.1.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.os_vcn_cidr))
    error_message = "os_vcn_cidr must be a valid CIDR block."
  }
}

variable "os_app_subnet_cidr" {
  description = "CIDR for OS App subnet. Must be within os_vcn_cidr."
  type        = string
  default     = "10.1.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.os_app_subnet_cidr))
    error_message = "os_app_subnet_cidr must be a valid CIDR block."
  }
}

# =============================================================================
# TS VCN CIDRs — Team 2 (C1_TS_ELZ_NW)
# =============================================================================
variable "ts_vcn_cidr" {
  description = "CIDR block for the TS spoke VCN."
  type        = string
  default     = "10.3.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.ts_vcn_cidr))
    error_message = "ts_vcn_cidr must be a valid CIDR block."
  }
}

variable "ts_app_subnet_cidr" {
  description = "CIDR for TS App subnet. Must be within ts_vcn_cidr."
  type        = string
  default     = "10.3.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.ts_app_subnet_cidr))
    error_message = "ts_app_subnet_cidr must be a valid CIDR block."
  }
}

# =============================================================================
# SS VCN CIDRs — Team 3 (C1_SS_ELZ_NW)
# =============================================================================
variable "ss_vcn_cidr" {
  description = "CIDR block for the SS spoke VCN."
  type        = string
  default     = "10.2.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.ss_vcn_cidr))
    error_message = "ss_vcn_cidr must be a valid CIDR block."
  }
}

variable "ss_app_subnet_cidr" {
  description = "CIDR for SS App subnet. Must be within ss_vcn_cidr."
  type        = string
  default     = "10.2.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.ss_app_subnet_cidr))
    error_message = "ss_app_subnet_cidr must be a valid CIDR block."
  }
}

# =============================================================================
# DEVT VCN CIDRs — Team 3 (C1_DEVT_ELZ_NW)
# =============================================================================
variable "devt_vcn_cidr" {
  description = "CIDR block for the DEVT spoke VCN."
  type        = string
  default     = "10.4.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.devt_vcn_cidr))
    error_message = "devt_vcn_cidr must be a valid CIDR block."
  }
}

variable "devt_app_subnet_cidr" {
  description = "CIDR for DEVT App subnet. Must be within devt_vcn_cidr."
  type        = string
  default     = "10.4.0.0/24"
  validation {
    condition     = can(cidrnetmask(var.devt_app_subnet_cidr))
    error_message = "devt_app_subnet_cidr must be a valid CIDR block."
  }
}

# =============================================================================
# SIM FIREWALL COMPUTE — shape and sizing
# =============================================================================
variable "sim_fw_shape" {
  description = "OCI compute shape for Sim Firewall instances."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "sim_fw_ocpus" {
  description = "OCPUs for each Sim Firewall instance (E4.Flex minimum: 1)."
  type        = number
  default     = 1
  validation {
    condition     = var.sim_fw_ocpus >= 1 && var.sim_fw_ocpus <= 4
    error_message = "sim_fw_ocpus must be between 1 and 4 for workshop use."
  }
}

variable "sim_fw_memory_gb" {
  description = "Memory (GB) for each Sim Firewall instance (E4.Flex minimum: 6)."
  type        = number
  default     = 6
  validation {
    condition     = var.sim_fw_memory_gb >= 6
    error_message = "sim_fw_memory_gb must be at least 6 GB for E4.Flex."
  }
}

# =============================================================================
# BASTION — allowed client CIDRs (Team 4)
# =============================================================================
variable "bastion_client_cidr" {
  description = "CIDR block allowed to connect to the Hub Bastion. Default: allow all (restrict for production)."
  type        = string
  default     = "10.0.0.0/8"
  validation {
    condition     = can(cidrnetmask(var.bastion_client_cidr))
    error_message = "bastion_client_cidr must be a valid CIDR block."
  }
}
