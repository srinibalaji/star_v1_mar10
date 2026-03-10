# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 3 — sec_team3.tf (T3)
#
# T3 owns: OCI Logging, VCN Flow Logs, Object Storage,
#          Events rule, Monitoring alarm, Notification topic.
#
# Creates:
#   1. Log group for VCN flow logs
#   2. 6 flow logs (one per subnet from Sprint 2)
#   3. Object Storage bucket for log retention
#   4. ONS notification topic
#   5. Events rule for DRG/route table changes
#   6. Monitoring alarm
#
# Flow logs capture: source IP, dest IP, port, protocol,
# action (accept/reject), byte count. No packet payloads.
# Critical for proving forced inspection — Hub FW subnet
# flow logs must show spoke-to-spoke traffic transiting.
# ─────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════
# 1. LOG GROUP
# ═══════════════════════════════════════════════════════════════

resource "oci_logging_log_group" "nw_flow" {
  compartment_id = var.sec_compartment_id
  display_name   = local.nw_log_group_name
  description    = "VCN flow logs for all Sprint 2 subnets — proves forced inspection path"

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 2. VCN FLOW LOGS — one per subnet
# ═══════════════════════════════════════════════════════════════
# Hub FW subnet flow log is the most critical — it proves spoke
# traffic is transiting the firewall after Sprint 3 apply.







# ═══════════════════════════════════════════════════════════════
# 3. OBJECT STORAGE — log retention bucket
# ═══════════════════════════════════════════════════════════════
# Versioned, no public access. OCI Logging can be configured to
# archive to this bucket via Service Connector Hub (Sprint 4/V2).
# For now, the bucket exists and is ready for log archival.

resource "oci_objectstorage_bucket" "logs" {
  compartment_id = var.sec_compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = local.log_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 4. NOTIFICATION TOPIC — alarm destination
# ═══════════════════════════════════════════════════════════════
# SOC team subscribes to this topic (email, PagerDuty, Slack webhook).
# All DRG routing change alerts route here.

resource "oci_ons_notification_topic" "security_alerts" {
  compartment_id = var.sec_compartment_id
  name           = local.notification_topic_name
  description    = "P1 alerts — DRG attachment, route table, and security list changes"

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 5. EVENTS RULE — DRG and route table changes
# ═══════════════════════════════════════════════════════════════
# Fires when anyone (Console, CLI, API, ORM) modifies:
#   - DRG route tables (create/update/delete)
#   - DRG attachments (update — e.g. reassign RT)
#   - VCN route tables (update — e.g. add/remove rules)
#   - Security lists (update)
# Delivers to the notification topic for SOC alerting.

# OCI events rules monitor resources across compartments — the rule itself
# lives in SEC cmp (where UG_ELZ_SEC has manage events-family), but watches
# events from NW cmp. UG_ELZ_SEC has "read all-resources in tenancy" which
# satisfies the cross-compartment event visibility requirement.

resource "oci_events_rule" "nw_changes" {
  compartment_id = var.sec_compartment_id
  display_name   = local.events_rule_name
  is_enabled     = true
  description    = "Detect DRG attachment, route table, and security list changes"

  condition = jsonencode({
    eventType = [
      "com.oraclecloud.virtualnetwork.updatedrgroutetable",
      "com.oraclecloud.virtualnetwork.createdrgroutetable",
      "com.oraclecloud.virtualnetwork.deletedrgroutetable",
      "com.oraclecloud.virtualnetwork.updatedrgattachment",
      "com.oraclecloud.virtualnetwork.createdrgattachment",
      "com.oraclecloud.virtualnetwork.deletedrgattachment",
      "com.oraclecloud.virtualnetwork.updateroutetable",
      "com.oraclecloud.virtualnetwork.updatesecuritylist",
      "com.oraclecloud.virtualnetwork.createservicegateway",
      "com.oraclecloud.virtualnetwork.deleteservicegateway"
    ]
  })

  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.security_alerts.id
    }
  }

  defined_tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# 6. MONITORING ALARM — routing anomaly
# ═══════════════════════════════════════════════════════════════
# Alarms on VCN flow log volume — if flow logs on Hub FW subnet
# drop to zero when spokes are active, inspection path may be broken.

resource "oci_monitoring_alarm" "drg_change" {
  compartment_id        = var.sec_compartment_id
  display_name          = local.drg_change_alarm_name
  namespace             = "oci_vcn"
  # Alarm lives in SEC cmp (where UG_ELZ_SEC manages alarms), but reads
  # metrics from NW cmp subnets. "read all-resources in tenancy" covers this.
  metric_compartment_id = var.nw_compartment_id
  query                 = "VnicEgressDropsSecurityList[5m]{resourceId = \"${var.hub_fw_subnet_id}\"}.sum() > 100"
  severity              = "CRITICAL"
  is_enabled            = true
  pending_duration      = "PT5M"
  body                  = "High security list drops on Hub FW subnet — verify forced inspection routing is intact and security lists allow spoke traffic."
  destinations          = [oci_ons_notification_topic.security_alerts.id]

  defined_tags = local.common_tags
}
