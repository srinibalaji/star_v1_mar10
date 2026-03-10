# STAR ELZ V1 — Sprint 2 Outputs
# After Phase 2: terraform output -json > sprint2_outputs.json

# ── Phase 1 ──

output "hub_drg_id" {
  description = "Hub DRG OCID. Share with all teams for Phase 2."
  value       = oci_core_drg.hub.id
}

output "ew_hub_drg_id" {
  description = "E-W DRG OCID (V2 placeholder)."
  value       = oci_core_drg.ew_hub.id
}

output "hub_vcn_id"  { value = oci_core_vcn.hub.id }
output "os_vcn_id"   { value = oci_core_vcn.os.id }
output "ts_vcn_id"   { value = oci_core_vcn.ts.id }
output "ss_vcn_id"   { value = oci_core_vcn.ss.id }
output "devt_vcn_id" { value = oci_core_vcn.devt.id }

output "hub_fw_subnet_id"   { value = oci_core_subnet.hub_fw.id }
output "hub_mgmt_subnet_id" { value = oci_core_subnet.hub_mgmt.id }
output "os_app_subnet_id"   { value = oci_core_subnet.os_app.id }
output "ts_app_subnet_id"   { value = oci_core_subnet.ts_app.id }
output "ss_app_subnet_id"   { value = oci_core_subnet.ss_app.id }
output "devt_app_subnet_id" { value = oci_core_subnet.devt_app.id }

output "hub_fw_rt_id" {
  description = "Hub FW Route Table OCID. Sprint 3 imports and adds spoke CIDRs."
  value       = oci_core_route_table.hub_fw.id
}

# ── Phase 2 ──

output "hub_bastion_id" {
  value = length(oci_bastion_bastion.hub) > 0 ? oci_bastion_bastion.hub[0].id : "phase2-not-applied"
}

output "sim_fw_hub_id" {
  value = length(oci_core_instance.sim_fw_hub) > 0 ? oci_core_instance.sim_fw_hub[0].id : "phase2-not-applied"
}
output "sim_fw_os_id" {
  value = length(oci_core_instance.sim_fw_os) > 0 ? oci_core_instance.sim_fw_os[0].id : "phase2-not-applied"
}
output "sim_fw_ts_id" {
  value = length(oci_core_instance.sim_fw_ts) > 0 ? oci_core_instance.sim_fw_ts[0].id : "phase2-not-applied"
}
output "sim_fw_ss_id" {
  value = length(oci_core_instance.sim_fw_ss) > 0 ? oci_core_instance.sim_fw_ss[0].id : "phase2-not-applied"
}

output "hub_drg_attachment_id" {
  value = length(oci_core_drg_attachment.hub_vcn) > 0 ? oci_core_drg_attachment.hub_vcn[0].id : "phase2-not-applied"
}
output "os_drg_attachment_id" {
  value = length(oci_core_drg_attachment.os) > 0 ? oci_core_drg_attachment.os[0].id : "phase2-not-applied"
}
output "ts_drg_attachment_id" {
  value = length(oci_core_drg_attachment.ts) > 0 ? oci_core_drg_attachment.ts[0].id : "phase2-not-applied"
}
output "ss_drg_attachment_id" {
  value = length(oci_core_drg_attachment.ss) > 0 ? oci_core_drg_attachment.ss[0].id : "phase2-not-applied"
}
output "devt_drg_attachment_id" {
  value = length(oci_core_drg_attachment.devt) > 0 ? oci_core_drg_attachment.devt[0].id : "phase2-not-applied"
}

output "hub_fw_private_ip_address" {
  description = <<-DESC
    Hub Sim FW private IP ADDRESS (e.g. 10.0.0.x).
    Sprint 3 needs the private IP OCID, not this address. After Phase 2 apply, run:
      oci network private-ip list --subnet-id <hub_fw_subnet_id> \
        --ip-address $(terraform output -raw hub_fw_private_ip_address) \
        --query 'data[0].id' --raw-output
    Paste the ocid1.privateip... into Sprint 3 ORM as hub_fw_private_ip_id.
    Wrong value = all spoke-to-spoke traffic black-holes silently.
  DESC
  value = length(oci_core_instance.sim_fw_hub) > 0 ? oci_core_instance.sim_fw_hub[0].private_ip : "phase2-not-applied"
}
