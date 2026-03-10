# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — Data Sources
# Shared lookups used by multiple team files.
# ─────────────────────────────────────────────────────────────

# Regions and tenancy — needed by providers.tf for home_region lookup
data "oci_identity_regions" "these" {}

data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

# Object Storage namespace — required for bucket creation
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# Service Gateway — list available Oracle services in the region
# Used by T4 sec_team4.tf for Service Gateway service_id
# Filter to "All <region> Services In Oracle Services Network"
# This is the broadest SG service CIDR — covers Object Storage, OCI APIs, etc.
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ── Cloud Guard — Oracle-managed detector recipes (used by T3 to clone) ──
# Configuration detector recipe — detects misconfigured resources
data "oci_cloud_guard_detector_recipes" "oracle_config" {
  compartment_id = var.tenancy_ocid
  display_name   = "OCI Configuration Detector Recipe"
}

# Activity detector recipe — detects suspicious user/service activity
data "oci_cloud_guard_detector_recipes" "oracle_activity" {
  compartment_id = var.tenancy_ocid
  display_name   = "OCI Activity Detector Recipe"
}

# Responder recipe — automated responses to detected problems
data "oci_cloud_guard_responder_recipes" "oracle_responder" {
  compartment_id = var.tenancy_ocid
  display_name   = "OCI Responder Recipe"
}

# ── Security Zone Policies — list all available policies for custom recipes ──
data "oci_cloud_guard_security_policies" "all" {
  compartment_id = var.tenancy_ocid
}
