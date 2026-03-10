# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2

# OCI provider — default: workload region
provider "oci" {
  region               = var.region
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
  # Ignore Oracle-managed tags — prevents plan noise on every apply
  ignore_defined_tags = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]
}

# OCI provider (home) — IAM resources must be provisioned in home region
# All: compartments, groups, policies, tags, tag defaults
provider "oci" {
  alias                = "home"
  region               = local.regions_map[local.home_region_key]
  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
  ignore_defined_tags  = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    oci = {
      source                = "oracle/oci"
      version               = ">= 6.0.0"
      configuration_aliases = [oci.home]
    }
  }
}
