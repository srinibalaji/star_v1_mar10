# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — sec_team3_security.tf (T3)
#
# T3 owns: OCI Vault (KMS), Cloud Guard detector/responder
#          recipes, Cloud Guard target, Security Zones.
#
# PREREQUISITE: Cloud Guard must be ENABLED in the tenancy
# before Security Zones can be created. Enable via:
#   OCI Console → Identity & Security → Cloud Guard → Enable
# or via Terraform:
#   oci_cloud_guard_cloud_guard_configuration (Sprint 1 scope)
#
# Creates:
#   1. KMS Vault (DEFAULT) in C1_R_ELZ_SEC
#   2. AES-256 master encryption key (HSM-protected)
#   3. Cloud Guard custom configuration detector recipe (clone)
#   4. Cloud Guard custom activity detector recipe (clone)
#   5. Cloud Guard target on enclosing compartment
#   6. Custom security zone recipe for SEC compartment
#   7. Custom security zone recipe for NW compartment
#   8. Security zone on C1_R_ELZ_SEC
#   9. Security zone on C1_R_ELZ_NW
#
# IAM requirements (all exist in Sprint 1 UG_ELZ_SEC-Policy):
#   - manage vaults in compartment C1_R_ELZ_SEC          ✅
#   - manage keys in compartment C1_R_ELZ_SEC             ✅
#   - manage cloud-guard-family in tenancy                ✅
# IAM additions needed (Sprint 1 patch — see README):
#   - manage security-zone in compartment C1_R_ELZ_SEC    ⚡
#   - manage security-zone in compartment C1_R_ELZ_NW     ⚡
# ─────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════
# 1. OCI VAULT (KMS) — centralised key management
# ═══════════════════════════════════════════════════════════════
# DEFAULT vault type — shared HSM partition, no monthly cost.
# VIRTUAL_PRIVATE vault is available for FIPS 140-2 Level 3
# dedicated HSM (recommended for production / IM8 compliance)
# but requires a paid subscription.
#
# The vault OCID is needed by:
#   - Object Storage (bucket encryption)
#   - Block Volume (boot/data volume encryption)
#   - Database (TDE key management)
#   - Secrets (credential storage)

resource "oci_kms_vault" "sec" {
  compartment_id = var.sec_compartment_id
  display_name   = local.vault_name
  vault_type     = "DEFAULT"

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 2. MASTER ENCRYPTION KEY — AES-256, HSM-protected
# ═══════════════════════════════════════════════════════════════
# This key is the root of the encryption hierarchy. OCI services
# use it as a customer-managed key (CMK) for envelope encryption.
# HSM protection mode means the key never leaves the HSM in
# plaintext — the HSM performs all crypto operations.
#
# key_shape: AES 256-bit is the standard for sovereign/defence.
# protection_mode: HSM (not SOFTWARE) for IM8/MTCS compliance.

resource "oci_kms_key" "master" {
  compartment_id      = var.sec_compartment_id
  display_name        = local.master_key_name
  management_endpoint = oci_kms_vault.sec.management_endpoint
  protection_mode     = "HSM"

  key_shape {
    algorithm = "AES"
    length    = 32  # 256-bit
  }

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 3. CLOUD GUARD — Custom Detector Recipes (cloned from Oracle)
# ═══════════════════════════════════════════════════════════════
# We clone Oracle-managed recipes so we can customise rules
# (enable/disable specific detectors, tune risk levels) without
# affecting the tenancy default. Cloned recipes are mutable.
#
# Configuration detector: scans resources for misconfigurations
#   (public buckets, open security lists, unencrypted volumes, etc.)
# Activity detector: monitors user and service API activity
#   (suspicious logins, privilege escalation, data exfiltration, etc.)

resource "oci_cloud_guard_detector_recipe" "config" {
  compartment_id            = var.sec_compartment_id
  display_name              = local.cg_config_recipe_name
  description               = "STAR ELZ configuration detector recipe — cloned from Oracle-managed"
  source_detector_recipe_id = try(data.oci_cloud_guard_detector_recipes.oracle_config.detector_recipe_collection[0].items[0].id, "")

  defined_tags = local.common_tags
}

resource "oci_cloud_guard_detector_recipe" "activity" {
  compartment_id            = var.sec_compartment_id
  display_name              = local.cg_activity_recipe_name
  description               = "STAR ELZ activity detector recipe — cloned from Oracle-managed"
  source_detector_recipe_id = try(data.oci_cloud_guard_detector_recipes.oracle_activity.detector_recipe_collection[0].items[0].id, "")

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 4. CLOUD GUARD — Custom Responder Recipe
# ═══════════════════════════════════════════════════════════════
# Responder recipes define automated actions when Cloud Guard
# detects a problem (e.g., disable public access on a bucket,
# terminate a non-compliant instance). Clone to customise.

resource "oci_cloud_guard_responder_recipe" "responder" {
  compartment_id             = var.sec_compartment_id
  display_name               = local.cg_responder_recipe_name
  description                = "STAR ELZ responder recipe — cloned from Oracle-managed"
  source_responder_recipe_id = try(data.oci_cloud_guard_responder_recipes.oracle_responder.responder_recipe_collection[0].items[0].id, "")

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 5. CLOUD GUARD TARGET — monitor the enclosing compartment
# ═══════════════════════════════════════════════════════════════
# The target tells Cloud Guard what compartment hierarchy to
# monitor. Setting it on the enclosing compartment (or tenancy
# root) covers all child compartments (NW, SEC, SOC, spokes).
#
# NOTE: If an existing Cloud Guard target already covers this
# compartment, this resource will fail. Check in Console:
#   Identity & Security → Cloud Guard → Targets
# If a root target exists, import it or skip this resource.

resource "oci_cloud_guard_target" "root" {
  compartment_id       = var.tenancy_ocid
  display_name         = local.cg_target_name
  target_resource_id   = var.tenancy_ocid
  target_resource_type = "COMPARTMENT"
  description          = "STAR ELZ Cloud Guard target — monitors entire tenancy"

  target_detector_recipes {
    detector_recipe_id = oci_cloud_guard_detector_recipe.config.id
  }

  target_detector_recipes {
    detector_recipe_id = oci_cloud_guard_detector_recipe.activity.id
  }

  target_responder_recipes {
    responder_recipe_id = oci_cloud_guard_responder_recipe.responder.id
  }

  defined_tags = local.common_tags

  # Cloud Guard targets are long-lived — prevent accidental destroy
  lifecycle {
    prevent_destroy = true
  }
}

# ═══════════════════════════════════════════════════════════════
# 6. SECURITY ZONE RECIPES — custom policies per compartment
# ═══════════════════════════════════════════════════════════════
# Security zones prevent insecure resource creation at deploy time.
# We use CUSTOM recipes (not Oracle Maximum Security) so we can
# select policies appropriate for each compartment's workload.
#
# SEC compartment recipe — strict (Vault, encryption, no public):
#   - Deny public buckets
#   - Deny unencrypted volumes
#   - Deny unencrypted databases
#   - Require customer-managed keys
#
# NW compartment recipe — network-focused:
#   - Deny public subnets
#   - Deny internet gateways
#   - Deny public IP on VNICs
#
# Security zone policies are identified by ID. We use the
# data source to look up available policies, then hardcode
# the well-known policy OCIDs in the recipe. These OCIDs
# are stable across all OCI regions.

resource "oci_cloud_guard_security_recipe" "sec" {
  compartment_id = var.sec_compartment_id
  display_name   = local.sz_recipe_sec_name
  description    = "STAR ELZ security zone recipe for SEC compartment — encryption and data protection"

  # CIS Level 2 policies for data-at-rest protection
  security_policies = [
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaanmfcy3ekrk3fwpgw7lqm6yixjag3nqpbtmaqu6gdbzmiq3mkuwja",  # Deny public Object Storage buckets
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaadfiuhqyg6aq45ipe5z5id5evlh4qer3f4woqlqfmn7kkpfvnhkfq",  # Deny boot volumes without Vault key
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaairps4kt5zetdnkci2tjsim3g3zxqn5pe3ficbjjs3bfpemhyjn2q",  # Deny block volumes without Vault key
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaap3gu7gfzee5kfkbjuawq7kcmurij26d6qg2xvlwlxlmp3recpdma",  # Deny databases without Vault key
  ]

  defined_tags = local.common_tags
}

resource "oci_cloud_guard_security_recipe" "nw" {
  compartment_id = var.sec_compartment_id
  display_name   = local.sz_recipe_nw_name
  description    = "STAR ELZ security zone recipe for NW compartment — network isolation"

  # CIS Level 1 policies for network isolation
  security_policies = [
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaafzsg2q6ftpzpqqoakl5fhgvqjf4puqxfhfwn4zwhh4vylp7b6oka",  # Deny public subnets
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaayrwlr3fvcbfat3rl2vb2ocvvvrxq2yhsfawbv7mwppk5xo7uxozia",  # Deny internet gateways
    "ocid1.securityzonessecuritypolicy.oc1..aaaaaaaasdqhvi7iy4fvthds3zdjf6u2nl2h7g53rvc37icfh2kikp7u2cr6a",  # Deny public IP on VNICs
  ]

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 7. SECURITY ZONES — enforce recipes on compartments
# ═══════════════════════════════════════════════════════════════
# Once applied, any resource creation that violates the recipe
# is blocked at API level. This is preventive — not detective.
#
# IMPORTANT: A compartment can only have ONE security zone.
# If an existing zone is already on the compartment, Terraform
# will fail. Check:
#   Identity & Security → Security Zones → Overview

resource "oci_cloud_guard_security_zone" "sec" {
  compartment_id             = var.sec_compartment_id
  display_name               = local.sz_sec_name
  description                = "Security zone on C1_R_ELZ_SEC — enforces encryption and data protection"
  security_zone_recipe_id    = oci_cloud_guard_security_recipe.sec.id

  defined_tags = local.common_tags
}

resource "oci_cloud_guard_security_zone" "nw" {
  compartment_id             = var.nw_compartment_id
  display_name               = local.sz_nw_name
  description                = "Security zone on C1_R_ELZ_NW — enforces network isolation (no public subnets, no IGW)"
  security_zone_recipe_id    = oci_cloud_guard_security_recipe.nw.id

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# SSH KEY VAULT SECRET — stores the SSH public key in Vault
# ═══════════════════════════════════════════════════════════════
# Defence-in-depth: SSH key stored in Vault alongside instance metadata.
# Production pattern: reference via data source instead of plain variable.
# V1 POC: both var.ssh_public_key and Vault secret contain the same key.

resource "oci_vault_secret" "ssh_public_key" {
  compartment_id = var.sec_compartment_id
  vault_id       = oci_kms_vault.sec.id
  key_id         = oci_kms_key.master.id
  secret_name    = "ssh-public-key"
  description    = "SSH public key for Sim FW instances — matches instance metadata ssh_authorized_keys"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.ssh_public_key)
  }

  defined_tags = local.common_tags
}
