# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — General Variables
# Same as Sprint 1/2. ORM populates from stack configuration.
# ─────────────────────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "Tenancy OCID"
  type        = string
}

variable "region" {
  description = "Workload region (ap-singapore-2)"
  type        = string
  default     = "ap-singapore-2"
}


variable "service_label" {
  description = "Service label — used in tags and descriptions only, never in resource names"
  type        = string
  default     = "star"
}

variable "ssh_public_key" {
  description = "SSH public key for Bastion sessions and compute access"
  type        = string
}

variable "enable_vss" {
  description = "Enable Vulnerability Scanning Service. Set false if VSS not available in isolated region."
  type        = bool
  default     = false
}

variable "lz_environment" {
  description = "Environment for tagging: poc, dev, uat, prod."
  type        = string
  default     = "poc"
}

variable "lz_cost_center" {
  description = "Cost center for tagging."
  type        = string
  default     = "STAR-ELZ-V1"
}

variable "user_ocid" {
  description = "API user OCID. Leave blank for ORM."
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
