# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2
# TEAM 3 OWNED — Governance and tagging layer
#
# =============================================================================
# MONITORING AND TAGS — THREE-LAYER TAGGING STRATEGY
#
# LAYER 1 — Freeform tags (local.landing_zone_tags in locals.tf):
#   Applied immediately, no dependency. Bootstrap watermark.
#   "oci-elz-landing-zone" = "${service_label}/v1"
#   "managed-by"           = "terraform"
#
# LAYER 2 — Defined tags (this file):
#   Namespace: C0-star-elz-v1 (C0 = tenancy root, singleton per tenancy)
#   Tags: Environment, Owner, ManagedBy, CostCenter
#   CostCenter: is_cost_tracking = true  ← required for TC-05
#   OCI constraint: namespace name is IMMUTABLE after creation.
#                   If you must rename, retire old and create new.
#   depends_on: all resources using defined_tags must include
#     depends_on = [module.lz_tags] or depends_on = [oci_identity_tag.cost_center]
#     to ensure ~10s propagation before use.
#
# LAYER 3 — Tag defaults (this file):
#   oci_identity_tag_default on tenancy root: auto-applies CreatedBy to every
#   new resource using ${iam.principal.name} computed value.
#   CIS 3.2 requirement. Auditable without manual tagging.
#
# SPRINT1-FIX (module-dependency):
#   Replaced lz_tags module call (github.com/oci-landing-zones/
#   terraform-oci-modules-governance//tags?ref=v0.1.5) with direct resources.
#   Reason: module added 4-hop variable tracing and a computed name collision
#   when tag_namespace_name was empty string (fell back to "${service_label}-namesp"
#   producing inconsistent name on second apply). Direct resources:
#     1. namespace name = constant "C0-star-elz-v1" (never drifts)
#     2. No module version pins to track
#     3. Transparent depends_on chain visible in this file
#     4. CostCenter is_cost_tracking = true explicit (module had it implicit)
#
# C0 NAMESPACE NAMING:
#   "C0-star-elz-v1" — C0 prefix identifies tenancy root scope (matches C0/C1
#   hierarchy convention). Consistent with how C1_ prefixes compartments.
#   V1 suffix allows V2 namespace without retiring V1 tags.
# =============================================================================

# =============================================================================
# TAG NAMESPACE — C0-star-elz-v1
# Tenancy root, singleton. Name is immutable once created.
# =============================================================================
resource "oci_identity_tag_namespace" "elz_v1" {
  provider       = oci.home
  compartment_id = local.tenancy_id
  name           = local.tag_namespace_name # "C0-star-elz-v1"
  description    = "${local.lz_description} — Tag namespace. Immutable name. Contains cost-tracking and governance tags."
  is_retired     = false

  freeform_tags = local.landing_zone_tags

  lifecycle {
    # CRITICAL: prevent accidental deletion of tag namespace.
    # Deleting the namespace would orphan all defined tag keys and break
    # cost reporting, governance dashboards, and tag default enforcement.
    # To delete: remove this block, apply, then destroy separately.
    prevent_destroy = true
  }
}

# =============================================================================
# TAG DEFINITIONS — 4 tags within C0-star-elz-v1 namespace
# =============================================================================

resource "oci_identity_tag" "environment" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "Environment"
  description      = "Deployment environment: poc | dev | uat | prod"
  is_retired       = false
  is_cost_tracking = false

  freeform_tags = local.landing_zone_tags
}

resource "oci_identity_tag" "owner" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "Owner"
  description      = "Landing zone instance owner — matches service_label"
  is_retired       = false
  is_cost_tracking = false

  freeform_tags = local.landing_zone_tags
}

resource "oci_identity_tag" "managed_by" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "ManagedBy"
  description      = "Infrastructure management tool: terraform | manual | ansible"
  is_retired       = false
  is_cost_tracking = false

  freeform_tags = local.landing_zone_tags
}

resource "oci_identity_tag" "cost_center" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "CostCenter"
  description      = "Cost center code for OCI cost tracking and billing allocation — TC-05 required tag"
  is_retired       = false
  is_cost_tracking = true # TC-05: cost tracking enabled on CostCenter tag

  freeform_tags = local.landing_zone_tags
}

# =============================================================================
# TAG 5 — DataClassification
# Singapore Government data classification: Official-Open, Official-Closed,
# Sensitive-Normal, Sensitive-High, Restricted.
# Default tag (Layer 3 below) pre-stamps every new resource as Official-Closed.
# Operators override on individual resources requiring higher classification.
# TC-05b: confirm this tag exists with is_cost_tracking = false.
# =============================================================================
resource "oci_identity_tag" "data_classification" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "DataClassification"
  description      = "SG Govt data classification: Official-Open | Official-Closed | Sensitive-Normal | Sensitive-High | Restricted. Default: Official-Closed."
  is_retired       = false
  is_cost_tracking = false

  freeform_tags = local.landing_zone_tags
}

# =============================================================================
# TAG DEFAULT — Layer 3: DataClassification auto-applied at tenancy root
# CIS 3.2 mandatory tagging: every resource created in this tenancy
# automatically receives DataClassification = Official-Closed unless
# explicitly overridden on the resource. Non-blocking (is_required = false).
#
# FIX vs original: was incorrectly reusing oci_identity_tag.owner.id which
# caused Owner to receive "${iam.principal.name}" at creation, then be
# overridden by lz_defined_tags on apply — semantically wrong and inconsistent.
# DataClassification is the correct tag key for a static default value.
# =============================================================================
resource "oci_identity_tag_default" "data_classification" {
  provider          = oci.home
  compartment_id    = local.tenancy_id
  tag_definition_id = oci_identity_tag.data_classification.id
  value             = "Official-Closed" # SG Govt default classification
  is_required       = false             # non-blocking — OCI tag service can lag ~10s

  depends_on = [
    oci_identity_tag.data_classification,
    oci_identity_tag_namespace.elz_v1
  ]
}

resource "oci_identity_tag" "sprint" {
  provider         = oci.home
  tag_namespace_id = oci_identity_tag_namespace.elz_v1.id
  name             = "Sprint"
  description      = "Sprint number that last created or modified this resource"
  is_retired       = false
  is_cost_tracking = false

  freeform_tags = local.landing_zone_tags
}

# =============================================================================
# TAG LOCALS — used across all modules for consistent defined tag application
# NOTE: Resources using lz_defined_tags must declare:
#   depends_on = [oci_identity_tag.cost_center]
# to allow ~10s OCI propagation before the defined tags can be applied.
# =============================================================================
locals {
  # All defined tag key-value pairs — merged into resource defined_tags attributes
  # lz_defined_tags is defined in locals.tf and references local.tag_namespace_name
  # This local confirms the tag namespace resource exists before use
  tags_ready = oci_identity_tag_namespace.elz_v1.id != "" ? true : false
}
