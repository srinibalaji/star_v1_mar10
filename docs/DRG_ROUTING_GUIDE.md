# OCI DRG v2 Routing — Definitive Guide for STAR ELZ V1

**Date:** 2 March 2026 | **Owner:** Principal Architect | **Classification:** Confidential

---

## Diagrams

### Diagram A — Sprint 2: Full-Mesh Connectivity (Current State)

```
                        ┌─────────────────────────────────────────────┐
                        │              drg_r_hub                      │
                        │                                             │
                        │  ┌─────────────────────────────────────┐    │
                        │  │  DRG Route Table                    │    │
                        │  │  (auto-generated OR custom import)  │    │
                        │  │                                     │    │
                        │  │  10.0.0.0/16 → Hub VCN attachment   │    │
                        │  │  10.1.0.0/24 → OS  VCN attachment   │    │
                        │  │  10.2.0.0/24 → SS  VCN attachment   │    │
                        │  │  10.3.0.0/24 → TS  VCN attachment   │    │
                        │  │  10.4.0.0/24 → DEVT VCN attachment  │    │
                        │  └─────────────────────────────────────┘    │
                        │                                             │
                        │  [1]       [2]      [3]      [4]      [5]  │
                        └───┬────────┬────────┬────────┬────────┬────┘
                            │        │        │        │        │
                    ┌───────┘    ┌───┘    ┌───┘    ┌───┘    ┌───┘
                    │            │        │        │        │
              ┌─────┴─────┐ ┌───┴───┐ ┌──┴──┐ ┌──┴──┐ ┌───┴───┐
              │  Hub VCN  │ │  OS   │ │ SS  │ │ TS  │ │ DEVT  │
              │ 10.0/16   │ │10.1/24│ │10.2 │ │10.3 │ │10.4/24│
              │ FW + MGMT │ │  /24  │ │ /24 │ │ /24 │ │       │
              └───────────┘ └───────┘ └─────┘ └─────┘ └───────┘

  [1]-[5] = DRG Attachments. All use same DRG Route Table (full-mesh).
  All subnet RTs: 0/0 → drg_r_hub. Traffic: OS → DRG → TS direct. No firewall.
```

### Diagram B — Sprint 3: Forced Inspection via Hub Firewall

```
① OS App Subnet        — VM sends packet to 10.3.0.x (TS)
│
② Subnet RT            — 0/0 → drg_r_hub
│
③ DRG (Spoke DRG RT)   — 0/0 → Hub VCN attachment (overrides full-mesh)
│
④ Hub VCN Ingress RT   — 0.0.0.0/0 → next-hop FW VNIC private IP
│
⑤ Hub FW Subnet        — Firewall inspects and forwards
│
⑥ Hub FW Subnet RT     — 10.0.0.0/8 → drg_r_hub
│
⑦ DRG (Hub DRG RT)     — 10.3.0.0/24 → TS VCN attachment (import distribution)(use the auto-generated drg attachement for VCN attachments - Created by default when you create a DRG)
│
⑧ TS App Subnet        — Packet delivered

5 route table lookups: Subnet RT (②), Spoke DRG RT (③), VCN Ingress RT (④),
FW Subnet RT (⑥), Hub DRG RT (⑦). Each does one job.

Sprint 3 Terraform — the static route that breaks full-mesh and forces inspection:
  resource "oci_core_drg_route_table_route_rule" "force_hub" {
    drg_route_table_id         = oci_core_drg_route_table.spoke_to_hub.id
    destination_type           = "CIDR_BLOCK"
    destination                = "0.0.0.0/0"
    next_hop_drg_attachment_id = oci_core_drg_attachment.hub_vcn[0].id
  }
```

### Diagram C — DRG-per-Tenancy (SCCA / Multi-Classification)

```
PARENT TENANCY (Transit)
├── Transit VCN → NGFW (all inter-tenancy traffic inspected)
└── DRG-T (Transit)
    ├── VCN attachment → Transit VCN
    ├── RPC → DRG-A (static or BGP: 10.10.0.0/16 only)
    └── RPC → DRG-B (static or BGP: 10.20.0.0/16 only)

CHILD TENANCY A                        CHILD TENANCY B
├── App VCN A (10.10.0.0/16)           ├── App VCN B (10.20.0.0/16)
└── DRG-A (isolated, own TF state)     └── DRG-B (isolated, own TF state)
    └── RPC → DRG-T                        └── RPC → DRG-T

DRG-A and DRG-B cannot reach each other directly. All traffic via NGFW.
Alternative: child VCN attaches directly to parent DRG (cross-tenancy VCN attachment)
  — parent controls all routing, child has no independent DRG. Use when parent must own routing.
```

### Diagram D — DRG-per-Compartment (Intra-Tenancy Isolation)

```
C1_R_ELZ_NW (Hub)
├── Transit VCN → Firewall
└── DRG-Hub (NW admin only)
    ├── RPC → DRG-OS
    ├── RPC → DRG-SS
    └── RPC → DRG-TS

C1_OS_ELZ_NW                C1_SS_ELZ_NW                C1_TS_ELZ_NW
├── VCN OS (10.1/24)        ├── VCN SS (10.2/24)        ├── VCN TS (10.3/24)
└── DRG-OS → RPC → Hub     └── DRG-SS → RPC → Hub     └── DRG-TS → RPC → Hub
    IAM: UG_OS only             IAM: UG_SS only             IAM: UG_TS only

Each compartment owns its DRG and routing decisions.
Sprint 2/3 uses shared hub DRG (Diagram A/B). V2 transitions to combined C+D model.
```

---

## 1. Three Route Table Types

| Role | Terraform Resource | Attached To | When It Acts |
|---|---|---|---|
| Subnet RT | `oci_core_route_table` | Subnet | Egress from subnet |
| DRG RT | `oci_core_drg_route_table` | DRG attachment | Forwarding inside DRG |
| VCN Ingress RT | `oci_core_route_table` | DRG attachment (`network_details`) | Ingress into VCN from DRG |

Subnet RT and VCN Ingress RT are the same resource type — the difference is where you attach them.

## 2. Auto-Generated vs Custom DRG Route Table

A DRG attachment created without `drg_route_table_id` gets an OCI auto-generated default DRG route table. It provides full-mesh but is invisible to Terraform. For auditability, create a custom DRG route table with `import_drg_route_distribution_id` and assign it at attachment creation. Same full-mesh, but in your Terraform state. Sprint 3 creates a second DRG route table (`spoke_to_hub` with a static `0/0 → Hub` route) and reassigns spoke attachments to it — the original `hub_spoke_mesh` RT stays on the hub attachment. No destroy/recreate needed.

```hcl
# Sprint 2 — custom DRG RT replaces auto-generated, same full-mesh behaviour
resource "oci_core_drg_route_table" "hub_spoke_mesh" {
  drg_id                           = oci_core_drg.hub.id
  display_name                     = "drgrt_r_hub_spoke_mesh"
  import_drg_route_distribution_id = oci_core_drg_route_distribution.hub_vcn_import.id
}

# Assign at attachment creation — auto-generated table never created
resource "oci_core_drg_attachment" "os" {
  drg_id             = var.hub_drg_id
  drg_route_table_id = oci_core_drg_route_table.hub_spoke_mesh.id  # ← this line
  network_details { id = oci_core_vcn.os.id; type = "VCN" }
}
```

## 3. Sprint Progression

| Component | Sprint 2 | Sprint 3 | V2 (Child Tenancy) | V3 (Isolated Region) |
|---|---|---|---|---|
| DRG RT | Auto or custom import | Custom + static to Hub | Per trust-zone DRG RT | + static or BGP from IPsec/FC |
| Firewall | Sim FW (test endpoints) | Sim FW (transit routing) | OCI Network Firewall | Network FW or certified NGFW |
| Security | Default security lists | NSGs + tightened SLs | NSGs only, default-deny | NSGs, zero-trust, Cloud Guard |
| DRG Model | Shared hub (Diagram A) | Shared hub (Diagram B) | DRG-per-compartment + per-tenancy (Diagram C+D) | Same — single region deployment |
| State | ORM single state | ORM single state | 1 state per tenancy | Air-gapped ORM per tenancy |
| Region | ap-singapore-2 (public) | ap-singapore-2 | ap-singapore-2 | Isolated region (same architecture, air-gapped) |

**Architecture direction confirmed:** V2 onwards will use both DRG-per-compartment and DRG-per-tenancy. Parent tenancy compartments will each have their own DRG (Diagram D). Child tenancies will have their own DRGs with VCN attachments scoped to the child's isolation and performance requirements (Diagram C). Parent-to-child connectivity is via RPC between DRGs (each tenancy retains routing control) or via cross-tenancy VCN attachment to the parent DRG (parent controls all routing — requires Endorse/Admit IAM). The choice depends on whether the child requires independent routing decisions. This is a single-region deployment — V3/V4/V5 in the isolated region uses the same topology, not multi-region.

## 4. OCI Network Firewall — Replacing Sim FW (V2/V3)

Sprint 2/3 use Sim FW (OL8 + iptables) because it works in any region with no service dependencies. OCI Network Firewall (managed PaaS) replaces it in V2/V3. The DRG routing stays identical — custom DRG route table forces spoke traffic to Hub VCN, VCN ingress route table sends to firewall subnet. The next-hop changes from Sim FW VNIC IP to Network Firewall forwarding IP. Network Firewall additionally requires a `oci_network_firewall_network_firewall_policy` resource defining inspection rules (URL filtering, intrusion detection, application-level controls) and may require a larger subnet CIDR for the firewall's internal load balancing. Network Firewall provides L3-L7 inspection, integrated threat and traffic logging to OCI Logging/Cloud Guard, and built-in regional HA without manual VRRP. The VCN topology, DRG attachments, and route table structure from Sprint 2/3 carry forward unchanged.

```hcl
# V2/V3 — replaces oci_core_instance.sim_fw_hub
resource "oci_network_firewall_network_firewall" "hub" {
  compartment_id             = var.nw_compartment_id
  subnet_id                  = oci_core_subnet.hub_fw.id
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.hub.id
  display_name               = "nfw_r_elz_nw_hub"
}

# VCN Ingress RT next-hop changes — Sim FW VNIC IP → Network FW IP
# oci_network_firewall_network_firewall.hub.ip_address_details[0].ip_address
```

## 5. SD-WAN and Hybrid Connectivity (V3)

DRGv2 supports IPsec VPN and FastConnect attachments alongside VCN attachments on the same DRG. For hybrid connectivity in the isolated region, IPsec tunnels or FastConnect virtual circuits (MPLS private peering or colocation cross-connect) terminate directly on the DRG. Route exchange can be dynamic (BGP over the tunnel — DRG import distributions learn on-prem CIDRs) or static (explicit route rules on the DRG route table pointing specific on-prem CIDRs to the IPsec/FastConnect attachment). In a defence context, static routes for known on-prem CIDRs are preferred for deterministic control — BGP is used only where on-prem route changes are frequent and operationally validated. SD-WAN appliances (Cisco Catalyst SD-WAN, Palo Alto Prisma, VMware VeloCloud) integrate by terminating IPsec tunnels to OCI DRG endpoints. The DRG treats SD-WAN tunnels as standard IPsec attachments. SD-WAN overlay policies (application-aware routing, QoS) operate independently — DRG handles underlay routing, SD-WAN handles overlay. BGP prefix-list filters on all external attachments (IPsec, FastConnect, RPC) prevent route leakage between classification levels. For V3 redundancy with multiple IPsec tunnels or FastConnect circuits, enable `ecmp_enabled` on the DRG route table for equal-cost multi-path load balancing across active tunnels.

## 6. Isolation Models

| Model | When | DRGs | TF State | Diagram |
|---|---|---|---|---|
| Shared Hub DRG | Sprint 2/3 — proving the pattern | 1 | 1 per sprint | A / B |
| DRG-per-Compartment | V2+ — parent tenancy compartments own their routing | N + 1 | Per compartment | D |
| DRG-per-Tenancy | V2+ — child tenancies isolated with own DRGs | N + 1 | Per tenancy | C |
| Combined (C + D) | V2+ production — per-compartment in parent, per-tenancy for children | N + M + 1 transit | Per tenancy + per compartment | C + D |

STAR ELZ V1 Sprint 2/3 uses shared hub DRG to prove connectivity and forced inspection. V2 transitions to the combined model: each parent compartment gets its own DRG (Diagram D), each child tenancy gets its own DRG with VCN attachments sized to isolation and performance needs (Diagram C), or child VCNs attach directly to the parent DRG via cross-tenancy VCN attachment if the parent must own all routing decisions. The `drg_r_ew_hub` placeholder in Sprint 2 becomes the parent-to-child peering DRG (either RPC peer or cross-tenancy attachment host). All connectivity flows through the parent transit DRG and NGFW. Single region — this topology carries directly into the isolated region deployment.

## 7. Routing Decision Framework — Static, Dynamic, and Distribution Criteria

In a defence deployment, not everything should be dynamically learned. Some routes must be explicitly declared and controlled. The decision of when to use static routes vs dynamic import distributions vs exclusion criteria is fundamental.

### When to Use Static Routes (Explicit Control)

Static routes provide deterministic, auditable control. Use them when you must guarantee exactly where traffic goes regardless of what the DRG learns dynamically. In a defence context, static routes are not an exception — they are the baseline.

| Use Case | Why Static | Example |
|---|---|---|
| Forced inspection (Sprint 3) | Must guarantee all spoke traffic hits the firewall — no bypass path allowed | `0/0 → Hub VCN attachment` on spoke DRG RT |
| Blackhole routes | Must guarantee certain CIDRs are unreachable — no route = no path | Exclude CIDR from all import distributions (deny by omission) |
| Known on-prem CIDRs | Must guarantee reachability to specific on-prem networks without relying on BGP convergence | `172.16.0.0/12 → IPsec attachment` on hub DRG RT |
| Inter-tenancy controlled peering | Must guarantee only specific CIDRs cross the RPC — no route leakage | `10.10.0.0/16 → RPC-A attachment` on transit DRG RT |

```hcl
# Static route — known on-prem CIDR to IPsec attachment (no BGP dependency)
resource "oci_core_drg_route_table_route_rule" "onprem_static" {
  drg_route_table_id         = oci_core_drg_route_table.hub_transit.id
  destination_type           = "CIDR_BLOCK"
  destination                = "172.16.0.0/12"
  next_hop_drg_attachment_id = oci_core_drg_attachment.ipsec[0].id
}

# Blackhole — achieved by routing to a DRG attachment with no VCN/tunnel behind it,
# or by excluding the CIDR from all import distributions (deny by omission).
# OCI does not have an explicit discard route — use distribution exclusion instead.
```

### When to Use Dynamic Import Distributions (Automatic Learning)

Import distributions reduce operational overhead when adding new spokes or connections. Use them for trusted, same-classification internal connectivity where new attachments should automatically participate.

| Use Case | Why Dynamic | Example |
|---|---|---|
| Hub full-mesh (Sprint 2) | New spoke VCN attaches, auto-learns CIDRs from all other spokes | `match_type = DRG_ATTACHMENT_TYPE, attachment_type = VCN` |
| BGP from FastConnect/IPsec | On-prem routes change, DRG learns automatically via BGP advertisement | `match_type = DRG_ATTACHMENT_TYPE, attachment_type = IPSEC_TUNNEL` |

### Import Distribution Match Criteria — Inclusion and Exclusion

`oci_core_drg_route_distribution_statement` supports inclusion criteria (what to accept) with priority ordering. Exclusion is achieved by not matching — if an attachment type is not in any statement, its routes are not imported.

```hcl
# Inclusion — accept VCN routes only (RPC and IPsec excluded by omission)
resource "oci_core_drg_route_distribution_statement" "accept_vcn" {
  drg_route_distribution_id = oci_core_drg_route_distribution.spoke_import.id
  action                    = "ACCEPT"
  match_criteria {
    match_type      = "DRG_ATTACHMENT_TYPE"
    attachment_type = "VCN"
  }
  priority = 1
}

# Per-spoke inclusion — accept routes from one specific attachment only
resource "oci_core_drg_route_distribution_statement" "accept_os_only" {
  drg_route_distribution_id = oci_core_drg_route_distribution.restricted_import.id
  action                    = "ACCEPT"
  match_criteria {
    match_type         = "DRG_ATTACHMENT_ID"
    drg_attachment_id  = oci_core_drg_attachment.os[0].id
  }
  priority = 1
}
# No statement for SS, TS, DEVT → their routes are excluded (deny by omission)
```

| Criteria Type | How It Works | Defence Application |
|---|---|---|
| **Inclusion (accept)** | `action = "ACCEPT"` with `match_type` filter — only matching routes are imported | Accept VCN attachment routes into hub RT. Accept IPsec routes into transit RT. |
| **Exclusion (deny by omission)** | If no statement matches an attachment, its routes are not imported | Child tenancy RPC routes excluded from spoke DRG RTs by having no matching statement. |
| **Priority ordering** | Lower `priority` number = evaluated first. First match wins. | Priority 1: Accept VCN attachments. Priority 2: Accept IPsec. No statement for RPC = excluded. |
| **Attachment type filtering** | `match_type = DRG_ATTACHMENT_TYPE` with `attachment_type` = VCN, IPSEC_TUNNEL, REMOTE_PEERING_CONNECTION, VIRTUAL_CIRCUIT | Import only VCN CIDRs into spoke RTs. Import only IPsec CIDRs into transit RT. |
| **DRG attachment ID filtering** | `match_type = DRG_ATTACHMENT_ID` with specific attachment OCID | Accept routes only from a specific spoke — exclude all others. Per-spoke control. |

### Inductive vs Deductive Routing Design

Two mental models for building route tables:

**Inductive (build up):** Start with nothing imported. Add specific accept statements for each attachment type or specific attachment you want. What you don't accept is excluded. This is the defence-preferred model — nothing is routable until explicitly permitted. Used for spoke DRG route tables and cross-tenancy transit DRG route tables.

**Deductive (start full, restrict):** Start with import-all via broad match criteria, then use static routes or separate DRG route tables to override specific paths. Used for the hub DRG route table in Sprint 2 where full-mesh is the starting point, then Sprint 3 narrows it by assigning spoke-specific DRG route tables that override the broad import.

STAR ELZ V1 progression: Sprint 2 is deductive (import all VCN CIDRs, full-mesh). Sprint 3 shifts spoke attachments to inductive (static route only — `0/0 → Hub`). V2/V3 uses inductive throughout — each DRG route table explicitly accepts only the attachments it should learn from.

### Three Operational Rules

**1. Everything in code.** Every route table, distribution, attachment — in Terraform, in state, in version control. No Console click-ops. ORM job logs provide immutable audit trail.

**2. Static for security boundaries, dynamic for trusted mesh.** Forced inspection, blackholes, and cross-tenancy peering use static routes. Same-classification spoke-to-spoke uses import distributions. Never rely on dynamic learning for security-critical paths.

**3. Inductive by default in production.** Start with no routes imported. Add explicit accept statements per attachment type. What you don't explicitly accept cannot be routed. This is the zero-trust routing posture for the isolated region.

## 8. Operational Risks and Mitigations — Sprint 2 Session Questions

These concerns were raised during the Sprint 2 Phase 1 workshop. Each is addressed with the specific OCI mechanism or Terraform pattern that mitigates it.

### How many route tables exist today?

Sprint 2 has 6 VCN-level route tables (`oci_core_route_table`) and 0 or 1 custom DRG route tables (`oci_core_drg_route_table`). Verify at any time:

```bash
# VCN route tables in Terraform state
terraform state list | grep oci_core_route_table

# DRG route tables — including auto-generated ones not in Terraform
oci network drg-route-table list --drg-id $DRG_OCID --all \
  --query 'data[].{"name":"display-name","type":"route-table-type"}' --output table
```

The OCI CLI command shows both auto-generated and custom DRG route tables. If a DRG route table appears in OCI Console but not in `terraform state list`, it is auto-generated and unmanaged — this is the auditability gap that custom DRG route tables solve.

### Can someone forget to assign a DRG route table to an attachment?

Yes — and that is the single most common routing mistake. If `drg_route_table_id` is omitted from a `oci_core_drg_attachment`, OCI silently creates an auto-generated DRG route table with full-mesh import. That attachment bypasses any forced inspection you configured on other attachments.

**Mitigation — Terraform `lifecycle` + `precondition`:**

```hcl
resource "oci_core_drg_attachment" "os" {
  drg_id             = var.hub_drg_id
  drg_route_table_id = var.spoke_drg_route_table_id
  network_details { id = oci_core_vcn.os.id; type = "VCN" }

  lifecycle {
    precondition {
      condition     = var.spoke_drg_route_table_id != ""
      error_message = "drg_route_table_id must be set — auto-generated tables bypass inspection."
    }
  }
}
```

This fails the plan if anyone submits code with an empty or missing `drg_route_table_id`. The error message tells them why.

### Can someone override the route table via Console and bypass the firewall?

Yes — a Console click can reassign a DRG attachment to a different DRG route table or add a static route that bypasses forced inspection. This is an operational bypass, not a code defect. The following controls work in layers — preventative (stop it), detective (catch it), and forensic (prove it).

**Preventative — IAM policy restricting DRG modifications:**

Limit who can modify DRG attachments and DRG route tables. Only the NW admin group should have `manage drg-route-tables` and `manage drg-attachments`. All other groups get `read` or `inspect` only.

```hcl
# Only NW admins can modify DRG routing — all others read-only
resource "oci_identity_policy" "restrict_drg_modify" {
  compartment_id = var.nw_compartment_id
  name           = "Restrict-DRG-Routing-Modify"
  statements = [
    "allow group UG_ELZ_NW to manage drgs in compartment C1_R_ELZ_NW",
    "allow group UG_ELZ_NW to manage drg-route-tables in compartment C1_R_ELZ_NW",
    "allow group UG_ELZ_NW to manage drg-attachments in compartment C1_R_ELZ_NW",
    "allow group UG_ELZ_SOC to inspect drgs in compartment C1_R_ELZ_NW",
    "allow group UG_ELZ_SOC to inspect drg-route-tables in compartment C1_R_ELZ_NW",
    "allow group UG_ELZ_SOC to inspect drg-attachments in compartment C1_R_ELZ_NW"
  ]
}
```

Spoke groups (UG_OS_ELZ_NW, UG_TS_ELZ_NW) should not have `manage drg-attachments` on the hub compartment. They can manage their own VCN and subnet route tables but cannot touch the DRG attachment's `drg_route_table_id`.

**Detective — Terraform drift detection:**

```bash
# Detect drift — compare Terraform state to live OCI
terraform plan -detailed-exitcode
# Exit code 2 = drift detected

# OCI Resource Manager drift detection API
oci resource-manager stack detect-drift --stack-id $STACK_ID
```

**Detective — OCI Audit Log alarm on DRG changes:**

OCI Audit service logs every API call. Create an alarm that fires when anyone modifies a DRG attachment or DRG route table outside the approved pipeline service account.

```bash
# OCI Logging — query audit events for DRG attachment changes
oci audit event list --compartment-id $NW_COMPARTMENT_ID \
  --start-time "2026-03-02T00:00:00Z" --end-time "2026-03-03T00:00:00Z" \
  --query "data[?contains(\"event-name\",'UpdateDrgAttachment') || contains(\"event-name\",'CreateDrgRouteTable') || contains(\"event-name\",'UpdateDrgRouteTable')].{\"time\":\"event-time\",\"user\":\"principal-id\",\"action\":\"event-name\"}" \
  --output table
```

In Terraform, configure an OCI Monitoring alarm that triggers on these audit events:

```hcl
# Alarm — DRG attachment or route table modified outside pipeline
resource "oci_monitoring_alarm" "drg_change_alert" {
  compartment_id        = var.nw_compartment_id
  display_name          = "P1-DRG-Routing-Change"
  namespace             = "oci_audit"
  query                 = "EventName = 'UpdateDrgAttachment' OR EventName = 'CreateDrgRouteTable' OR EventName = 'DeleteDrgRouteRule'"
  severity              = "CRITICAL"
  is_enabled            = true
  pending_duration      = "PT1M"
  destinations          = [oci_ons_notification_topic.security_alerts.id]
  body                  = "DRG routing modified — verify change is authorised and matches Terraform state."
}
```

**Detective — Cloud Guard custom detector recipe:**

Cloud Guard monitors OCI resources for security-relevant configuration changes. A custom detector recipe triggers when DRG-related resources change.

```hcl
resource "oci_cloud_guard_detector_recipe" "drg_monitor" {
  compartment_id = var.security_compartment_id
  display_name   = "DRG-Routing-Monitor"
  detector_id    = "oci-cloud-guard-detector-configuration"

  # Cloud Guard out-of-box rules to enable:
  #   NETWORK_DRG_ROUTE_TABLE_MODIFIED
  #   NETWORK_DRG_ATTACHMENT_MODIFIED
  #   NETWORK_ROUTE_TABLE_MODIFIED
  #   NETWORK_SECURITY_LIST_MODIFIED
  # Set risk level = CRITICAL, responder = notify SOC team
}
```

Cloud Guard evaluates continuously — not on a schedule. If a DRG attachment's route table ID changes, Cloud Guard raises a problem within minutes. Combined with the IAM restrictions, this catches both authorised changes made incorrectly and unauthorised changes made by privileged users.

**Forensic — VCN Flow Logs:**

VCN Flow Logs capture metadata for all traffic entering and leaving subnets. They do not capture packet payloads but record source/destination IP, port, protocol, action (accept/reject), and byte count. Enable flow logs on the Hub FW subnet to verify that all spoke-to-spoke traffic is transiting the firewall.

```hcl
# Enable flow logs on Hub FW subnet — proves traffic transits firewall
resource "oci_core_subnet" "hub_fw" {
  # ... existing subnet config ...
}

resource "oci_logging_log_group" "nw_flow_logs" {
  compartment_id = var.nw_compartment_id
  display_name   = "lg_r_elz_nw_flow"
}

resource "oci_logging_log" "hub_fw_flow" {
  display_name = "fl_r_elz_nw_fw"
  log_group_id = oci_logging_log_group.nw_flow_logs.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "all"
      resource    = oci_core_subnet.hub_fw.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }
  is_enabled = true
}
```

If a routing bypass occurs (spoke traffic reaching another spoke without appearing in the Hub FW subnet flow logs), the flow log gap is the evidence. Compare spoke subnet flow logs (traffic sent) against Hub FW subnet flow logs (traffic received) — any discrepancy means traffic is not transiting the firewall.

**Control summary for DRG routing integrity:**

| Layer | Control | What It Catches | When |
|---|---|---|---|
| Preventative | IAM policy — restrict `manage drg-*` to NW admins | Unauthorised users cannot modify DRG routing | Before change |
| Preventative | Terraform precondition on `drg_route_table_id` | Missing RT assignment caught at plan time | Before apply |
| Preventative | DRG `default_drg_route_tables` override | Forgotten attachments inherit forced inspection RT | At attachment creation |
| Detective | `terraform plan -detailed-exitcode` / ORM drift API | Any change outside Terraform | Scheduled (daily) |
| Detective | OCI Audit alarm on DRG API events | Any DRG modification, by any user, any method | Real-time (minutes) |
| Detective | Cloud Guard custom detector recipe | DRG attachment, route table, or route rule change | Continuous |
| Forensic | VCN Flow Logs on Hub FW subnet | Spoke traffic bypassing firewall | Continuous capture |

### What about the DRG default route table — can it be changed?

Every DRG has a `default_drg_route_tables` attribute that OCI assigns to new attachments if no `drg_route_table_id` is specified. This default can be overridden:

```bash
# Check current default DRG route tables
oci network drg get --drg-id $DRG_OCID \
  --query 'data."default-drg-route-tables"' --output json

# Override the default so even forgotten attachments get the correct RT
oci network drg update --drg-id $DRG_OCID \
  --default-drg-route-tables '{"vcn": "'$SPOKE_DRG_RT_OCID'"}'
```

In Terraform, set `default_drg_route_tables` on the `oci_core_drg` resource. This is a safety net — if someone creates a DRG attachment without `drg_route_table_id`, it inherits the spoke DRG route table (forced inspection) instead of an auto-generated full-mesh table. Defence-in-depth: set the default AND require `drg_route_table_id` via precondition.

### Terraform `import` block — bringing existing resources under control

If resources were created manually in Console (interim overrides, testing), bring them into Terraform state using the `import` block (Terraform 1.5+):

```hcl
# Import an existing DRG route table created manually in Console
import {
  to = oci_core_drg_route_table.hub_spoke_mesh
  id = "ocid1.drgroutetable.oc1.ap-singapore-2.aaaa..."
}

# Import an existing route rule
import {
  to = oci_core_drg_route_table_route_rule.force_hub
  id = "drg-route-table-id/route-rule-id"
}
```

After import, run `terraform plan` to verify the imported resource matches the code. Any difference is a manual override that needs to be reconciled — either update the code to match reality or let Terraform correct the drift on next apply.

### Terraform testing — validating route table correctness

Use `terraform test` (Terraform 1.6+) to validate routing invariants before apply:

```hcl
# tests/routing.tftest.hcl
run "spoke_attachments_use_correct_drg_rt" {
  command = plan

  assert {
    condition     = oci_core_drg_attachment.os.drg_route_table_id == oci_core_drg_route_table.spoke_to_hub.id
    error_message = "OS attachment must use spoke_to_hub DRG RT, not auto-generated."
  }

  assert {
    condition     = oci_core_drg_attachment.ts.drg_route_table_id == oci_core_drg_route_table.spoke_to_hub.id
    error_message = "TS attachment must use spoke_to_hub DRG RT."
  }
}
```

These tests run during CI before ORM apply. They catch misassigned route tables, missing preconditions, and code regressions.

### Service Gateway — parent vs child tenancy control

Service Gateway provides private access to Oracle services (Object Storage, OCI APIs) without traversing the internet. It is VCN-scoped — it exists inside a specific VCN, not on the DRG. This has direct implications for central inspection.

**How parent-child tenancy connectivity works:**

The child tenancy's VCN does not attach directly to a compartment in the parent. There are two connectivity patterns:

| Pattern | How It Works | Parent Visibility |
|---|---|---|
| **RPC peering** | Child DRG ←RPC→ Parent DRG. Each tenancy owns its own DRG. | Parent controls transit DRG RT and NGFW. Parent sees traffic crossing the RPC. |
| **Cross-tenancy VCN attachment** | Child VCN attaches directly to parent DRG (requires Endorse/Admit IAM). No child DRG needed. | Parent owns the DRG and attachment. Parent controls all routing for that VCN. |

In either pattern, the DRG handles east-west traffic between tenancies. But Oracle service traffic is different — if the child VCN has its own Service Gateway, that traffic goes directly from the child VCN to Oracle services backbone. It never enters the DRG. The parent cannot see it, inspect it, or block it at the routing layer.

**In a disconnected/isolated region, this matters because:**

Oracle services (Object Storage, OCI Vault, Logging) are accessed via Service Gateway even in isolated regions. If the child has its own Service Gateway, the child can exfiltrate data to Object Storage in their tenancy without the parent's NGFW seeing the traffic.

**Three mitigation options (policy decisions, not technical limitations):**

**Option 1 — IAM restriction (preventative):** Do not grant child tenancy the `manage service-gateways` IAM verb. The child physically cannot create a Service Gateway. All Oracle service traffic must route via DRG → parent transit VCN → NGFW → parent's Service Gateway.

```hcl
# In child tenancy — restrict SG creation. Only parent pipeline can provision networking.
resource "oci_identity_policy" "deny_child_sg" {
  compartment_id = var.child_tenancy_id
  name           = "Deny-Child-ServiceGateway"
  statements = [
    "allow group ChildNetworkAdmins to manage virtual-network-family in tenancy where request.operation != 'CreateServiceGateway'"
  ]
}
```

**Option 2 — Centralised Service Gateway (architectural):** Provision Service Gateway only in the parent transit VCN. Child traffic: Child VCN → Child DRG (or cross-tenancy attachment) → Parent DRG → NGFW → Parent Transit VCN → Service Gateway → Oracle services. All Oracle service traffic is inspected. Trade-off: added latency on every Oracle API call from child workloads.

**Option 3 — Allow child Service Gateway with monitoring (detective):** Permit child Service Gateway for performance, but monitor usage via OCI Audit logs and Cloud Guard. Service Gateway access is logged — the parent SOC team monitors for anomalous data transfer patterns. This accepts the risk that Oracle service traffic bypasses the NGFW in exchange for lower latency.

```bash
# Audit — list all Service Gateways across child tenancy
oci network service-gateway list --compartment-id $CHILD_COMPARTMENT_ID --all \
  --query 'data[].{"name":"display-name","state":"lifecycle-state","vcn":"vcn-id"}' --output table
```

**Recommendation for STAR ELZ V1:** Start with Option 1 (IAM restriction) in V2/V3. Centralise the Service Gateway in the parent transit VCN. Evaluate Option 3 only if latency on Oracle service calls becomes a measured performance issue in the isolated region. DRGv2 supports both patterns — the routing does not change, only the Service Gateway placement and IAM policy.

---

## 9. Cloud Provider Reference

| Aspect | OCI (DRGv2) | AWS (TGW) | Azure (vWAN + UDR) | GCP (Global VPC) |
|---|---|---|---|---|
| Transit routing | DRG RT → Hub VCN → FW | TGW RT → inspection VPC → FW | Routing intent → NVA in hub | Cloud Router → NVA |
| Dynamic learning | Import Route Distribution | TGW propagation | vWAN auto-learn | BGP-native |
| Isolation | DRG-per-tenancy + RPC + BGP | TGW segmentation or separate TGWs | Secured hubs | VPC Service Controls |
| Forced inspection | Custom DRG RT on spoke attachment | Custom TGW RT on spoke attachment | UDR next-hop to NVA | Firewall rules + routes |

AWS TGW uses the same architectural pattern as OCI DRGv2. Teams with AWS experience will find OCI DRGv2 concepts directly transferable. The Sprint 3 forced inspection pattern mirrors the AWS TGW appliance-mode pattern.
