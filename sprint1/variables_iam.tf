# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2

# =============================================================================
# COMPARTMENT NAME OVERRIDES (C1 Level)
# All default to null — when null, canonical constants from locals.tf are used.
# Set in ORM UI (Section 2) or terraform.tfvars ONLY if you need non-standard names.
# Standard STAR names are defined in locals.tf and require no override.
# =============================================================================
variable "custom_nw_compartment_name" {
  description = "Override for C1_R_ELZ_NW. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_nw_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_nw_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_sec_compartment_name" {
  description = "Override for C1_R_ELZ_SEC. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_sec_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_sec_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_soc_compartment_name" {
  description = "Override for C1_R_ELZ_SOC. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_soc_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_soc_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_ops_compartment_name" {
  description = "Override for C1_R_ELZ_OPS. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_ops_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_ops_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_csvcs_compartment_name" {
  description = "Override for C1_R_ELZ_CSVCS. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_csvcs_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_csvcs_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_devt_csvcs_compartment_name" {
  description = "Override for C1_R_ELZ_DEVT_CSVCS. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_devt_csvcs_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_devt_csvcs_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_os_nw_compartment_name" {
  description = "Override for C1_OS_ELZ_NW. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_os_nw_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_os_nw_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_ss_nw_compartment_name" {
  description = "Override for C1_SS_ELZ_NW. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_ss_nw_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_ss_nw_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_ts_nw_compartment_name" {
  description = "Override for C1_TS_ELZ_NW. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_ts_nw_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_ts_nw_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

variable "custom_devt_nw_compartment_name" {
  description = "Override for C1_DEVT_ELZ_NW. Leave null to use STAR standard name."
  type        = string
  default     = null
  validation {
    condition     = var.custom_devt_nw_compartment_name == null || can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.custom_devt_nw_compartment_name))
    error_message = "Compartment name must be uppercase alphanumeric with underscores, starting with a letter."
  }
}

# =============================================================================
# ENCLOSING COMPARTMENT (OPT-IN — default: false)
# Nests all 10 C1 compartments under a single parent for test isolation.
# Use case: multiple teams sharing one tenancy for workshop — prevents name
# collision AND gives each deployment a clean destroy scope.
# Default: false — all C1 compartments created directly at tenancy root (C0).
# Exposed in ORM UI: Section 3 — Test Isolation.
# =============================================================================
variable "enable_enclosing_compartment" {
  description = <<-EOT
    Nest all 10 C1 compartments under a single enclosing parent compartment.
    false (default): All C1 compartments created at tenancy root (C0). Recommended for production.
    true: Creates one parent compartment first, then all C1 compartments inside it.
          Use for workshop isolation when multiple teams share one tenancy.
  EOT
  type        = bool
  default     = false
}

variable "enclosing_compartment_name" {
  description = "Name of the enclosing parent compartment when enable_enclosing_compartment = true."
  type        = string
  default     = "AD_LZ_DEV"
  validation {
    condition     = can(regex("^[A-Z][A-Z0-9_]{1,99}$", var.enclosing_compartment_name))
    error_message = "Enclosing compartment name must be uppercase alphanumeric with underscores."
  }
}

# =============================================================================
# C2 LEVEL SUB-COMPARTMENTS (OPT-IN — default: false)
# Adds Level 2 child compartments under selected C1 compartments.
# Use case: workload isolation, agency separation, prod/dev environment splits.
# When true, populate children : {} in the relevant iam_cmps_team*.tf file.
# Exposed in ORM UI: Section 3 — Future Compartment Levels.
# =============================================================================
variable "enable_c2_compartments" {
  description = <<-EOT
    Enable Level 2 (C2) child compartments under C1 compartments.
    false (default): No sub-compartments. Clean Sprint 1 baseline.
    true: Unlocks C2_ name variables below. Then add children blocks to
          iam_cmps_team*.tf files for the relevant compartments.
  EOT
  type        = bool
  default     = false
}

# C2 name stubs — only used when enable_c2_compartments = true
# Add more as needed following C2_<AGENCY>_<FUNCTION> convention
variable "c2_soc_logs_name" {
  description = "Name for a Level 2 log archive compartment under C1_R_ELZ_SOC. Example: C2_SOC_LOGS."
  type        = string
  default     = "C2_SOC_LOGS"
  validation {
    condition     = can(regex("^C2_[A-Z][A-Z0-9_]{1,96}$", var.c2_soc_logs_name))
    error_message = "C2 compartment names must start with C2_ followed by uppercase alphanumeric and underscores."
  }
}

variable "c2_os_app_name" {
  description = "Name for a Level 2 app compartment under C1_OS_ELZ_NW. Example: C2_OS_APP."
  type        = string
  default     = "C2_OS_APP"
  validation {
    condition     = can(regex("^C2_[A-Z][A-Z0-9_]{1,96}$", var.c2_os_app_name))
    error_message = "C2 compartment names must start with C2_ followed by uppercase alphanumeric and underscores."
  }
}

# =============================================================================
# MANUAL COMPARTMENT OCIDs — SIM compartments created in OCI Console
# Created manually by Team 4 on Sprint 1 Day 1. OCIDs recorded in State Book.
# Required before Sprint 4 apply. Leave empty for Sprint 1.
# =============================================================================
variable "sim_ext_compartment_id" {
  description = "OCID of C1_SIM_EXT — created manually by Team 4 (Sprint 1 Day 1). Leave empty until Sprint 4."
  type        = string
  default     = ""
  validation {
    condition     = var.sim_ext_compartment_id == "" || can(regex("^ocid1\\.compartment\\.", var.sim_ext_compartment_id))
    error_message = "sim_ext_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment. or empty string."
  }
}

variable "sim_child_compartment_id" {
  description = "OCID of C1_SIM_CHILD — created manually by Team 4 (Sprint 1 Day 1). Leave empty until Sprint 4."
  type        = string
  default     = ""
  validation {
    condition     = var.sim_child_compartment_id == "" || can(regex("^ocid1\\.compartment\\.", var.sim_child_compartment_id))
    error_message = "sim_child_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment. or empty string."
  }
}
