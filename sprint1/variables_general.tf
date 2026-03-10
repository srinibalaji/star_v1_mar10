# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2

# =============================================================================
# AUTHENTICATION — OCI Provider credentials
# ORM (Resource Manager): leave all blank — ORM injects its own instance principal.
# CLI / local: set in terraform.tfvars or environment variables.
# =============================================================================
variable "tenancy_ocid" {
  description = "The OCID of the tenancy. Found at: OCI Console → Profile → Tenancy."
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the API-signing user. Leave blank when using ORM or instance principal."
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "Fingerprint of the API public key. Leave blank when using ORM."
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "Path to the API private key PEM file. Leave blank when using ORM."
  type        = string
  default     = ""
}

variable "private_key_password" {
  description = "Passphrase for the API private key (if encrypted). Leave blank when using ORM."
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# REGION
# =============================================================================
variable "region" {
  description = "OCI region identifier where workload resources are deployed, e.g. ap-singapore-2."
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "region must not be empty."
  }
}

# =============================================================================
# LANDING ZONE IDENTITY
# service_label: short identifier for this LZ instance.
#   - Used in: freeform tags, resource descriptions, ORM stack display.
#   - NOT used in: resource names (names use canonical constants in locals.tf).
# =============================================================================
variable "service_label" {
  description = <<-EOT
    Short identifier for this landing zone instance. Used in tags and descriptions only.
    Max 8 chars, uppercase letters and digits, must start with a letter.
    Example: C1 (STAR ELZ instance 1), C2 (instance 2).
    NOTE: Resource names (compartments, groups, policies) use canonical constants
    defined in locals.tf — they do NOT change when service_label changes.
  EOT
  type        = string
  default     = "C1"
  validation {
    condition     = can(regex("^[A-Z][A-Z0-9]{0,7}$", var.service_label))
    error_message = "service_label must be 1-8 uppercase alphanumeric characters starting with a letter. Example: C1"
  }
}

# =============================================================================
# CIS BENCHMARK
# =============================================================================
variable "cis_level" {
  description = <<-EOT
    CIS OCI Foundations Benchmark compliance level.
    "1" = Practical security baseline (recommended for PoC and initial deployments).
    "2" = Security-critical (enables Vault mandatory encryption, Security Zones, stricter policies).
  EOT
  type        = string
  default     = "1"
  validation {
    condition     = contains(["1", "2"], var.cis_level)
    error_message = "cis_level must be '1' or '2'."
  }
}

# =============================================================================
# TAGGING INPUTS — used in lz_defined_tags (mon_tags.tf)
# =============================================================================
variable "lz_environment" {
  description = "Deployment environment value for the Environment defined tag. e.g. poc, dev, uat, prod."
  type        = string
  default     = "poc"
  validation {
    condition     = contains(["poc", "dev", "uat", "prod"], var.lz_environment)
    error_message = "lz_environment must be one of: poc, dev, uat, prod."
  }
}

variable "lz_cost_center" {
  description = "Cost center code for the CostCenter defined tag. Used for OCI cost tracking and TC-05 validation."
  type        = string
  default     = "STAR-ELZ-V1"
  validation {
    condition     = length(var.lz_cost_center) > 0 && length(var.lz_cost_center) <= 32
    error_message = "lz_cost_center must be 1-32 characters."
  }
}

# =============================================================================
# OUTPUT CONTROL
# =============================================================================
variable "display_output" {
  description = "Display resource OCIDs and names in Terraform output after apply. Set false to suppress."
  type        = bool
  default     = true
}
