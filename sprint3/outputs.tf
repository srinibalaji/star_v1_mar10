# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — Outputs
# Sprint 4 (Compute) needs these for AD Bridge, DNS, Hello World.
# ─────────────────────────────────────────────────────────────

# ── DRG Route Tables ──
output "hub_spoke_mesh_drgrt_id" {
  description = "OCID of drgrt_r_hub_spoke_mesh (Hub DRG RT with import distribution)"
  value       = oci_core_drg_route_table.hub_spoke_mesh.id
}

output "spoke_to_hub_drgrt_id" {
  description = "OCID of drgrt_spoke_to_hub (Spoke DRG RT with static 0/0 → Hub)"
  value       = oci_core_drg_route_table.spoke_to_hub.id
}

# ── Service Gateway ──

# ── Logging ──
output "nw_log_group_id" {
  description = "OCID of lg_r_elz_nw_flow log group"
  value       = oci_logging_log_group.nw_flow.id
}

# ── Object Storage ──
output "log_bucket_name" {
  description = "Name of bkt_r_elz_sec_logs bucket"
  value       = oci_objectstorage_bucket.logs.name
}

# ── Notifications ──
output "security_alerts_topic_id" {
  description = "OCID of nt_r_elz_sec_alerts notification topic"
  value       = oci_ons_notification_topic.security_alerts.id
}

# ── VCN Ingress RT ──
output "hub_ingress_rt_id" {
  description = "OCID of rt_r_elz_nw_hub_ingress (VCN ingress RT on Hub DRG attachment)"
  value       = oci_core_route_table.hub_ingress.id
}

# ── Vault (KMS) ──
output "vault_id" {
  description = "OCID of vlt_r_elz_sec Vault"
  value       = oci_kms_vault.sec.id
}

output "vault_management_endpoint" {
  description = "Management endpoint for vlt_r_elz_sec Vault"
  value       = oci_kms_vault.sec.management_endpoint
}

output "vault_crypto_endpoint" {
  description = "Crypto endpoint for vlt_r_elz_sec Vault (encrypt/decrypt operations)"
  value       = oci_kms_vault.sec.crypto_endpoint
}

output "master_key_id" {
  description = "OCID of key_r_elz_sec_master AES-256 master encryption key"
  value       = oci_kms_key.master.id
}

# ── Cloud Guard ──
output "cg_target_id" {
  description = "OCID of Cloud Guard target on tenancy root"
  value       = oci_cloud_guard_target.root.id
}

output "cg_config_recipe_id" {
  description = "OCID of custom configuration detector recipe"
  value       = oci_cloud_guard_detector_recipe.config.id
}

# ── Security Zones ──
output "sz_sec_id" {
  description = "OCID of security zone on C1_R_ELZ_SEC"
  value       = oci_cloud_guard_security_zone.sec.id
}

output "sz_nw_id" {
  description = "OCID of security zone on C1_R_ELZ_NW"
  value       = oci_cloud_guard_security_zone.nw.id
}

# NSGs
output "hub_fw_nsg_id" {
  description = "OCID of Hub FW NSG."
  value       = oci_core_network_security_group.hub_fw.id
}

output "os_app_nsg_id" {
  description = "OCID of OS app NSG."
  value       = oci_core_network_security_group.os_app.id
}

# VSS
output "vss_recipe_id" {
  description = "OCID of VSS host scan recipe."
  value       = var.enable_vss ? oci_vulnerability_scanning_host_scan_recipe.standard[0].id : null
}

# SCH
output "sch_flow_to_bucket_id" {
  description = "OCID of Service Connector Hub (flow logs → bucket)."
  value       = oci_sch_service_connector.flow_to_bucket.id
}

# Certificate Authority
output "cert_authority_id" {
  description = "OCID of root Certificate Authority."
  value       = oci_certificates_management_certificate_authority.sec.id
}

# Vault SSH Key Secret
output "ssh_key_vault_secret_id" {
  description = "OCID of SSH public key stored in Vault."
  value       = oci_vault_secret.ssh_public_key.id
}
