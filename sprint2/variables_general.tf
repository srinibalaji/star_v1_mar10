# STAR ELZ V1 — Sprint 2 General Variables

variable "tenancy_ocid" {
  description = "Tenancy OCID."
  type        = string
}

variable "user_ocid" {
  description = "API-signing user OCID. Leave blank for ORM."
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "API key fingerprint. Leave blank for ORM."
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "Path to API private key. Leave blank for ORM."
  type        = string
  default     = ""
}

variable "private_key_password" {
  description = "API key passphrase. Leave blank for ORM."
  type        = string
  default     = ""
  sensitive   = true
}

variable "region" {
  description = "OCI region, e.g. ap-singapore-1."
  type        = string
}

variable "service_label" {
  description = "Short identifier (tags/descriptions only). Max 8 chars uppercase."
  type        = string
  default     = "C1"
  validation {
    condition     = can(regex("^[A-Z][A-Z0-9]{0,7}$", var.service_label))
    error_message = "1-8 uppercase alphanumeric, starts with letter."
  }
}

variable "cis_level" {
  description = "CIS Benchmark level: 1 or 2."
  type        = string
  default     = "1"
}

variable "lz_environment" {
  description = "Environment tag: poc, dev, uat, prod."
  type        = string
  default     = "poc"
}

variable "lz_cost_center" {
  description = "Cost center tag."
  type        = string
  default     = "STAR-ELZ-V1"
}

variable "ssh_public_key" {
  description = "SSH public key for Sim FW instances. Paste ~/.ssh/id_rsa.pub contents."
  type        = string
}
