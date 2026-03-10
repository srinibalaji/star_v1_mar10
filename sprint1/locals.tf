# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint1-solutions-v2

locals {
  # ---------------------------------------------------------------------------
  # REGION AND TENANCY — derived from data sources, not hardcoded
  # ---------------------------------------------------------------------------
  regions_map         = { for r in data.oci_identity_regions.these.regions : r.key => r.name }
  regions_map_reverse = { for r in data.oci_identity_regions.these.regions : r.name => r.key }
  home_region_key     = data.oci_identity_tenancy.this.home_region_key
  region_key          = lower(local.regions_map_reverse[var.region])

  # Tenancy OCID from data source — avoids repeating var.tenancy_ocid in every resource
  # SPRINT1-FIX: tenancy_id local replaces var.tenancy_ocid in all policy/tag resources
  tenancy_id = data.oci_identity_tenancy.this.id

  # ---------------------------------------------------------------------------
  # NETWORK HELPERS
  # ---------------------------------------------------------------------------
  anywhere                    = "0.0.0.0/0"
  valid_service_gateway_cidrs = ["all-${local.region_key}-services-in-oracle-services-network", "oci-${local.region_key}-objectstorage"]

  # ---------------------------------------------------------------------------
  # COMPARTMENT DELETE PROTECTION
  # false = compartment survives terraform destroy (production safe default)
  # ---------------------------------------------------------------------------
  enable_cmp_delete = false

  # ---------------------------------------------------------------------------
  # LANDING ZONE DESCRIPTION — single string used in all resource descriptions
  # SPRINT1-FIX: replaces var.lz_provenant_label, removes a variable that only
  # served as a description prefix. Derived from service_label + fixed label.
  # ---------------------------------------------------------------------------
  lz_description = "STAR ELZ V1 [${var.service_label}]"

  # ---------------------------------------------------------------------------
  # TAGGING — THREE-LAYER STRATEGY (CIS 3.2 compliant)
  #
  # Layer 1: freeform_tags — applied immediately, no namespace dependency.
  #          "managed-by" watermark identifies Terraform-managed resources.
  #          Used as bootstrap tags before defined tags are available.
  #
  # Layer 2: defined_tags — applied via C0-star-elz-v1 namespace.
  #          depends_on lz_tags module. Used for cost tracking and governance.
  #          CostCenter tag has is_cost_tracking = true (TC-05 requirement).
  #
  # Layer 3: tag defaults (in mon_tags.tf) — CreatedBy applied automatically
  #          to every resource at root level. CIS 3.2 mandatory tagging.
  # ---------------------------------------------------------------------------

  # Layer 1 — freeform, no dependency, applied everywhere
  # SPRINT1-FIX: landing_zone_tags now includes managed-by watermark
  landing_zone_tags = {
    "oci-elz-landing-zone" = "${var.service_label}/v1"
    "managed-by"           = "terraform"
  }

  # Layer 2 — defined tags using C0 namespace
  # Reference: "${local.tag_namespace_name}.TagKey" = "value"
  # NOTE: resources that use defined_tags must have depends_on = [module.lz_tags]
  lz_defined_tags = {
    "${local.tag_namespace_name}.Environment" = var.lz_environment
    "${local.tag_namespace_name}.Owner"       = var.service_label
    "${local.tag_namespace_name}.ManagedBy"   = "terraform"
    "${local.tag_namespace_name}.CostCenter"  = var.lz_cost_center
  }

  # ---------------------------------------------------------------------------
  # CANONICAL NAMES — C0/C1 HIERARCHY CONSTANTS
  # ===========================================================================
  # C0 = Tenancy Root — tag namespace and policies live here, no compartment
  # C1 = Level 1 compartments — all 10 TF-managed compartments
  # C2 = Level 2 sub-compartments — future, opt-in via enable_c2_compartments
  #
  # NAMING CONVENTION:
  #   Compartments : C<level>_<AGENCY>_ELZ_<FUNCTION>  e.g. C1_R_ELZ_NW
  #   Groups       : UG_ELZ_<FUNCTION>                  e.g. UG_ELZ_NW
  #   Policies     : UG_ELZ_<FUNCTION>-Policy           e.g. UG_ELZ_NW-Policy
  #   Tag namespace: C0-star-elz-v1                     (C0 = tenancy root)
  #   Tag keys     : PascalCase                          e.g. CostCenter
  #
  # WHY CONSTANTS NOT INTERPOLATION:
  #   service_label is kept for ORM display, tags, and descriptions only.
  #   Resource names follow STAR naming standards and must not drift with
  #   service_label changes. Constants = 2-hop trace. Interpolation = 4+ hops.
  #
  # SPRINT1-FIX: replaces coalesce(var.custom_*, "${var.service_label}-r-elz-nw-cmp")
  #              chains that produced lowercase hyphenated names inconsistent
  #              with STAR ELZ naming standard.
  # ===========================================================================

  # --- C0 Tag Namespace (tenancy root — singleton per tenancy) ---
  # SPRINT1-FIX: C0 prefix correctly identifies tenancy root scope.
  # Name is IMMUTABLE after creation — cannot be changed, only retired.
  tag_namespace_name = "C0-star-elz-v1"

  # --- C1 Compartment Names (Level 1, all at tenancy root by default) ---
  nw_compartment_name         = "C1_R_ELZ_NW"
  sec_compartment_name        = "C1_R_ELZ_SEC"
  soc_compartment_name        = "C1_R_ELZ_SOC"
  ops_compartment_name        = "C1_R_ELZ_OPS"
  csvcs_compartment_name      = "C1_R_ELZ_CSVCS"
  devt_csvcs_compartment_name = "C1_R_ELZ_DEVT_CSVCS"
  os_nw_compartment_name      = "C1_OS_ELZ_NW"
  ss_nw_compartment_name      = "C1_SS_ELZ_NW"
  ts_nw_compartment_name      = "C1_TS_ELZ_NW"
  devt_nw_compartment_name    = "C1_DEVT_ELZ_NW"

  # Override any C1 name via variables_iam.tf — null = use constant above
  # Pattern: provided_* = custom override OR canonical constant
  provided_nw_compartment_name         = coalesce(var.custom_nw_compartment_name, local.nw_compartment_name)
  provided_sec_compartment_name        = coalesce(var.custom_sec_compartment_name, local.sec_compartment_name)
  provided_soc_compartment_name        = coalesce(var.custom_soc_compartment_name, local.soc_compartment_name)
  provided_ops_compartment_name        = coalesce(var.custom_ops_compartment_name, local.ops_compartment_name)
  provided_csvcs_compartment_name      = coalesce(var.custom_csvcs_compartment_name, local.csvcs_compartment_name)
  provided_devt_csvcs_compartment_name = coalesce(var.custom_devt_csvcs_compartment_name, local.devt_csvcs_compartment_name)
  provided_os_nw_compartment_name      = coalesce(var.custom_os_nw_compartment_name, local.os_nw_compartment_name)
  provided_ss_nw_compartment_name      = coalesce(var.custom_ss_nw_compartment_name, local.ss_nw_compartment_name)
  provided_ts_nw_compartment_name      = coalesce(var.custom_ts_nw_compartment_name, local.ts_nw_compartment_name)
  provided_devt_nw_compartment_name    = coalesce(var.custom_devt_nw_compartment_name, local.devt_nw_compartment_name)

  # Opt-in enclosing compartment name (only relevant when enable_enclosing_compartment = true)
  enclosing_compartment_name = var.enclosing_compartment_name

  # Parent for all C1 compartments — tenancy root OR enclosing compartment
  # SPRINT1-FIX: conditional replaces hard dependency on iam_enclosing_compartment.tf
  parent_compartment_id = var.enable_enclosing_compartment ? oci_identity_compartment.enclosing[0].id : local.tenancy_id

  # --- C2 Sub-Compartment Names (Level 2 — opt-in, disabled by default) ---
  # Uncomment and populate children : {} in iam_cmps_team*.tf to activate.
  # Enable via ORM UI: Section 3 → Enable Level 2 Sub-Compartments = true
  # c2_soc_logs_name = "C2_SOC_LOGS"   # example — add to iam_cmps_team2.tf children
  # c2_os_app_name   = "C2_OS_APP"     # example — add to iam_cmps_team4.tf children
  # c2_os_db_name    = "C2_OS_DB"      # example — add to iam_cmps_team4.tf children

  # --- Group Names (tenancy-scoped, no C-level prefix) ---
  nw_group_name         = "UG_ELZ_NW"
  sec_group_name        = "UG_ELZ_SEC"
  soc_group_name_const  = "UG_ELZ_SOC"
  ops_group_name        = "UG_ELZ_OPS"
  csvcs_group_name      = "UG_ELZ_CSVCS"
  devt_csvcs_group_name = "UG_DEVT_CSVCS"
  os_nw_group_name      = "UG_OS_ELZ_NW"
  ss_nw_group_name      = "UG_SS_ELZ_NW"
  ts_nw_group_name      = "UG_TS_ELZ_NW"
  devt_nw_group_name    = "UG_DEVT_ELZ_NW"

  # --- Policy Names — derived from group names, not hardcoded separately ---
  # Pattern: "<group_name>-Policy"
  # All policies live at tenancy root (C0) — no Root/Admin suffix needed
  nw_policy_name           = "${local.nw_group_name}-Policy"
  sec_policy_name          = "${local.sec_group_name}-Policy"
  soc_policy_name          = "${local.soc_group_name_const}-Policy"
  ops_policy_name          = "${local.ops_group_name}-Policy"
  csvcs_policy_name        = "${local.csvcs_group_name}-Policy"
  devt_csvcs_policy_name   = "${local.devt_csvcs_group_name}-Policy"
  oci_services_policy_name = "OCI-SERVICES-Policy"

  # Per-spoke policies — 1:1 mapping: group → compartment → policy (architecture diagram)
  os_nw_policy_name   = "${local.os_nw_group_name}-Policy"
  ss_nw_policy_name   = "${local.ss_nw_group_name}-Policy"
  ts_nw_policy_name   = "${local.ts_nw_group_name}-Policy"
  devt_nw_policy_name = "${local.devt_nw_group_name}-Policy"
}
