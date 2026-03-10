# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — Network Variables (CIDRs)
# Same CIDR plan as Sprint 2. Used in route table rules
# and Service Gateway service CIDR references.
# ─────────────────────────────────────────────────────────────

variable "hub_vcn_cidr" {
  description = "Hub VCN CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "os_app_subnet_cidr" {
  description = "OS spoke app subnet CIDR"
  type        = string
  default     = "10.1.0.0/24"
}

variable "ss_app_subnet_cidr" {
  description = "SS spoke app subnet CIDR"
  type        = string
  default     = "10.2.0.0/24"
}

variable "ts_app_subnet_cidr" {
  description = "TS spoke app subnet CIDR"
  type        = string
  default     = "10.3.0.0/24"
}

variable "devt_app_subnet_cidr" {
  description = "DEVT spoke app subnet CIDR"
  type        = string
  default     = "10.4.0.0/24"
}
