# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — IAM Variables (from Sprint 1 outputs)
# Same as Sprint 2. 10 compartment OCIDs.
# ─────────────────────────────────────────────────────────────

variable "nw_compartment_id" {
  description = "C1_R_ELZ_NW compartment OCID"
  type        = string
}

variable "sec_compartment_id" {
  description = "C1_R_ELZ_SEC compartment OCID"
  type        = string
}

variable "soc_compartment_id" {
  description = "C1_R_ELZ_SOC compartment OCID"
  type        = string
}

variable "ops_compartment_id" {
  description = "C1_R_ELZ_OPS compartment OCID"
  type        = string
}

variable "csvcs_compartment_id" {
  description = "C1_R_ELZ_CSVCS compartment OCID"
  type        = string
}

variable "devt_csvcs_compartment_id" {
  description = "C1_R_ELZ_DEVT_CSVCS compartment OCID"
  type        = string
}

variable "os_compartment_id" {
  description = "C1_OS_ELZ_NW compartment OCID"
  type        = string
}

variable "ss_compartment_id" {
  description = "C1_SS_ELZ_NW compartment OCID"
  type        = string
}

variable "ts_compartment_id" {
  description = "C1_TS_ELZ_NW compartment OCID"
  type        = string
}

variable "devt_compartment_id" {
  description = "C1_DEVT_ELZ_NW compartment OCID"
  type        = string
}
