# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# IAM COMPARTMENT OCIDs — SPRINT 1 HANDOFF VARIABLES
# =============================================================================
# These OCIDs come from Sprint 1 Terraform outputs.
# After Sprint 1 apply, run:
#   terraform output -json > sprint1_outputs.json
# Then paste each OCID into terraform.tfvars (or ORM Variables UI).
#
# ALL variables below have NO default — they are required.
# If empty, terraform validate will fail immediately with a clear message.
# This prevents silent failures from unset compartment references.
#
# VALIDATION: OCI compartment OCIDs always start with "ocid1.compartment."
# =============================================================================

variable "nw_compartment_id" {
  description = "OCID of C1_R_ELZ_NW (Hub Network). From: terraform output nw_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.nw_compartment_id))
    error_message = "nw_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "sec_compartment_id" {
  description = "OCID of C1_R_ELZ_SEC (Security). From: terraform output sec_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.sec_compartment_id))
    error_message = "sec_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "soc_compartment_id" {
  description = "OCID of C1_R_ELZ_SOC (SOC). From: terraform output soc_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.soc_compartment_id))
    error_message = "soc_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "ops_compartment_id" {
  description = "OCID of C1_R_ELZ_OPS (Operations). From: terraform output ops_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.ops_compartment_id))
    error_message = "ops_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "csvcs_compartment_id" {
  description = "OCID of C1_R_ELZ_CSVCS (Common Services). From: terraform output csvcs_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.csvcs_compartment_id))
    error_message = "csvcs_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "devt_csvcs_compartment_id" {
  description = "OCID of C1_R_ELZ_DEVT_CSVCS (Dev Common Services). From: terraform output devt_csvcs_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.devt_csvcs_compartment_id))
    error_message = "devt_csvcs_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "os_compartment_id" {
  description = "OCID of C1_OS_ELZ_NW (Operational Systems). From: terraform output os_nw_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.os_compartment_id))
    error_message = "os_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "ss_compartment_id" {
  description = "OCID of C1_SS_ELZ_NW (Shared Services). From: terraform output ss_nw_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.ss_compartment_id))
    error_message = "ss_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "ts_compartment_id" {
  description = "OCID of C1_TS_ELZ_NW (Trusted Services). From: terraform output ts_nw_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.ts_compartment_id))
    error_message = "ts_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}

variable "devt_compartment_id" {
  description = "OCID of C1_DEVT_ELZ_NW (Development). From: terraform output devt_nw_compartment_id"
  type        = string
  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.devt_compartment_id))
    error_message = "devt_compartment_id must be a valid OCI compartment OCID starting with ocid1.compartment."
  }
}
