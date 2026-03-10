# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — locals.tf
# Single source of truth for all Sprint 3 display names.
# Pattern: same as Sprint 1 (IAM) and Sprint 2 (networking).
# Rule: team files reference local.* only — never hardcode strings.
# ─────────────────────────────────────────────────────────────

locals {

  # Region mapping — needed by providers.tf for home_region
  regions_map     = { for r in data.oci_identity_regions.these.regions : r.key => r.name }
  home_region_key = data.oci_identity_tenancy.this.home_region_key
  # ── Tag namespace (from Sprint 1 — C0 = tenancy root) ──
  tag_namespace_name = "C0-star-elz-v1"

  # ── Common tags (applied to all Sprint 3 resources) ──
  common_tags = {
    "${local.tag_namespace_name}.Environment" = var.lz_environment
    "${local.tag_namespace_name}.Owner"       = var.service_label
  }

  # ── Forced Inspection — Custom DRG Route Tables (T4) ──
  hub_spoke_mesh_drgrt_name = "drgrt_r_hub_spoke_mesh"  # Hub attachment — import distribution
  spoke_to_hub_drgrt_name   = "drgrt_spoke_to_hub"      # Spoke attachments — static 0/0 → Hub
  hub_import_dist_name      = "drgrd_r_hub_vcn_import"  # Import distribution — auto-learn VCN CIDRs
  hub_ingress_rt_name       = "rt_r_elz_nw_hub_ingress" # VCN ingress RT on Hub DRG attachment

  # ── Service Gateway (T4) ──

  # ── Logging (T3) ──
  nw_log_group_name      = "lg_r_elz_nw_flow"
  hub_fw_flow_log_name   = "fl_r_elz_nw_fw"
  hub_mgmt_flow_log_name = "fl_r_elz_nw_mgmt"
  os_app_flow_log_name   = "fl_os_elz_nw_app"
  ts_app_flow_log_name   = "fl_ts_elz_nw_app"
  ss_app_flow_log_name   = "fl_ss_elz_nw_app"
  devt_app_flow_log_name = "fl_devt_elz_nw_app"

  # ── Object Storage (T3) ──
  log_bucket_name = "bkt_r_elz_sec_logs"

  # ── Events and Alarms (T3) ──
  notification_topic_name = "nt_r_elz_sec_alerts"
  events_rule_name        = "ev_r_elz_sec_nw_changes"
  drg_change_alarm_name   = "al_r_elz_sec_drg_change"

  # ── Bastion Sessions (T1, T2) ──
  bastion_session_os_name = "bsn_os_elz_nw_ssh"
  bastion_session_ts_name = "bsn_ts_elz_nw_ssh"

  # ── Vault and Encryption Keys (T3) ──
  vault_name      = "vlt_r_elz_sec"
  master_key_name = "key_r_elz_sec_master"

  # ── Cloud Guard (T3) ──
  cg_config_recipe_name   = "cgdr_r_elz_config"   # Configuration detector recipe (clone of Oracle-managed)
  cg_activity_recipe_name = "cgdr_r_elz_activity"  # Activity detector recipe (clone of Oracle-managed)
  cg_responder_recipe_name = "cgrr_r_elz_responder" # Responder recipe (clone of Oracle-managed)
  cg_target_name          = "cgt_r_elz_root"       # Cloud Guard target on enclosing/root compartment

  # ── Security Zones (T3) ──
  sz_recipe_sec_name = "szr_r_elz_sec"   # Custom recipe for SEC compartment
  sz_recipe_nw_name  = "szr_r_elz_nw"    # Custom recipe for NW compartment
  sz_sec_name        = "sz_r_elz_sec"     # Security zone on C1_R_ELZ_SEC
  sz_nw_name         = "sz_r_elz_nw"      # Security zone on C1_R_ELZ_NW
  hub_fw_nsg_name   = "nsg_r_elz_nw_fw"
  hub_mgmt_nsg_name = "nsg_r_elz_nw_mgmt"
  os_app_nsg_name   = "nsg_os_elz_nw_app"
  ts_app_nsg_name   = "nsg_ts_elz_nw_app"
  ss_app_nsg_name   = "nsg_ss_elz_nw_app"
  devt_app_nsg_name = "nsg_devt_elz_nw_app"
  vss_recipe_name = "vssr_r_elz_sec"
  vss_target_name = "vsst_r_elz_nw"
  sch_flow_to_bucket_name = "sch_r_elz_sec_flow_logs"
  cert_authority_name = "ca_r_elz_sec"
  ssh_key_secret_name = "ssh-public-key"
}
