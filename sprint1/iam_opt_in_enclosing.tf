# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
#
# =============================================================================
# OPTIONAL ENCLOSING COMPARTMENT — TEST ISOLATION
#
# DEFAULT: disabled (enable_enclosing_compartment = false)
#   All 10 C1 compartments created directly at tenancy root (C0).
#   Recommended for production deployments.
#
# WHEN TO ENABLE:
#   Multiple teams sharing one tenancy for a workshop.
#   Each team sets a unique enclosing_compartment_name (e.g. T1_AD_LZ_DEV,
#   T2_AD_LZ_DEV) to prevent compartment name collisions at tenancy root.
#   One terraform destroy removes all 10 C1 compartments cleanly.
#
# HOW TO ENABLE:
#   ORM UI: Section 3 → Enable Enclosing Compartment = true
#           Enclosing Compartment Name = <your unique name>
#   CLI:    enable_enclosing_compartment = true
#           enclosing_compartment_name   = "T1_AD_LZ_DEV"
#
# HIERARCHY WITH ENCLOSING:
#   C0 Tenancy Root
#   └── T1_AD_LZ_DEV  ← this resource (count = 1 when enabled)
#       ├── C1_R_ELZ_NW
#       ├── C1_R_ELZ_SEC
#       └── ... (10 C1 compartments)
#
# HIERARCHY WITHOUT ENCLOSING (default):
#   C0 Tenancy Root
#   ├── C1_R_ELZ_NW
#   ├── C1_R_ELZ_SEC
#   └── ... (10 C1 compartments)
#
# parent_compartment_id local is defined in locals.tf and resolves conditionally:
#   enable_enclosing_compartment = true  → oci_identity_compartment.enclosing[0].id
#   enable_enclosing_compartment = false → local.tenancy_id
# =============================================================================

resource "oci_identity_compartment" "enclosing" {
  count = var.enable_enclosing_compartment ? 1 : 0

  provider       = oci.home
  compartment_id = local.tenancy_id
  name           = local.enclosing_compartment_name
  description    = "${local.lz_description} — Enclosing compartment for test isolation. Contains all C1 sub-compartments. Managed by Terraform."
  enable_delete  = true # true here — enclosing compartment is ephemeral for workshops

  freeform_tags = merge(local.landing_zone_tags, {
    "enclosing-for" = var.service_label
    "purpose"       = "test-isolation"
  })

  defined_tags = local.lz_defined_tags
}
