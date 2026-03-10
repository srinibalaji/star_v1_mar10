# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — Sprint 2 Reference
# Read-only reference — no resources. Documents what Sprint 2 created
# and what Sprint 3 expects to exist before apply.
#
# Same pattern as sprint2/iam_sprint1_ref.tf.
# ─────────────────────────────────────────────────────────────

# Sprint 2 created these resources (now in Sprint 2 ORM state):
#
# VCNs (5):
#   vcn_r_elz_nw     (10.0.0.0/16)  — Hub
#   vcn_os_elz_nw    (10.1.0.0/24)  — OS spoke
#   vcn_ts_elz_nw    (10.3.0.0/24)  — TS spoke
#   vcn_ss_elz_nw    (10.2.0.0/24)  — SS spoke
#   vcn_devt_elz_nw  (10.4.0.0/24)  — DEVT spoke
#
# Subnets (6):
#   sub_r_elz_nw_fw     — Hub FW subnet
#   sub_r_elz_nw_mgmt   — Hub MGMT subnet
#   sub_os_elz_nw_app   — OS app subnet
#   sub_ts_elz_nw_app   — TS app subnet
#   sub_ss_elz_nw_app   — SS app subnet
#   sub_devt_elz_nw_app — DEVT app subnet
#
# DRGs (2):
#   drg_r_hub       — Primary hub DRG (5 VCN attachments)
#   drg_r_ew_hub    — E-W DRG placeholder (0 attachments in V1)
#
# DRG Attachments (5):
#   drga_r_elz_nw_hub  — Hub VCN → drg_r_hub
#   drga_os_elz_nw     — OS VCN → drg_r_hub
#   drga_ts_elz_nw     — TS VCN → drg_r_hub
#   drga_ss_elz_nw     — SS VCN → drg_r_hub
#   drga_devt_elz_nw   — DEVT VCN → drg_r_hub
#
# Route Tables (6):
#   rt_r_elz_nw_fw     — Hub FW subnet RT (Sprint 3 updates with spoke CIDRs)
#   rt_r_elz_nw_mgmt   — Hub MGMT subnet RT
#   rt_os_elz_nw_app   — OS spoke subnet RT (0/0 → DRG)
#   rt_ts_elz_nw_app   — TS spoke subnet RT (0/0 → DRG)
#   rt_ss_elz_nw_app   — SS spoke subnet RT (0/0 → DRG)
#   rt_devt_elz_nw_app — DEVT spoke subnet RT (0/0 → DRG)
#
# Security Lists (6):
#   sl_r_elz_nw_fw     — Hub FW (all from 10/8)
#   sl_r_elz_nw_mgmt   — Hub MGMT (all from 10/8)
#   sl_os_elz_nw_app   — OS spoke (all from 10/8)
#   sl_ts_elz_nw_app   — TS spoke (all from 10/8)
#   sl_ss_elz_nw_app   — SS spoke (all from 10/8)
#   sl_devt_elz_nw_app — DEVT spoke (all from 10/8)
#
# Sim FW Compute Instances (4):
#   fw_r_elz_nw_hub_sim  — Hub FW (ip_forward=1, MASQUERADE)
#   fw_os_elz_nw_sim     — OS spoke
#   fw_ts_elz_nw_sim     — TS spoke
#   fw_ss_elz_nw_sim     — SS spoke
#
# Bastion Service (1):
#   bas_r_elz_nw_hub    — OCI Bastion in Hub MGMT subnet
#
# Sprint 2 total: 38 resources (32 Phase 1+2 + 6 security lists)
#
# Sprint 3 MODIFIES (via oci_core_drg_attachment_management):
#   - 5 DRG attachments: adds drg_route_table_id
#   - Hub attachment: adds VCN ingress RT via network_details.route_table_id
#
# Sprint 3 CREATES (new resources in Sprint 3 state):
#   - 2 custom DRG route tables
#   - 1 DRG import distribution + 1 statement
#   - 1 static route rule (0/0 → Hub)
#   - 1 VCN ingress route table
#   - 1 Hub FW subnet RT (with spoke CIDRs + SG route)
#   - 1 Service Gateway
#   - 1 log group + 6 flow logs
#   - 1 Object Storage bucket
#   - 1 notification topic + 1 events rule + 1 alarm
#   - 2 Bastion sessions
#   Total: ~23 new resources
