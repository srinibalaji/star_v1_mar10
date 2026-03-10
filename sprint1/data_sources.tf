# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2

# All regions — used to build regions_map / regions_map_reverse in locals.tf
data "oci_identity_regions" "these" {}

# Region subscriptions — home region detection
data "oci_identity_region_subscriptions" "these" {
  tenancy_id = var.tenancy_ocid
}

# Tenancy — home_region_key + tenancy OCID via local.tenancy_id
data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

# Object storage namespace — used for bucket naming in Sprint 3+
data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

# Cloud Guard configuration status — used to gate Cloud Guard enablement
# OCI returns existing config or error if Cloud Guard not yet enabled
data "oci_cloud_guard_cloud_guard_configuration" "this" {
  compartment_id = var.tenancy_ocid
}

# Availability Domains — Sprint 2 forward compatibility
# Used by compute and subnet resources in Sprint 2+
data "oci_identity_availability_domains" "these" {
  compartment_id = var.tenancy_ocid
}

# Platform images — Sprint 2 Sim FW and workload compute
# Query-based: always resolves to latest OL8 image at plan time
# No hardcoded OCID — image OCIDs are region-specific and change on patch releases
data "oci_core_images" "platform_oel_images" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
