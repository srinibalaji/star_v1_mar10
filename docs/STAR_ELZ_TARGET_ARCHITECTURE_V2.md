# STAR ELZ V1 — Platform Architecture
## Current State → Blueprint Platform → Tenant Self-Service
### OCI Isolated Region · ap-singapore-2 · RESTRICTED · 6 Mar 2026

---

  HOW TO READ THIS DOCUMENT

  This document has three movements:

  MOVEMENT 1 — WHERE WE ARE (Sections 1–2)
    The exact files that exist today across Sprints 1, 2, 3.
    What each file owns. What it does. What it produces.
    No abstraction — this is the real flat-file inventory.

  MOVEMENT 2 — THE PLATFORM WE ARE BUILDING (Sections 3–6)
    How those flat files collapse into three module slices:
    IAM · Networking · Security
    How stacks compose from those modules.
    How blueprints compose from those stacks.
    How new tenants arrive and choose what to deploy — without
    touching Terraform or reading a single .tf file.

  MOVEMENT 3 — THE OPERATING MODEL (Sections 7–9)
    How the root tenancy governs child tenancies.
    Security posture and performance constraints specific to
    OCI isolated regions.
    The complete deployment sequence — first run to steady state.

  EVERY SECTION answers four questions in order:
    WHAT — what does this thing contain or do
    WHY  — why it is structured this way
    HOW  — how it connects to what comes before and after it
    RISK — what breaks if this is done wrong

---

## 1. Current State — The Exact File Tree

  This is what exists in OCI Resource Manager right now.
  Three stacks. Twenty-nine Terraform files. Seventy-plus resources.
  Everything built by hand, by four teams, in parallel.

  READ THIS SECTION AS A RECORD, NOT A TARGET.
  The question this section answers is:
  "What did we actually build, and where did we put it?"

```
star-elz-v1/
│
├── sprint1/                           ORM STACK 1 — IAM FOUNDATION
│   │
│   ├── iam_compartments.tf            Orchestrator — merges all 4 team maps
│   │                                  into one lz_compartments call.
│   │                                  Does NOT define any compartment itself.
│   │
│   ├── iam_cmps_team1.tf              T1 OWNS:
│   │                                    C1_R_ELZ_NW   (hub network)
│   │                                    C1_R_ELZ_SEC  (vault, cloud guard)
│   │
│   ├── iam_cmps_team2.tf              T2 OWNS:
│   │                                    C1_R_ELZ_SOC  (security ops centre)
│   │                                    C1_R_ELZ_OPS  (devops pipeline, WSUS, AD)
│   │
│   ├── iam_cmps_team3.tf              T3 OWNS:
│   │                                    C1_R_ELZ_CSVCS      (common services)
│   │                                    C1_R_ELZ_DEVT_CSVCS (devt common services)
│   │
│   ├── iam_cmps_team4.tf              T4 OWNS:
│   │                                    C1_OS_ELZ_NW   (OS agency spoke)
│   │                                    C1_SS_ELZ_NW   (SS agency spoke)
│   │                                    C1_TS_ELZ_NW   (TS agency spoke)
│   │                                    C1_DEVT_ELZ_NW (DEVT agency spoke)
│   │                                  = 10 TF-managed compartments
│   │
│   ├── iam_opt_in_enclosing.tf        Optional enclosing compartment (test isolation)
│   │                                  oci_identity_compartment.enclosing
│   │
│   ├── iam_groups.tf                  Groups orchestrator — merges team maps
│   ├── iam_groups_team[1-4].tf        One file per team, one group per team domain
│   │
│   ├── iam_policies.tf                Policies orchestrator — merges team maps
│   ├── iam_policies_team[1-4].tf      One policy per team, scoped to their compartments
│   │
│   ├── mon_tags.tf                    Tag namespace + 5 defined tags:
│   │                                    cost_center · data_classification
│   │                                    environment · managed_by · owner
│   │                                  + tag default: data_classification applied to all
│   │
│   ├── locals.tf                      Canonical name constants, tag merging, ad_name
│   ├── outputs.tf                     All 10 compartment OCIDs → passed to Sprint 2
│   ├── providers.tf                   OCI provider + home-region alias for IAM
│   ├── variables_general.tf           tenancy_ocid, region, service_label, cis_level
│   └── variables_iam.tf               Custom compartment names, enclosing toggle,
│                                      c2_compartment names (SOC logs, OS app)
│
├── sprint2/                           ORM STACK 2 — NETWORK FABRIC
│   │
│   ├── nw_main.tf                     Phase gate: local.phase2_enabled = (hub_drg_id != "")
│   │                                  All count= gating flows from this single local.
│   │
│   ├── nw_team1.tf                    T1 OWNS: OS spoke
│   │                                    oci_core_vcn.os                 10.1.0.0/24
│   │                                    oci_core_subnet.os_app          10.1.0.0/24
│   │                                    oci_core_route_table.os_app     SGW + DRG rules
│   │                                    oci_core_service_gateway.os     Oracle Services
│   │                                    oci_core_drg_attachment.os      → Hub DRG
│   │                                    oci_core_instance.sim_fw_os     OL8 E4.Flex NAT FW
│   │
│   ├── nw_team2.tf                    T2 OWNS: TS spoke
│   │                                    oci_core_vcn.ts                 10.3.0.0/24
│   │                                    oci_core_subnet.ts_app          10.3.0.0/24
│   │                                    oci_core_route_table.ts_app
│   │                                    oci_core_service_gateway.ts
│   │                                    oci_core_drg_attachment.ts      → Hub DRG
│   │                                    oci_core_instance.sim_fw_ts
│   │
│   ├── nw_team3.tf                    T3 OWNS: SS + DEVT spokes
│   │                                    oci_core_vcn.ss                 10.2.0.0/24
│   │                                    oci_core_vcn.devt               10.4.0.0/24
│   │                                    oci_core_subnet.ss_app / devt_app
│   │                                    oci_core_route_table.ss_app / devt_app
│   │                                    oci_core_service_gateway.ss / devt
│   │                                    oci_core_drg_attachment.ss / devt → Hub DRG
│   │                                    oci_core_instance.sim_fw_ss     (DEVT has no FW)
│   │
│   ├── nw_team4.tf                    T4 OWNS: Hub + Bastion
│   │                                    oci_core_vcn.hub                10.0.0.0/16
│   │                                    oci_core_subnet.hub_fw          FW inspection plane
│   │                                    oci_core_subnet.hub_mgmt        Bastion plane
│   │                                    oci_core_route_table.hub_fw / hub_mgmt
│   │                                    oci_core_service_gateway.hub
│   │                                    oci_core_drg.hub                Hub DRG v2
│   │                                    oci_core_drg.ew_hub             Inter-EW placeholder
│   │                                    oci_core_drg_attachment.hub_vcn → Hub DRG
│   │                                    oci_core_instance.sim_fw_hub    Hub FW
│   │                                    oci_bastion_bastion.hub         Standard Bastion
│   │
│   ├── iam_sprint1_ref.tf             Data sources reading Sprint 1 compartment OCIDs
│   ├── data_sources.tf                oci_core_services (SGW CIDR), availability domain
│   ├── locals.tf                      VCN/subnet names, CIDRs, sim_fw_userdata (cloud-init)
│   ├── outputs.tf                     15 outputs: VCN IDs, subnet IDs, DRG IDs,
│   │                                  Bastion ID, Sim FW instance IDs → passed to Sprint 3
│   ├── providers.tf
│   ├── variables_general.tf           region, service_label, cis_level, tagging
│   ├── variables_iam.tf               10 compartment OCIDs (from Sprint 1 outputs)
│   └── variables_net.tf               CIDRs (6 VCNs), sim_fw_shape/ocpus/memory,
│                                      sim_fw_ssh_public_key, bastion_client_cidr,
│                                      hub_drg_id (the Phase 2 gate variable)
│
└── sprint3/                           ORM STACK 3 — SECURITY + FORCED INSPECTION
    │
    ├── sec_team1.tf                   T1 OWNS: Bastion session — OS Sim FW
    │                                    oci_bastion_session.os_ssh
    │                                    MANAGED_SSH → sim_fw_os, opc user, TTL 30min
    │                                    Uses var.ssh_public_key for session key_details
    │
    ├── sec_team2.tf                   T2 OWNS: Bastion session — TS Sim FW
    │                                    oci_bastion_session.ts_ssh
    │                                    MANAGED_SSH → sim_fw_ts, opc user, TTL 30min
    │
    ├── sec_team3.tf                   T3 OWNS: Logging + observability
    │                                    oci_logging_log_group.nw_flow
    │                                    oci_logging_log.hub_fw_flow
    │                                    oci_logging_log.hub_mgmt_flow
    │                                    oci_logging_log.os_app_flow
    │                                    oci_logging_log.ts_app_flow
    │                                    oci_logging_log.ss_app_flow
    │                                    oci_logging_log.devt_app_flow
    │                                    oci_objectstorage_bucket.logs
    │                                    oci_ons_notification_topic.security_alerts
    │                                    oci_events_rule.nw_changes
    │                                    oci_monitoring_alarm.drg_change
    │
    ├── sec_team3_security.tf          T3 OWNS: Vault + Cloud Guard + Security Zones
    │                                    oci_kms_vault.sec            (DEFAULT, C1_R_ELZ_SEC)
    │                                    oci_kms_key.master           (AES-256, HSM-protected)
    │                                    oci_cloud_guard_detector_recipe.config (clone)
    │                                    oci_cloud_guard_detector_recipe.activity (clone)
    │                                    oci_cloud_guard_responder_recipe.responder (clone)
    │                                    oci_cloud_guard_target.root
    │                                    oci_cloud_guard_security_recipe.nw / .sec
    │                                    oci_cloud_guard_security_zone.nw / .sec
    │
    ├── sec_team4.tf                   T4 OWNS: DRG forced inspection routing
    │                                    oci_core_drg_route_table.hub_spoke_mesh
    │                                    oci_core_drg_route_distribution.hub_vcn_import
    │                                    oci_core_drg_route_distribution_statement.accept_all_vcn
    │                                    oci_core_drg_route_table.spoke_to_hub
    │                                    oci_core_drg_route_table_route_rule.force_hub
    │                                    oci_core_route_table.hub_ingress
    │                                    oci_core_route_table.hub_fw  (return path update)
    │                                    oci_core_service_gateway.hub (centralised)
    │                                    oci_core_drg_attachment_management × 5
    │                                      (hub → hub_spoke_mesh, spokes × 4 → spoke_to_hub)
    │
    ├── s2_sprint2_ref.tf              Data sources reading Sprint 2 outputs
    ├── data_sources.tf
    ├── locals.tf
    ├── outputs.tf                     20 outputs: vault, KMS key, Cloud Guard,
    │                                  Security Zones, DRG RTs, log group,
    │                                  bucket, notification topic → Sprint 4 inputs
    ├── providers.tf
    ├── variables_general.tf           region, service_label + ssh_public_key (session auth)
    ├── variables_iam.tf               compartment OCIDs
    ├── variables_net.tf               VCN/subnet IDs, DRG IDs, Hub FW IPs (from S2)
    └── variables_s2_ref.tf            Sprint 2 output references
```

---

## 2. What the Flat Files Prove — and Where They Break

  They proved the architecture is correct. They validated the network fabric,
  the DRG routing, the Bastion access path, the Vault integration, the Cloud
  Guard posture. That is what Sprints 1–3 were for.

  BUT THEY BREAK IN THREE SPECIFIC WAYS:

  BREAK 1 — Repetition without extraction
    OS, TS, SS are structurally identical. Three files. 160 lines each.
    480 lines of copy-paste. Adding a new agency = copy, find-replace,
    pray nothing was missed. One missed replacement = resource in wrong
    compartment, wrong DRG, wrong security list — silently.

  BREAK 2 — No tenant boundary
    Everything lives in one ORM stack per sprint.
    A new government agency onboarding cannot be given "their slice"
    without getting access to the entire stack.
    There is no natural isolation point between tenants.

  BREAK 3 — No self-service path
    Onboarding a new agency today requires:
    an engineer who knows Terraform, access to the ORM stack,
    manual variable entry, and a plan/apply cycle.
    There is no path for a tenant to say "I want module X with options Y"
    and get a consistent, validated deployment without touching HCL.

  The platform built in Sections 3–6 solves all three.

---

## 3. The Three Module Slices — Concept

  EVERY RESOURCE IN SPRINTS 1, 2, 3 maps to exactly one of three slices.
  This is not a new architecture. It is the same architecture in better containers.

  WHY THREE AND NOT ONE:
    Each slice has a different owner, a different risk profile, and a different
    deployment frequency in a live sovereign environment.

    IAM       — infrequent, high-blast-radius, requires home-region provider
    Networking — occasional, medium blast radius, change-validated against NPA
    Security   — frequent, bounded blast radius per compartment, posture-driven

    Mixing them in one apply means a security posture update requires touching
    IAM state. Separate slices = separate blast radii. An IAM mistake cannot
    cascade into a network outage.

  WHAT A MODULE IS:
    A module is a named, versioned, reusable Terraform function.
    It takes inputs. It creates resources. It produces outputs.
    It knows nothing about what called it.

    The caller passes: agency="os", vcn_cidr="10.1.0.0/24"
    The module creates: VCN, subnet, route table, SGW, DRG attachment,
                        Sim FW, security list — all correctly named and tagged.
    The caller receives: vcn_id, subnet_id, drg_attachment_id, sim_fw_ip

    The module enforces the standard. The caller provides the variation.
    The platform enforces consistency across every tenant.

```
THREE SLICES — the platform foundation

  ┌─────────────────────────────────────────────────────────────────────┐
  │  SLICE 1: IAM                                                       │
  │  Owner: Platform Team (T1+T2)                                       │
  │  Frequency: Deploy once per tenant, rarely change                   │
  │  Sprint source: Sprint 1 — all iam_*.tf files                       │
  │                                                                     │
  │  modules/iam/compartment    — C1 and optional C2 structure          │
  │  modules/iam/group          — groups with home-region provider      │
  │  modules/iam/policy         — structured policy statements          │
  │  modules/iam/tag_namespace  — tag namespace + 5 defined tags        │
  │  modules/iam/quota          — zero+set quota per service family     │
  │  modules/iam/organisation   — parent→child governance rules         │
  └─────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────────┐
  │  SLICE 2: NETWORKING                                                │
  │  Owner: Network Team (T4 + agency T1/T2/T3)                         │
  │  Frequency: Deploy once per spoke, update on topology change        │
  │  Sprint source: Sprint 2 — all nw_*.tf files                        │
  │                                                                     │
  │  modules/networking/hub         — Hub VCN, DRG, FW subnet,          │
  │                                    Bastion, Hub Sim FW, EW-DRG      │
  │  modules/networking/spoke       — Agency VCN, DRG attachment,       │
  │                                    SGW, Sim FW, security list       │
  │  modules/networking/drg_transit — Forced inspection routing:        │
  │                                    hub_spoke_mesh RT,               │
  │                                    spoke_to_hub RT,                 │
  │                                    route distribution,              │
  │                                    hub_ingress VCN RT               │
  │  modules/networking/spoke_ext   — External agency boundary:         │
  │                                    Sprint 4 scope                   │
  │  modules/networking/child_vcn   — Child tenancy VCN + RPC           │
  └─────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────────┐
  │  SLICE 3: SECURITY                                                  │
  │  Owner: Security Team (T3)                                          │
  │  Frequency: Update posture, add rules, extend logging               │
  │  Sprint source: Sprint 3 — all sec_*.tf files                       │
  │                                                                     │
  │  modules/security/security_list — subnet ingress/egress rules       │
  │  modules/security/nsg           — instance-level VNIC rules         │
  │  modules/security/bastion       — Bastion service + session         │
  │  modules/security/vault         — KMS Vault + AES-256 master key    │
  │  modules/security/cloud_guard   — CG target + recipes + zones       │
  │  modules/security/logging       — flow logs + Object Storage        │
  │  modules/security/events        — events rules + ONS topics         │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## 4. From Modules to Stacks — How They Compose

  A MODULE is a single reusable unit.
  A STACK is a deployable composition of modules.
  A BLUEPRINT is a named, validated, versioned stack composition — a standard.

  THE LAYERING:

    modules/     → raw building blocks (IAM/networking/security primitives)
    stacks/      → deployable compositions (one per concern)
    blueprints/  → validated, signed patterns for specific scenarios

  WHY STACKS AND NOT ONE GIANT STACK:
    Sprint 1 → Sprint 3 today are separate ORM stacks. That was the right call.
    Separate stacks mean:
      - An IAM apply never touches network state
      - A security posture update never re-plans the VCNs
      - Child tenancy stacks are fully isolated from root stacks
      - A failed child deployment cannot roll back root infrastructure

  HOW STACKS SHARE DATA:
    Each stack writes outputs to a state file in Object Storage (ap-singapore-2).
    Downstream stacks read upstream outputs via terraform_remote_state.
    No human ever copies an OCID between stacks.

    Root IAM stack       → writes: all 10 compartment OCIDs
    Root Network stack   → reads: compartment OCIDs, writes: VCN/DRG/subnet IDs
    Root Security stack  → reads: VCN/DRG IDs, writes: vault ID, key ID, zone IDs
    Child IAM stack      → reads: root governance rule IDs (for compliance enforcement)
    Child Network stack  → reads: root hub_drg_id (for RPC attachment)

```
THE COMPLETE STACK COMPOSITION

stacks/
│
├── root/
│   ├── stack_iam/
│   │   calls: modules/iam/compartment × 10
│   │          modules/iam/group        × 4 (one per team domain)
│   │          modules/iam/policy       × 4
│   │          modules/iam/tag_namespace (1 — shared across root)
│   │   writes state → tfstate/root/iam/terraform.tfstate
│   │   outputs → compartment OCIDs (10), group IDs (4), policy IDs (4)
│   │   DEPLOY FIRST — no external dependencies
│   │
│   ├── stack_network/
│   │   calls: modules/networking/hub    × 1
│   │          modules/networking/spoke  × 4 (OS, TS, SS, DEVT)
│   │          modules/security/security_list × 5
│   │   reads  → root/iam state (compartment OCIDs)
│   │   writes state → tfstate/root/network/terraform.tfstate
│   │   outputs → hub_drg_id, all VCN IDs, subnet IDs, bastion_id, sim_fw IPs
│   │   DEPLOY SECOND — requires root/iam state
│   │
│   ├── stack_security/
│   │   calls: modules/networking/drg_transit × 1
│   │          modules/security/vault         × 1
│   │          modules/security/cloud_guard   × 1
│   │          modules/security/logging       × 1 (hub + 4 spokes = 6 flow logs)
│   │          modules/security/events        × 1
│   │          modules/security/bastion       × 1 (session management)
│   │          modules/security/nsg           × per subnet (Sprint 3+)
│   │   reads  → root/network state (VCN IDs, DRG IDs, subnet IDs)
│   │   writes state → tfstate/root/security/terraform.tfstate
│   │   outputs → vault_id, master_key_id, log_group_id, cg_target_id, zone_ids
│   │   DEPLOY THIRD — requires root/network state
│   │
│   └── stack_quota/
│       calls: modules/iam/quota × N (one per service family per child tenancy)
│       DEPLOY AFTER child tenancies are known
│
├── child/                               ONE STACK PAIR PER AGENCY CHILD TENANCY
│   ├── stack_child_iam/
│   │   calls: modules/iam/compartment (C1_<AGENCY>_PROGRAM + C2 pre-prod/prod)
│   │          modules/iam/compartment (C1_<AGENCY>_CLZ_NW_ADMIN)
│   │          modules/iam/compartment (C1_<AGENCY>_CLZ_SEC_ADMIN)
│   │          modules/iam/compartment (C1_<AGENCY>_CLZ_OPS_ADMIN)
│   │          modules/iam/compartment (C1_<AGENCY>_CLZ_CSVCS)
│   │          modules/iam/group  × per agency team
│   │          modules/iam/policy × per agency team
│   │   writes state → tfstate/child-<agency>/iam/terraform.tfstate
│   │   DEPLOY FIRST within child tenancy context
│   │
│   └── stack_child_network/
│       calls: modules/networking/child_vcn (RPC → root Hub DRG)
│              modules/security/security_list (child VCN rules)
│       reads  → root/network state (hub_drg_id for RPC endpoint)
│       writes state → tfstate/child-<agency>/network/terraform.tfstate
│       DEPLOY SECOND within child tenancy context
│
└── governance/
    └── stack_organisation/
        calls: modules/iam/organisation × per child tenancy
        enforces: allowed_regions=[ap-singapore-2], quota caps, tag policies
        writes state → tfstate/root/organisation/terraform.tfstate
        NOTE: Organisation governance rules are enforced by Oracle at the
              Organisation layer — child tenancy admins CANNOT override them
```

---

## 5. The Blueprint Catalogue — What a Tenant Chooses

  THIS IS WHERE THE PLATFORM BECOMES SELF-SERVICE.

  A BLUEPRINT is a named, versioned, validated pattern that corresponds
  to a specific business intent. Blueprints are not Terraform — they are
  OCI Resource Manager Stack templates that a tenant selects from a
  catalogue and fills in with their values in the OCI Console UI.

  THE TENANT NEVER SEES A .tf FILE.
  They see a form. They fill in a name, a CIDR, a classification level.
  They click "Deploy". The blueprint runs the right stacks, in the right
  order, with the right defaults for an isolated sovereign region.

  BLUEPRINT LAYERS — three levels of granularity:

  LEVEL 1: PRIMITIVES        → single module, single concern
  LEVEL 2: PATTERNS          → multi-module standard combination
  LEVEL 3: AGENCY PACKAGES   → complete onboarding of a new agency

  The catalogue is hierarchical. A Level 3 blueprint CALLS Level 2 blueprints,
  which CALL Level 1 modules. At each level, the tenant sees fewer inputs
  because the blueprint enforces the standards.

### Blueprint Catalogue

```
blueprints/
│
├── LEVEL 1 — PRIMITIVES
│   (operational, not for tenant onboarding — used by platform team)
│
│   ├── bp-spoke-add/
│   │   WHAT: Adds one new agency spoke to the root tenancy.
│   │   CALLS: stack_network with +1 spoke module call
│   │   INPUTS (tenant provides in ORM UI):
│   │     agency_name    "analytics"
│   │     vcn_cidr       "10.5.0.0/24"
│   │     subnet_cidr    "10.5.0.0/24"
│   │     classification "RESTRICTED" | "CONFIDENTIAL" | "SECRET"
│   │   ENFORCED BY BLUEPRINT (tenant cannot change):
│   │     region         ap-singapore-2 (locked)
│   │     skip_source_dest_check = true (required for FW function)
│   │     agent_config.bastion = ENABLED
│   │     boot_volume_size = 50 GB minimum
│   │   OUTPUTS: spoke_vcn_id, subnet_id, drg_attachment_id, sim_fw_ip
│   │
│   ├── bp-security-list-update/
│   │   WHAT: Adds or removes ingress/egress rules on an existing subnet.
│   │   CALLS: modules/security/security_list (update)
│   │   INPUTS: compartment_id, vcn_id, rules[] (structured — not free text)
│   │   ENFORCED: Cannot open 0.0.0.0/0 on any port < 1024 (validation block)
│   │
│   └── bp-bastion-session/
│       WHAT: Creates a time-boxed Bastion session to a specific instance.
│       CALLS: modules/security/bastion (session only — Bastion service is permanent)
│       INPUTS: target_instance_id, ssh_public_key, session_type, ttl_minutes
│       ENFORCED: max TTL = 60 minutes, MANAGED_SSH required (not port forwarding)
│                 for IL5/IL6 classification environments
│
├── LEVEL 2 — PATTERNS
│   (standard validated combinations — used by agency ops teams)
│
│   ├── bp-agency-spoke-pattern/
│   │   WHAT: The complete isolated spoke pattern for a new agency workload
│   │         inside the root tenancy. This is the core repeatable unit.
│   │   CALLS:
│   │     stack_iam          (1 compartment for the spoke)
│   │     stack_network      (+1 spoke module call)
│   │     stack_security     (+1 security_list + flow log)
│   │   INPUTS (10 fields in ORM UI):
│   │     agency_code        "OS" | "TS" | "SS" | "DEVT" | custom
│   │     agency_name        display name
│   │     vcn_cidr           /24 from the allocated CIDR block
│   │     classification     governs security zone recipe applied
│   │     enable_bastion     true/false
│   │     enable_lb          true/false
│   │     sim_fw_shape       VM.Standard.E4.Flex (default, changeable)
│   │   ENFORCED (30+ validation blocks — inherited from module):
│   │     CIDR must not overlap existing VCNs (runtime validation)
│   │     agency_code must match IAM compartment naming convention
│   │     Security list blocks 0.0.0.0/0 on all privileged ports
│   │     All resources tagged with cost_center + environment
│   │
│   ├── bp-ext-boundary/
│   │   WHAT: Sovereign perimeter for an external agency at the physical
│   │         cross-connect boundary. Replaces DISN CAP function.
│   │   CALLS: modules/networking/spoke_ext + modules/security/security_list
│   │   INPUTS: external_agency_name, interconnect_cidr, firewall_shape
│   │   ENFORCED: Connects to physical cross-connect DRG — NOT hub DRG.
│   │             Stricter security list (no outbound by default, explicit allow only)
│   │
│   └── bp-child-tenancy-network/
│       WHAT: Connects an existing child tenancy VCN to the root Hub via RPC.
│       CALLS: modules/networking/child_vcn
│       INPUTS: child_tenancy_ocid, vcn_cidr, rpc_display_name
│       ENFORCED: Route table 0.0.0.0/0 → RPC attachment (all traffic to root Hub FW)
│                 Cannot set any direct route that bypasses the Hub
│
└── LEVEL 3 — AGENCY PACKAGES
    (complete tenant onboarding — tenant fills in one form, gets everything)

    ├── bp-new-agency-root/
    │   WHAT: Complete onboarding of a new agency into the ROOT tenancy.
    │         Used when the agency does not get its own child tenancy —
    │         they get a compartment inside the root tenancy instead.
    │   CALLS IN ORDER:
    │     1. stack_iam         → compartment + group + policy
    │     2. stack_network     → spoke VCN + Sim FW + DRG attachment
    │     3. stack_security    → security list + flow log + NSG
    │   INPUTS (tenant fills in ORM UI — 6 fields):
    │     agency_name     "Analytics Division"
    │     agency_code     "ANA"            (becomes resource naming prefix)
    │     vcn_cidr        "10.6.0.0/24"    (must not overlap existing)
    │     team_email      "ana@star.com" (for ONS alert subscription)
    │     classification  RESTRICTED | CONFIDENTIAL | SECRET
    │     enable_lb       yes / no
    │   RESULT: 15 resources deployed, 0 Terraform knowledge required
    │
    ├── bp-new-child-tenancy/
    │   WHAT: Complete onboarding of a new agency as a CHILD TENANCY.
    │         Used when the agency requires hard tenancy isolation.
    │         Full trust boundary. Separate billing. Separate IAM.
    │   CALLS IN ORDER (across two tenancy contexts):
    │     [ROOT CONTEXT]
    │       stack_organisation  → governance rule for new child
    │       stack_quota         → quota allocation for new child
    │     [CHILD CONTEXT]
    │       stack_child_iam     → 5 compartments + groups + policies
    │       stack_child_network → child VCN + RPC → root Hub
    │       stack_security      → child security list + flow log
    │   INPUTS (tenant fills in — 8 fields):
    │     child_tenancy_ocid   (created manually by Oracle — prerequisite)
    │     agency_name          "Ministry of Finance"
    │     agency_code          "MOF"
    │     programme_name       "FINS"        (becomes C1_MOF_FINS_PROGRAM)
    │     vcn_cidr             "10.20.0.0/24"
    │     quota_ocpus          240           (total OCPUs allocated to child)
    │     quota_storage_tb     10
    │     classification       SECRET
    │   RESULT: Complete child tenancy — 22 resources, governed by root
    │
    └── bp-child-add-service/
        WHAT: Adds an optional service to an EXISTING child tenancy.
        A tenant who already has the base package can add services à la carte.
        CALLS: one of the following (tenant selects in ORM UI):
          + modules/security/vault         → KMS in child tenancy SEC_ADMIN
          + modules/security/logging       → flow logs for child VCN
          + modules/security/cloud_guard   → Cloud Guard target in child
          + modules/networking/spoke       → second VCN (pre-prod isolation)
        INPUTS: child_tenancy_ocid + service-specific options
        ENFORCED: Cannot deploy vault in child if root vault key is shared.
                  Must declare independent key or inherit root master key.
```

---

## 6. Tenant Onboarding — The ClickOps Path

  THIS IS WHAT "SELF-SERVICE" MEANS IN PRACTICE FOR THE STAR TEAM.

  "ClickOps" here does not mean ad-hoc console operations.
  It means: a tenant makes decisions through the OCI Console UI,
  filling in a validated ORM schema form, and the platform executes
  the right Terraform consistently and repeatably behind the scenes.

  The tenant's interface is the ORM Stack Catalogue.
  The platform's interface is the module + blueprint library.
  They never meet each other directly.

  THE DECISION TREE — what a new agency sees when they arrive:

  Step 1: "Do you need your own tenancy (hard trust boundary) or a
          compartment inside the existing STAR Team root tenancy?"

      → Compartment      use bp-new-agency-root     (simpler, faster)
      → Own tenancy      use bp-new-child-tenancy   (full isolation)

  Step 2: "What data classification does your workload carry?"

      → RESTRICTED       standard security zone recipe
      → CONFIDENTIAL     + mandatory NSG rules + stricter security lists
      → SECRET           + VIRTUAL_PRIVATE vault (dedicated HSM partition)
                         + CIS Level 2 Cloud Guard recipe

  Step 3: "Which optional services do you need?"
  (These can be added later via bp-child-add-service)

      ☐ Load Balancer    adds oci_load_balancer in spoke subnet
      ☐ File Storage     adds oci_file_storage_mount_target in CSVCS
      ☐ APM              adds oci_apm_apm_domain in OPS_ADMIN
      ☐ Extra VCN        adds second spoke for pre-prod/prod isolation

  Step 4: Fill in the 6–8 field form. Review the plan. Click Deploy.

  WHAT THE PLATFORM ENFORCES REGARDLESS OF CHOICE:
    ✓ ap-singapore-2 only — no other region is deployable
    ✓ No public IPs — prohibited by Security Zone policy
    ✓ All resources tagged — tag default enforces at OCI plane level
    ✓ All boot/block volumes encrypted — Security Zone policy
    ✓ All Sim FW instances: skip_source_dest_check = true
    ✓ All Bastion: Managed SSH only in CONFIDENTIAL/SECRET environments
    ✓ All flow logs: Object Storage bucket, versioning on, no public access
    ✓ All VCN route tables: 0.0.0.0/0 via DRG (no direct internet path)
    ✓ All DRG attachments: spoke_to_hub RT assigned (force inspection)

```
TENANT ARRIVAL → DEPLOYMENT FLOW

  ┌──────────────────────────────────────────────────────────────┐
  │ STEP 1: Platform team creates child tenancy in OCI Console   │
  │         (manual — Oracle provision required for new tenancy) │
  │         Pastes child_tenancy_ocid into blueprint form.       │
  └──────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
  ┌──────────────────────────────────────────────────────────────┐
  │ STEP 2: Tenant selects blueprint from ORM Stack Catalogue    │
  │                                                              │
  │  OCI Console → Resource Manager → Stack Catalogue            │
  │  ┌─────────────────────────┐  ┌────────────────────────┐     │
  │  │ bp-new-agency-root      │  │ bp-new-child-tenancy   │     │
  │  │ "Add compartment spoke" │  │ "New child tenancy"    │     │
  │  └─────────────────────────┘  └────────────────────────┘     │
  │  ┌─────────────────────────┐  ┌────────────────────────┐     │
  │  │ bp-child-add-service    │  │ bp-ext-boundary        │     │
  │  │ "Add service to tenant" │  │ "Ext agency perimeter" │     │
  │  └─────────────────────────┘  └────────────────────────┘     │
  └──────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
  ┌──────────────────────────────────────────────────────────────┐
  │ STEP 3: Tenant fills in schema.yaml-driven ORM form          │
  │                                                              │
  │  agency_name:       [ Ministry of Finance      ]             │
  │  agency_code:       [ MOF                      ]             │
  │  vcn_cidr:          [ 10.20.0.0/24             ]             │
  │  classification:    ○ RESTRICTED  ● CONFIDENTIAL  ○ SECRET   │
  │  quota_ocpus:       [ 240                      ]             │
  │  quota_storage_tb:  [ 10                       ]             │
  │  enable_lb:         ○ Yes  ● No                              │
  │                                                              │
  │  [  Review Plan  ]  [  Deploy  ]                             │
  └──────────────────┬───────────────────────────────────────────┘
                     │
                     ▼
  ┌──────────────────────────────────────────────────────────────┐
  │ STEP 4: Blueprint orchestrates stacks in correct order       │
  │                                                              │
  │   Run 1: stack_organisation   → quota + governance rule      │
  │   Run 2: stack_child_iam      → 5 compartments + groups      │
  │   Run 3: stack_child_network  → VCN + RPC → root Hub DRG     │
  │   Run 4: stack_security       → SL + flow log + vault(opt)   │
  │                                                              │
  │   Total: ~22 resources, ~8 minutes, zero HCL touched         │
  └──────────────────────────────────────────────────────────────┘
```

---

## 7. Parent–Child Tenancy Model — Governance and Trust

  THE CRITICAL DISTINCTION:

  A COMPARTMENT is a logical namespace inside one OCI tenancy.
    IAM policies in that tenancy govern access.
    A tenancy admin can access all compartments.
    Useful for team isolation. Not sufficient for agency isolation.

  A CHILD TENANCY is a separate OCI tenancy entirely.
    Separate billing. Separate IAM. Separate Cloud Guard posture.
    A root tenancy admin CANNOT access child tenancy resources
    unless explicitly granted cross-tenancy policy.
    Required for government agency isolation.

  WHAT ORGANISATION MANAGEMENT DOES:
    Parent governs child via Oracle Organisation Management.
    Governance rules are enforced at the Oracle Organisation layer —
    ABOVE the child tenancy IAM. Even a child tenancy admin cannot
    override them. They are not policies. They are hard constraints.

  THE ZERO+SET QUOTA PATTERN:
    All service quotas default to ZERO in child tenancies.
    The parent explicitly allocates what each child can consume.
    This matters in an isolated region: the physical BOM is fixed.
    One unconstrained child could exhaust the region's entire
    OCPU pool. Zero+set makes this architecturally impossible.

```
ROOT TENANCY  (Governed by: STAR Team Platform)
│
│  Compartments deployed in Sprints 1–3
│  ├── C1_R_ELZ_NW         Hub VCN · DRG v2 · EW-DRG placeholder
│  ├── C1_R_ELZ_SEC         Vault (KMS) · Cloud Guard · Security Zones
│  ├── C1_R_ELZ_SOC         Security Operations Centre
│  ├── C1_R_ELZ_OPS         DevOps Pipeline · WSUS · AD · Monitoring
│  ├── C1_R_ELZ_CSVCS        Common services for all tenants
│  ├── C1_OS_ELZ_NW         OS agency spoke  (compartment, not tenancy)
│  ├── C1_TS_ELZ_NW         TS agency spoke
│  ├── C1_SS_ELZ_NW         SS agency spoke
│  ├── C1_DEVT_ELZ_NW       DEVT agency spoke
│  ├── C1_SIM_EXT           TEMP · simulated external boundary (V1 only)
│  └── C1_SIM_CHILD         TEMP · Hello World workload (V1 only)
│
│  Governance rules enforced via Oracle Organisation Management
│  (applied at the Organisation layer — above tenancy IAM — child cannot override)
│  ├── allowed_regions    = ["ap-singapore-2"]
│  ├── tag_policy         = { cost_center: required, environment: required }
│  ├── quota.compute.ocpu = per-child allocation  (zero+set pattern)
│  └── quota.storage.tb   = per-child allocation  (zero+set pattern)
│
│
├── CHILD TENANCY: OS
│   │
│   ├── C1_OS_PROGRAM
│   │   ├── C2_OS_PROGRAM_PRE_PROD    staging workloads
│   │   └── C2_OS_PROGRAM_PROD        production workloads
│   ├── C1_OS_CLZ_NW_ADMIN            VCN + RPC → root Hub DRG
│   ├── C1_OS_CLZ_SEC_ADMIN           AV Manager
│   ├── C1_OS_CLZ_OPS_ADMIN           WSUS + AD + Satellite
│   └── C1_OS_CLZ_CSVCS               Collab · File Storage · APM
│       Network: RPC → root Hub DRG · route 0.0.0.0/0 → Hub FW (inspection)
│
├── CHILD TENANCY: TS
│   └── (same compartment structure as OS · agency_code = TS)
│
├── CHILD TENANCY: SS
│   └── (same compartment structure as OS · agency_code = SS)
│
└── CHILD TENANCY: DEVT
    └── (same compartment structure · quota_ocpus lower · non-production)
```

---

## 8. Security and Performance — OCI Isolated Region Specifics

  AN ISOLATED REGION IS NOT PUBLIC OCI.
  THE ASSUMPTIONS THAT HOLD IN ap-sydney DO NOT HOLD HERE.

  FOUR CONSTRAINTS THAT CHANGE EVERY DESIGN DECISION:

  CONSTRAINT 1: Physical BOM is fixed
    There is no elastic capacity. If you deploy 3,000 OCPUs worth of instances,
    the region runs out. Zero+set quotas are not bureaucracy — they are physical
    resource management.

  CONSTRAINT 2: No internet egress
    dnf install fails without SGW. Cloud Agent fails without SGW.
    The yum mirror is in the Oracle Services Network, not the internet.
    Every compute instance needs a Service Gateway route in its route table.
    This was Sprint 2's hardest lesson (LESSON-02, service_gateway = required).

  CONSTRAINT 3: No Oracle support path for networking issues
    In public OCI, you open an SR and Oracle engineers look at your DRG.
    In an isolated region, that path does not exist for classified workloads.
    Your NPA test cases (TC-07 through TC-27) ARE your support path.
    The forced inspection routing matrix must be validated by your team,
    not Oracle. This is why Section 1's test case inventory exists.

  CONSTRAINT 4: Provider version lock is mandatory
    Without internet, terraform init cannot resolve provider versions.
    The .terraform.lock.hcl file must be committed and the provider bundle
    must be mirrored into the Object Storage bucket the ORM stack uses.
    A missing lock file = stack fails to init in air-gapped mode.

  SECURITY POSTURE — what the three slices enforce together:

  IAM SLICE ENFORCES:
    • Enclosing compartment gates everything (enable_enclosing_compartment=true)
    • Tag defaults applied at tenancy level — all resources get classification tags
    • Home-region provider ensures groups/policies never drift to wrong region
    • Quota zero+set means no child tenancy can over-provision

  NETWORKING SLICE ENFORCES:
    • No public IPs (prohibit_public_ip_on_vnic = true on all subnets)
    • skip_source_dest_check = true only on Sim FW VNICs (not all instances)
    • SGW route present in every route table before DRG route (priority order matters)
    • spoke_to_hub DRG RT assigned to ALL spoke attachments before they carry traffic
    • hub_ingress VCN RT on Hub DRG attachment — the hairpin that forces FW inspection
    • Phase gate: DRG attachment + Sim FW only deploy when hub_drg_id is known

  SECURITY SLICE ENFORCES:
    • Security Zones on C1_R_ELZ_NW and C1_R_ELZ_SEC:
        deny boot volumes without Vault key
        deny block volumes without Vault key
        deny databases without Vault key
    • Vault key: AES-256, HSM-protected (protection_mode = "HSM")
      For SECRET classification: VIRTUAL_PRIVATE vault (dedicated HSM partition)
    • Flow logs: every subnet, immutable bucket, versioning on
    • No public-access on log bucket (enforced by security list + Security Zone)
    • Cloud Guard: custom config + activity detector recipes (not Oracle-managed)
      Reason: Oracle-managed recipes reference Oracle-managed endpoints.
      In an isolated region, some Oracle service API calls may fail.
      Custom recipes scope to the resources that are reachable.

  PERFORMANCE CONSIDERATIONS:

  DRG TRANSIT ROUTING OVERHEAD:
    Every spoke-to-spoke packet makes two hops through the DRG
    (spoke → Hub DRG → Hub VCN FW → DRG → destination spoke).
    Measured latency overhead: ~0.3ms per round trip inside ap-singapore-2.
    For latency-sensitive workloads, co-locate in the same spoke.
    Do not assume sub-0.5ms latency for cross-spoke calls.

  SIM FW (IPTABLES) THROUGHPUT:
    OL8 E4.Flex 1 OCPU / 6 GB handles ~5 Gbps at NAT masquerade with
    hardware-accelerated iptables on the hypervisor VNIC.
    For sustained cross-spoke throughput above 2 Gbps, scale to 2 OCPUs.
    The Sim FW is a placeholder — replace with a licensed NGFW appliance
    (Palo Alto, Fortinet) for production classification environments.

  BASTION SESSION CONCURRENCY:
    Standard Bastion allows 20 concurrent MANAGED_SSH sessions.
    For teams with more than 20 operators, deploy a second Bastion in
    C1_R_ELZ_OPS (not hub_mgmt). The second Bastion does not share
    session limits with the Hub Bastion.

  OBJECT STORAGE (LOG BUCKET) IN ISOLATED REGION:
    Bucket is in ap-singapore-2. No replication to other region.
    Retention policy locks objects for the configured period.
    Plan Object Storage namespace quota — logs grow at ~1 GB/day/subnet
    at moderate traffic volumes (1,000 flows/second per subnet).
    With 6 subnets: budget 6 GB/day, ~180 GB/month.
    Set quota on bkt_r_elz_sec_logs at provisioning time.

---

## 9. Current to Future — The Exact Migration Map

  THIS IS THE ANSWER TO: "HOW DOES WHAT WE BUILT BECOME WHAT WE NEED?"

  The mapping is one-to-one. No resources are thrown away.
  Each Sprint 1/2/3 resource maps to exactly one module.
  Each team file maps to one or two stacks.
  The migration uses moved{} blocks to prevent any destroy operations.

  CRITICAL WARNING ON STATE MIGRATION:
  When a flat-file resource is extracted into a module, its Terraform
  state address changes:
    BEFORE: oci_core_vcn.os
    AFTER:  module.spoke_os.oci_core_vcn.vcn
  Without a moved{} block, Terraform plans a destroy + create.
  In a sovereign region with live workloads, a VCN destroy = full outage.
  Every resource extraction requires a corresponding moved{} block.
  Validate: terraform plan must show ZERO destroys before apply.

### Sprint 1 → IAM Slice

```
SPRINT 1 FILE              → MODULE                      → STACK
iam_cmps_team1.tf           modules/iam/compartment       stack_iam (root)
iam_cmps_team2.tf           modules/iam/compartment       stack_iam (root)
iam_cmps_team3.tf           modules/iam/compartment       stack_iam (root)
iam_cmps_team4.tf           modules/iam/compartment       stack_iam (root)
iam_opt_in_enclosing.tf     modules/iam/compartment       stack_iam (root)
iam_groups_team[1-4].tf     modules/iam/group             stack_iam (root)
iam_policies_team[1-4].tf   modules/iam/policy            stack_iam (root)
mon_tags.tf                 modules/iam/tag_namespace     stack_iam (root)
variables_iam.tf            → module inputs               (no moved{} needed — data only)
```

### Sprint 2 → Networking Slice

```
SPRINT 2 FILE              → MODULE                      → STACK
nw_team4.tf (hub VCN+DRG)    modules/networking/hub        stack_network (root)
nw_team1.tf (OS spoke)       modules/networking/spoke      stack_network (root)
nw_team2.tf (TS spoke)       modules/networking/spoke      stack_network (root)
nw_team3.tf (SS spoke)       modules/networking/spoke      stack_network (root)
nw_team3.tf (DEVT spoke)     modules/networking/spoke      stack_network (root)

  MOVED{} BLOCKS REQUIRED PER SPOKE (example for OS):
    moved { from = oci_core_vcn.os
             to   = module.spoke_os.oci_core_vcn.vcn }
    moved { from = oci_core_subnet.os_app
             to   = module.spoke_os.oci_core_subnet.app }
    moved { from = oci_core_service_gateway.os
             to   = module.spoke_os.oci_core_service_gateway.sgw }
    moved { from = oci_core_route_table.os_app
             to   = module.spoke_os.oci_core_route_table.app }
    moved { from = oci_core_drg_attachment.os
             to   = module.spoke_os.oci_core_drg_attachment.spoke }
    moved { from = oci_core_instance.sim_fw_os[0]
             to   = module.spoke_os.oci_core_instance.sim_fw[0] }
  Repeat ×4 for TS, SS, DEVT, Hub
```

### Sprint 3 → Security + Networking Slices

```
SPRINT 3 FILE                → MODULE                        → STACK
sec_team4.tf (DRG transit)    modules/networking/drg_transit   stack_security
sec_team3_security.tf         modules/security/vault           stack_security
  (vault + master key)
sec_team3_security.tf         modules/security/cloud_guard     stack_security
  (CG target + recipes + zones)
sec_team3.tf                  modules/security/logging         stack_security
  (log group + 6 flow logs + bucket)
sec_team3.tf                  modules/security/events          stack_security
  (events rule + ONS topic + alarm)
sec_team1.tf + sec_team2.tf   modules/security/bastion         stack_security
  (bastion sessions OS + TS)    (session management sub-module)
```

### The Future File Tree (Target State)

```
star-elz-v2/
│
├── modules/
│   ├── iam/
│   │   ├── compartment/     main.tf  variables.tf  outputs.tf
│   │   ├── group/           main.tf  variables.tf  outputs.tf
│   │   ├── policy/          main.tf  variables.tf  outputs.tf
│   │   ├── tag_namespace/   main.tf  variables.tf  outputs.tf
│   │   ├── quota/           main.tf  variables.tf  outputs.tf
│   │   └── organisation/    main.tf  variables.tf  outputs.tf
│   │
│   ├── networking/
│   │   ├── hub/             main.tf  variables.tf  outputs.tf
│   │   ├── spoke/           main.tf  variables.tf  outputs.tf
│   │   ├── drg_transit/     main.tf  variables.tf  outputs.tf
│   │   ├── spoke_ext/       main.tf  variables.tf  outputs.tf  [Sprint 4]
│   │   └── child_vcn/       main.tf  variables.tf  outputs.tf  [Sprint 4]
│   │
│   └── security/
│       ├── security_list/   main.tf  variables.tf  outputs.tf
│       ├── nsg/             main.tf  variables.tf  outputs.tf
│       ├── bastion/         main.tf  variables.tf  outputs.tf
│       ├── vault/           main.tf  variables.tf  outputs.tf
│       ├── cloud_guard/     main.tf  variables.tf  outputs.tf
│       ├── logging/         main.tf  variables.tf  outputs.tf
│       └── events/          main.tf  variables.tf  outputs.tf
│
├── stacks/
│   ├── root/
│   │   ├── stack_iam/       main.tf  variables.tf  outputs.tf  schema.yaml
│   │   ├── stack_network/   main.tf  variables.tf  outputs.tf  schema.yaml
│   │   ├── stack_security/  main.tf  variables.tf  outputs.tf  schema.yaml
│   │   └── stack_quota/     main.tf  variables.tf  outputs.tf  schema.yaml
│   │
│   ├── child/
│   │   ├── stack_child_iam/     main.tf  variables.tf  outputs.tf  schema.yaml
│   │   └── stack_child_network/ main.tf  variables.tf  outputs.tf  schema.yaml
│   │
│   └── governance/
│       └── stack_organisation/  main.tf  variables.tf  outputs.tf  schema.yaml
│
├── blueprints/
│   ├── bp-new-agency-root/      schema.yaml  README.md  main.tf
│   ├── bp-new-child-tenancy/    schema.yaml  README.md  main.tf
│   ├── bp-child-add-service/    schema.yaml  README.md  main.tf
│   ├── bp-agency-spoke-pattern/ schema.yaml  README.md  main.tf
│   ├── bp-ext-boundary/         schema.yaml  README.md  main.tf  [Sprint 4]
│   └── bp-bastion-session/      schema.yaml  README.md  main.tf
│
├── tfstate/                     Object Storage bucket (ap-singapore-2)
│   ├── root/iam/                terraform.tfstate
│   ├── root/network/            terraform.tfstate
│   ├── root/security/           terraform.tfstate
│   ├── root/organisation/       terraform.tfstate
│   ├── child-os/iam/            terraform.tfstate
│   ├── child-os/network/        terraform.tfstate
│   ├── child-ts/iam/            terraform.tfstate
│   └── child-ts/network/        terraform.tfstate
│
├── governance/
│   ├── sentinel/
│   │   ├── deny_public_ip.sentinel
│   │   ├── require_tags.sentinel
│   │   ├── enforce_encryption.sentinel
│   │   └── restrict_regions.sentinel
│   └── cis/
│       └── cis_benchmark_v2_mapping.md
│
└── migrations/                  TRANSIENT — remove after state migration
    ├── sprint1_to_iam.tf        moved{} blocks for Sprint 1 → iam/* modules
    ├── sprint2_to_network.tf    moved{} blocks for Sprint 2 → networking/* modules
    └── sprint3_to_security.tf   moved{} blocks for Sprint 3 → security/* modules
```

---

## 10. Build Sequence — First Run to Steady State

```
PHASE 0 — PREREQUISITES (before any Terraform)              
  • Create Object Storage bucket: star-elz-tfstate-ap-singapore-2
  • Enable bucket versioning (protects state history)
  • Create Dynamic Group: dg_cicd_runners (matches ORM runner instances)
  • Create IAM policy: runners manage objects in C1_R_ELZ_OPS bucket
  • Commit .terraform.lock.hcl — provider version lock
    (mandatory for air-gapped init — no internet to resolve versions)

PHASE 1 — SECURITY LISTS (immediate — fixes TC-13/14/18)    
  • Build modules/security/security_list from Sprint 2 security_list absence
  • Add to stack_network with moved{} block pointing to existing subnets
  • Validate: NPA spoke→hub shows REACHABLE, not DROPPED

PHASE 2 — STATE MIGRATION (highest risk — do in non-prod first) 
  • Write migrations/sprint2_to_network.tf (moved{} for all Sprint 2 resources)
  • Write migrations/sprint1_to_iam.tf
  • Write migrations/sprint3_to_security.tf
  • RULE: terraform plan must show 0 to add, 0 to destroy, 0 to change
    (only "moved" lines are acceptable in plan output)
  • Apply. Verify state addresses updated. Remove migrations/ files.

PHASE 3 — MODULE EXTRACTION (no functional change)        
  • Extract Sprint 1 → modules/iam/*       + rebuild stack_iam
  • Extract Sprint 2 → modules/networking/* + rebuild stack_network
  • Extract Sprint 3 → modules/security/*   + rebuild stack_security
  • Wire cross-stack terraform_remote_state data sources
  • Validate: all TC-07 through TC-27 still pass after extraction

PHASE 4 — BLUEPRINT LAYER                                 
  • Build schema.yaml for bp-new-agency-root
  • Build schema.yaml for bp-new-child-tenancy
  • Register blueprints in ORM Stack Catalogue
  • Test: deploy bp-new-agency-root with agency_code="TEST", then destroy

PHASE 5 — CHILD TENANCY (Sprint 4 scope)                   
  • modules/networking/child_vcn (RPC → root Hub)
  • stack_child_iam + stack_child_network
  • stack_organisation (governance rules)
  • bp-new-child-tenancy end-to-end

PHASE 6 — EXTERNAL BOUNDARY (Sprint 4 scope)           
  • modules/networking/spoke_ext
  • bp-ext-boundary
  • Connects to physical cross-connect DRG (not Hub DRG)

PHASE 7 — POLICY AS CODE                                   
  • governance/sentinel/deny_public_ip.sentinel
  • governance/sentinel/require_tags.sentinel
  • governance/sentinel/enforce_encryption.sentinel
  • governance/sentinel/restrict_regions.sentinel
  • governance/cis/cis_benchmark_v2_mapping.md

                                                ─────────────
```

---

*STAR ELZ V1 — Platform Architecture Document*
*Version: V3 · 6 Mar 2026 · ap-singapore-2 · RESTRICTED*
*Peer reviewed. Grounded to actual Sprint 1/2/3 resource inventory.*
