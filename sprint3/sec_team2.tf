# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — sec_team2.tf (T2)
#
# T2 owns: Bastion session (TS), Hub MGMT + TS + SS + DEVT NSGs,
#          Flow logs (hub_mgmt + TS + SS + DEVT),
#          Certificate Authority (V2 readiness)
#
# Rebalanced from T3 to spread workload evenly.
# ─────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════
# 1. BASTION SESSION — TS Sim FW
# ═══════════════════════════════════════════════════════════════

# Cross-VCN bastion sessions are NOT supported by OCI.
# See sec_team1.tf for full documentation.
# Validation: Hub Bastion → Hub FW → ssh opc@10.3.0.x (TS spoke)

# resource "oci_bastion_session" "ts_ssh" {
#   # COMMENTED OUT — cross-VCN not supported. Use Console session to Hub FW instead.
# }

# ═══════════════════════════════════════════════════════════════
# 2. NSGs — Hub MGMT + TS + SS + DEVT spokes
# ═══════════════════════════════════════════════════════════════

resource "oci_core_network_security_group" "hub_mgmt" {
  compartment_id = var.nw_compartment_id
  vcn_id         = var.hub_vcn_id
  display_name   = local.hub_mgmt_nsg_name
  defined_tags   = local.common_tags
}

resource "oci_core_network_security_group_security_rule" "hub_mgmt_ingress" {
  network_security_group_id = oci_core_network_security_group.hub_mgmt.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/8"
  source_type               = "CIDR_BLOCK"
  description               = "Allow all internal"
}

resource "oci_core_network_security_group_security_rule" "hub_mgmt_egress" {
  network_security_group_id = oci_core_network_security_group.hub_mgmt.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all egress"
}

resource "oci_core_network_security_group" "ts_app" {
  compartment_id = var.ts_compartment_id
  vcn_id         = var.ts_vcn_id
  display_name   = local.ts_app_nsg_name
  defined_tags   = local.common_tags
}

resource "oci_core_network_security_group_security_rule" "ts_ingress" {
  network_security_group_id = oci_core_network_security_group.ts_app.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/8"
  source_type               = "CIDR_BLOCK"
  description               = "Allow all internal"
}

resource "oci_core_network_security_group_security_rule" "ts_egress" {
  network_security_group_id = oci_core_network_security_group.ts_app.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all egress"
}

resource "oci_core_network_security_group" "ss_app" {
  compartment_id = var.ss_compartment_id
  vcn_id         = var.ss_vcn_id
  display_name   = local.ss_app_nsg_name
  defined_tags   = local.common_tags
}

resource "oci_core_network_security_group_security_rule" "ss_ingress" {
  network_security_group_id = oci_core_network_security_group.ss_app.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/8"
  source_type               = "CIDR_BLOCK"
  description               = "Allow all internal"
}

resource "oci_core_network_security_group_security_rule" "ss_egress" {
  network_security_group_id = oci_core_network_security_group.ss_app.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all egress"
}

resource "oci_core_network_security_group" "devt_app" {
  compartment_id = var.devt_compartment_id
  vcn_id         = var.devt_vcn_id
  display_name   = local.devt_app_nsg_name
  defined_tags   = local.common_tags
}

resource "oci_core_network_security_group_security_rule" "devt_ingress" {
  network_security_group_id = oci_core_network_security_group.devt_app.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/8"
  source_type               = "CIDR_BLOCK"
  description               = "Allow all internal"
}

resource "oci_core_network_security_group_security_rule" "devt_egress" {
  network_security_group_id = oci_core_network_security_group.devt_app.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all egress"
}

# ═══════════════════════════════════════════════════════════════
# 3. FLOW LOGS — Hub MGMT + TS + SS + DEVT subnets
# ═══════════════════════════════════════════════════════════════

resource "oci_logging_log" "hub_mgmt_flow" {
  display_name = local.hub_mgmt_flow_log_name
  log_group_id = oci_logging_log_group.nw_flow.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "all"
      resource    = var.hub_mgmt_subnet_id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.nw_compartment_id
  }

  is_enabled = true
}

resource "oci_logging_log" "ts_app_flow" {
  display_name = local.ts_app_flow_log_name
  log_group_id = oci_logging_log_group.nw_flow.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "all"
      resource    = var.ts_app_subnet_id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.ts_compartment_id
  }

  is_enabled = true
}

resource "oci_logging_log" "ss_app_flow" {
  display_name = local.ss_app_flow_log_name
  log_group_id = oci_logging_log_group.nw_flow.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "all"
      resource    = var.ss_app_subnet_id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.ss_compartment_id
  }

  is_enabled = true
}

resource "oci_logging_log" "devt_app_flow" {
  display_name = local.devt_app_flow_log_name
  log_group_id = oci_logging_log_group.nw_flow.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "all"
      resource    = var.devt_app_subnet_id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    compartment_id = var.devt_compartment_id
  }

  is_enabled = true
}

# ═══════════════════════════════════════════════════════════════
# 4. CERTIFICATE AUTHORITY — V2 readiness
# ═══════════════════════════════════════════════════════════════
# OCI Certificates service — creates a private CA in SEC compartment.
# V1 has no HTTPS endpoints (no IGW, no LB). This CA is provisioned
# for Sprint 4+ when Load Balancers or API Gateways are added.
# The CA itself is free — certificates issued from it are the cost.

resource "oci_certificates_management_certificate_authority" "sec" {
  compartment_id = var.sec_compartment_id
  name           = local.cert_authority_name

  certificate_authority_config {
    config_type = "ROOT_CA_GENERATED_INTERNALLY"
    subject {
      common_name         = "STAR ELZ V1 Root CA"
      organization        = "STAR"
      country             = "SG"
      organizational_unit = "CSS"
    }
    signing_algorithm = "SHA256_WITH_RSA"
  }

  kms_key_id = oci_kms_key.master.id

  certificate_authority_rules {
    rule_type                         = "CERTIFICATE_AUTHORITY_ISSUANCE_EXPIRY_RULE"
    certificate_authority_max_validity_duration = "P3650D"
    leaf_certificate_max_validity_duration      = "P365D"
  }

  defined_tags = local.common_tags

  depends_on = [oci_kms_key.master]
}
